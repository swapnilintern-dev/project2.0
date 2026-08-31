# Push Notification System — Integration Spec

**Status:** backend complete and live-safe · Flutter data layer complete · UI + FCM transport **paused** pending the VS Arogya Firebase project.

Marketing broadcasts a rich notification → every approved vendor receives it as a
push (foreground / background / terminated / offline) **and** as a row in their
in-app notification center, with read/unread tracking and delivery analytics.

---

## 1. What is already built and merged

Everything below is on disk, syntax-checked, and safe to deploy **today**. With
no Firebase credentials present the system runs in *in-app-only* mode: campaigns
are stored, fanned out to every eligible vendor's notification center, and all
analytics work — only the OS-level push is skipped, and the API reports that
honestly via `pushConfigured: false`. Nothing throws, nothing existing changed.

### Backend — new files

| File | Purpose |
|---|---|
| `server/model/notificationModel.js` | One campaign. 12 categories, 4 priorities, draft/scheduled/sending/sent/failed lifecycle, rich-media fields, denormalised sender, stats counters, text + compound indexes. |
| `server/model/notificationReceiptModel.js` | One row per *(campaign, vendor)* — the vendor's inbox row **and** the delivery record. Unique `(notification, vendor)` index is the no-duplicates guarantee. |
| `server/model/deviceTokenModel.js` | FCM registration tokens. Unique per token, one row per `(user, deviceId)`, never returned to any client. |
| `server/utils/fcm.js` | The transport. Lazy `firebase-admin` init from env, `sendEach` in batches of 500 with concurrency 4, exponential-backoff retry on transient codes, classification of permanently-invalid tokens. |
| `server/utils/notificationBroadcast.js` | The engine: resolve eligible vendors → chunked receipt insert → chunked token load → push → fold per-vendor outcomes → prune dead tokens → update stats. Atomic status claim makes double-send impossible. |
| `server/utils/notificationScheduler.js` | Timer jobs: scheduled sends, stuck-broadcast recovery, retry sweep (max 3 auto passes / 24h window), stale-token pruning. `unref`'d, no cron dependency. |
| `server/controller/notificationController.js` | All 20 handlers. |
| `server/routes/notificationRoute.js` | Route table + role guards. |
| `server/middlewares/requireRole.js` | Reusable role guard reading the signed JWT claim. |

### Backend — edited files (additive only)

- `server/model/userModel.js` — added `notificationsEnabled: Boolean` (default `true`, so existing vendors are reachable with no migration).
- `server/index.js` — mounted `notificationRouter`, started the scheduler.
- `server/package.json` — added `firebase-admin`.

### Flutter — new files

| File | Purpose |
|---|---|
| `lib/notifications/notification_models.dart` | `AppNotification` (vendor row, incl. `fromPushData` for instant optimistic display), `Campaign` + `CampaignStats`, `CampaignDraft` (mutable composer model with client-side validation mirroring the server), `AudienceSummary`, category/priority vocabularies, colour + icon mapping, `relativeTime`. |
| `lib/notifications/notification_api.dart` | Repository over all 20 endpoints. Same auth header strategy as `CustomerApi`/`MarketingApi` (Bearer + cookie fallback). Never throws — returns `ApiResult` / empty page. Multipart banner upload. |
| `lib/notifications/notification_controller.dart` | `NotificationController` (vendor inbox, unread badge, optimistic read/delete with rollback, `_seenPushIds` dedup, `onPushReceived` / `onPushOpened`) and `MarketingCampaignsController` (history, debounced search, filters, send/retry/duplicate/delete). Plus the `incomingPush` `ValueNotifier` that the in-app banner will listen to. |

`flutter analyze lib/notifications/` → **No issues found.** Nothing imports these
yet, so the existing app is completely unaffected.

---

## 2. API contract

Base: `{API_BASE_URL}/vsArogya`. All routes require a session
(`Authorization: Bearer <jwt>` or the login cookie).

### Shared — any signed-in account

| Method | Path | Body / Query | Notes |
|---|---|---|---|
| `GET` | `/notifications/meta` | — | Category + priority vocabularies, `pushConfigured`. |
| `POST` | `/notifications/device-token` | `{token, platform, deviceId, appVersion, enabled}` | Idempotent upsert. Steals the token from any other account (shared device) and replaces the same device's rotated token. |
| `PUT` | `/notifications/device-token` | `{oldToken, token, …}` | Token rotation. |
| `DELETE` | `/notifications/device-token` | `{token}` (omit → all) | Call on logout. |
| `GET` | `/notifications/settings` | — | `notificationsEnabled`, `registeredDevices`. |
| `PUT` | `/notifications/preferences` | `{enabled}` | Account-level opt-out; mirrored onto the account's devices. |

### Vendor — notification center

| Method | Path | Notes |
|---|---|---|
| `GET` | `/notifications/inbox` | `?page&limit&unreadOnly&category`. Pinned first, newest first. Expired and soft-deleted campaigns filtered out inside the `$lookup`. Returns `total`, `unread`, `hasMore`. |
| `GET` | `/notifications/inbox/unread-count` | Tiny; safe to poll for the bell badge. |
| `POST` | `/notifications/inbox/:id/read` | `:id` accepts **receipt id or campaign id** — so a push handler that only knows the campaign can call it directly. |
| `POST` | `/notifications/inbox/read-all` | Bulk, with per-campaign counter roll-up. |
| `POST` | `/notifications/inbox/:id/delivered` | Device ack — this is what turns "sent to FCM" into a *confirmed delivery*. Idempotent. |
| `POST` | `/notifications/inbox/:id/opened` | Implies delivered + read. |
| `DELETE` | `/notifications/inbox/:id` | Soft delete, this vendor only. |

### Marketing — `requireRole("marketing")` on every route

| Method | Path | Notes |
|---|---|---|
| `GET` | `/notifications` | History. `?q&status&category&priority&page&limit`. `q` is an escaped regex so partial words match as you type. |
| `POST` | `/notifications` | Create. `sendNow=true` broadcasts; future `scheduledAt` queues; otherwise draft. JSON **or** multipart with a `bannerImage` file part. |
| `PUT` | `/notifications/:id` | Edit — **drafts and scheduled only** (409 otherwise; duplicate a sent campaign instead). |
| `DELETE` | `/notifications/:id` | Draft → hard delete + Cloudinary cleanup. Sent → soft delete (keeps analytics + vendor inboxes). |
| `POST` | `/notifications/:id/send` | Send / resend. Receipts dedupe, so only vendors added since the first send get a new row. |
| `POST` | `/notifications/:id/retry` | Re-attempt only the vendors whose push failed or never ran. |
| `POST` | `/notifications/:id/duplicate` | Clone a sent campaign back to a draft. |
| `GET` | `/notifications/:id` | Campaign + live analytics computed from receipts. |
| `GET` | `/notifications/:id/stats` | Analytics only — cheap to poll. |
| `GET` | `/notifications/audience` | `eligibleVendors` / `reachableVendors` for the composer preview. |

**Eligibility rule** (`resolveEligibleVendorIds`): role does **not** match
`/^(admin|marketing|delivery|agent|outlet)/i`, `approvalStatus === "Approved"`,
and `notificationsEnabled !== false`.

---

## 3. Guarantees and how they are enforced

| Requirement | Mechanism |
|---|---|
| No duplicate notifications | Unique `(notification, vendor)` index on receipts; `_seenPushIds` set client-side; `collapseKey` / `apns-collapse-id` on the campaign id. |
| No double broadcast | `findOneAndUpdate` atomically claims `draft/scheduled/sent/failed → sending`; a second request gets `409 already being sent`. |
| Offline delivery | FCM store-and-forward with `ttl` = 14 days, clamped to the campaign's own `expiryDate`. |
| Near-zero delay | `android.priority: "high"`, `apns-priority: 10` for High/Critical; the HTTP response returns as soon as the campaign is durable while the fan-out continues in the background. |
| Thousands of vendors | Vendors/receipts chunked at 1 000, tokens at 2 000, FCM at 500 × 4 concurrent. No unbounded arrays anywhere. |
| Retry | In-transport backoff (3 attempts) + a 10-minute sweeper (3 auto passes, 24 h window) + a manual retry endpoint. |
| Invalid token cleanup | 5 permanent FCM error codes → row hard-deleted immediately; 180-day stale prune. |
| Crash recovery | A campaign stuck in `sending` > 15 min is released to `failed` and picked up by the retry sweep. |
| Security | Role comes from the signed JWT, never the body. Tokens are never echoed to any client. Vendor inbox routes scope every query by `req.id`. |
| Analytics accuracy | Counters increment only on the *first* state transition; `GET /:id/stats` recomputes from receipts so it can never drift. |

---

## 4. What is left to build (resumes when the Firebase project exists)

### 4.1 Prerequisites you create

1. **Firebase project** for VS Arogya → add an Android app (`com.example.self`
   — or your real applicationId) and an iOS app.
2. **Server credentials:** Project Settings → Service accounts → *Generate new
   private key*. Put the JSON into the Render environment as
   `FIREBASE_SERVICE_ACCOUNT` (raw JSON on one line, or base64 — `fcm.js`
   accepts both). Alternatively set `FIREBASE_PROJECT_ID`,
   `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`.
   *Nothing else on the server changes — it starts pushing the moment those
   variables exist.*
3. **iOS only:** an APNs auth key uploaded to Firebase, plus Push Notifications
   + Background Modes → Remote notifications capability in Xcode.

### 4.2 Flutter packages to add

```
firebase_core
firebase_messaging
flutter_local_notifications      # foreground tray notification + channels
url_launcher                     # optional: opens a campaign's deep link
```

Client config will be passed as `--dart-define` values (`FIREBASE_API_KEY`,
`FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`),
matching the existing `API_BASE_URL` pattern — so **no `google-services.json`
in the repo and no secrets committed**, and the Android build keeps working for
anyone who doesn't have the values.

### 4.3 `lib/services/push_service.dart`

- Initialise Firebase **only** when the dart-defines are present; otherwise set
  `isConfigured = false` and let the app run on polling alone (no crash, no
  dummy data).
- Request the OS permission (Android 13+ `POST_NOTIFICATIONS`, iOS alert/badge/sound).
- Fetch the token → `POST /notifications/device-token`; listen to
  `onTokenRefresh` → `PUT`; `DELETE` on logout.
- Stable per-install `deviceId` in `shared_preferences` (already a dependency).
- **Foreground** `onMessage` → `NotificationController.onPushReceived` (in-app
  animated banner + optimistic row) *and* a local tray notification.
  iOS foreground presentation set to `alert: false` so it never doubles up.
- **Background/terminated** — the system tray renders FCM's `notification`
  block; the background isolate handler stays minimal. Delivery is acked on the
  next inbox sync (add `delivered` to `publicInboxItem` and ack unacked rows
  once per session).
- **Tap** → `onMessageOpenedApp`, `getInitialMessage`, and the local-notification
  response callback all route through `NotificationController.onPushOpened` →
  `redirectScreen` / `deepLink` / notification detail.
- Two Android channels matching the ids `fcm.js` already sends:
  `medicaplus_general` and `medicaplus_critical`.

### 4.4 UI screens

**Vendor** (`lib/notifications/`)
- `notification_center_screen.dart` — pull-to-refresh, infinite scroll, category
  chips, unread-only toggle, "Mark all read", swipe-to-delete, pinned section.
- `notification_detail_screen.dart` — hero artwork, expandable message, priority
  badge, CTA button, marks opened on entry.
- `notification_widgets.dart` — gradient card, priority badge, unread dot, time
  label, animated in-app banner overlay driven by `incomingPush`.
- Bell + badge in `lib/customer/home_screen.dart` — replaces the existing
  `_bellButton()` placeholder at line 213 (`'No new notifications'` snack) and
  its "no notifications backend yet" comment.

**Marketing** (`lib/marketing/notifications/`)
- `notification_composer_screen.dart` — all 12 fields, category/priority/redirect
  pickers, icon picker, banner upload, expiry + schedule pickers, live preview
  rendered with the *real* vendor card, audience count, Save draft / Schedule /
  Send now.
- `notification_history_screen.dart` — search, filters, status chips, per-row
  send / retry / duplicate / edit / delete, live `LiveRefreshMixin` polling.
- `notification_stats_screen.dart` — targeted / sent / delivered / opened / read
  / failed / retries with rates.
- A 5th tab in `lib/marketing/marketing_role_main.dart` ("Notify").

### 4.5 Wire-up

- `lib/main.dart` — `navigatorKey` for push-tap routing + the in-app banner overlay.
- `lib/auth/session.dart` / `AuthService` — register the device token after
  login and session restore; unregister + `NotificationController.clear()` on logout.
- `android/app/src/main/AndroidManifest.xml` — `POST_NOTIFICATIONS` permission,
  default-channel meta-data, `<queries>` entry if `url_launcher` is used.
- `ios/Runner/Info.plist` — `UIBackgroundModes: remote-notification`.

---

## 5. Test checklist for when it lands

1. Marketing sends → campaign stored with `status: sent`, `stats.targeted` = approved-vendor count.
2. Every approved vendor gets a receipt; staff accounts get none.
3. Foreground → in-app banner + tray notification, no duplicate.
4. Background → tray notification, tap opens the detail screen.
5. Terminated → tray notification, cold-start tap routes correctly.
6. Airplane mode → notification arrives when connectivity returns (within TTL).
7. Read / mark-all-read / delete → badge and analytics update on both sides.
8. Resend → no vendor sees it twice.
9. Uninstalled device → token auto-removed on the next broadcast.
10. Non-marketing role calling `POST /notifications` → `403`.
11. Vendor A cannot read/delete vendor B's receipt.
12. Double-tap Send → second request returns `409`, one broadcast only.
