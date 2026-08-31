# Backend Spec — Area Agent & Outlet Staff roles

For: backend developer
App: VS Arogya (Flutter)
Server: Node + Express 5 + Mongoose 9 (existing `server/` folder)
Base URL: `https://backend-new-0ady.onrender.com`

The Flutter screens for both roles are **already built and working against mock
data**. The exact JSON field names and status strings below are what the app
already parses — if you match them, the app is wired by swapping the mock for a
live datasource. Nothing in the app needs redesigning.

Please read "Section 0" first — it explains what already exists so you don't
rebuild it.

---

## 0. What already exists (reuse, don't rebuild)

- **One user collection.** `Vendor` (`model/userModel.js`) holds every kind of
  user — admin, marketing, delivery, buyers. They are told apart by the
  free-text `role` string field. Delivery agents are created as
  `Vendor.create({ role: "delivery" })`.
  → **Agent and Outlet users should be Vendor documents too**, with
  `role: "agent"` and `role: "outlet"`. Do not make new user collections.

- **Login already works.** `POST /vsArogya/login` returns
  `{ success, role, token }` and also sets an httpOnly `token` cookie.
  `middlewares/isAuthenticated.js` accepts the cookie OR
  `Authorization: Bearer <token>`. The app already sends the Bearer header.

- **Vendor list already works.** `GET /vsArogya/active-vendors` returns
  `Vendor.find({ approvalStatus: "Approved" })`. **The outlet app already parses
  this response as-is** (it reads `_id`, `store_name`, `contact_person_name`,
  `mobile_no`, `full_address`, `city`, `state`, `pin_code`). No change needed
  except removing the password field from the response.

- **Orders already store the pincode.** `orderModel.shippingAddress.pincode` is
  required on every order. **This is the single field the whole Agent role runs
  on.**

- **Idempotency already exists.** `orderModel.clientOrderId` is unique + sparse.
  Use it for the outlet's `idempotencyKey`.

- **Razorpay already works** (`controller/paymentController.js`) — order-first,
  then create-payment, then verify-payment with signature check.

---

## 1. Things to fix first (small, blocks both roles)

1. **`controller/userController.js`, the login role gate:**
   ```js
   const staffRoles = ["admin", "marketing", "delivery"];
   ```
   Add `"agent"` and `"outlet"`. Without this, agent/outlet accounts get a 403
   ("pending admin approval") and can never log in.

2. **`GET /all-vendors` and `GET /active-vendors` return the password field.**
   Add `.select("-password")`.

3. **Admin routes have no auth middleware at all.** `/all-orders`,
   `/all-vendors`, `/approval-mail/:id` etc. are open to anyone. Adding two more
   roles makes this worse. Suggest: load the user in `isAuthenticated` and
   attach `req.user.role`, then add a `requireRole("agent")` style guard.

4. **Passwords are stored and compared in plain text** (`password !== user.password`).
   `bcrypt` is already in package.json but never imported.

> Items 3 and 4 are pre-existing, not caused by this work — but both roles sit
> on top of them.

---

# PART A — AREA AGENT ROLE

## A1. What the agent does

An Area Agent is assigned **one pincode**. They log in and see **every order
being delivered to that pincode**. They tap an order to see its status and its
medicines. **They are read-only — they cannot change anything.**

That's the whole role.

## A2. Database changes

**None.** Everything needed already exists:

| Need | Existing field |
|---|---|
| Agent identity | `Vendor` with `role: "agent"` |
| Agent's assigned pincode | `Vendor.pin_code` (already in the schema) |
| Agent's name | `Vendor.contact_person_name` |
| Order's delivery pincode | `order.shippingAddress.pincode` |

To create an agent: make a `Vendor` with `role: "agent"`, `pin_code`,
`contact_person_name`, `mobile_no`, `password`, and `approvalStatus: "Approved"`.

## A3. Endpoints to build

### `GET /vsArogya/agent/orders`
Auth required. Returns orders whose delivery pincode = the **logged-in agent's**
`pin_code`. Read the pincode from the token's user — do **not** accept a pincode
from the client (an agent must not be able to view another area).

Logic is essentially:
```js
const agent = await Vendor.findById(req.id);
const orders = await order
  .find({ "shippingAddress.pincode": agent.pin_code })
  .populate("orderItems.product")
  .populate("user")
  .sort({ createdAt: -1 });
```

Response:
```json
{
  "success": true,
  "pincode": "411001",
  "agentName": "Ravi Kumar",
  "orders": [
    {
      "id": "665f...",
      "orderNo": "ORD-2026123456",
      "customerName": "Rahul Sharma",
      "deliveryAddress": "12 MG Road, Shivajinagar, Pune",
      "deliveryPincode": "411001",
      "status": "Pending",
      "createdAt": "2026-07-16T09:12:00.000Z",
      "total": 210,
      "lines": [
        { "name": "Paracetamol 500mg", "packSize": "10 tablets", "qty": 3, "price": 25 }
      ]
    }
  ]
}
```

Notes:
- `customerName` = the order's `user.store_name` or `contact_person_name`.
- `deliveryAddress` = `shippingAddress.address` (+ city/state if you like).
- `lines[].name` = the populated `product.title`;
  `packSize` = `product.packInfo`; `price` = `orderItems[].orderPrice`.
- Send `createdAt` as an ISO date. **Do not send "12 min ago"** — the app
  formats that itself.

### `GET /vsArogya/agent/orders/:id`
Same single order, same shape as one array element above. Must 403 if the
order's pincode is not the agent's pincode.

### `GET /vsArogya/agent/me` (optional but useful)
`{ "success": true, "name": "...", "pincode": "411001" }` — so the dashboard can
show the agent's name and pincode after a session restore.

## A4. Status mapping — NEEDS A DECISION

Server statuses (`orderModel.orderStatus`):
```
Pending | Confirm Order | Shipped | Out for Delivery | Delivered | Cancelled
```

The agent screen currently understands only four:
```
pending | confirmed | outForDelivery | delivered
```

**"Shipped" and "Cancelled" have no place to go in the app right now.**

Recommended: **send the raw server status string** exactly as stored, and we add
the two missing states to the app. Please do not invent new status strings and
do not collapse Shipped into something else — send what's in the database.

---

# PART B — OUTLET STAFF ROLE

## B1. What outlet staff does

An Outlet is a physical shop we run. Staff log in and:

1. **See stock** — two lists: their **own outlet's** stock (they can sell it)
   and other outlets' stock **in their district** (read-only, just to check
   availability elsewhere).
2. **Create an order** for an **admin-approved vendor** (picked from a list —
   staff never type a name). Order is either **counter handover** or **home
   delivery**.
3. **Take payment by Razorpay QR or payment link only.** No cash. No COD.
4. **Hand over / dispatch** the order — but only after the server says it's paid.

## B2. THE MAIN PROBLEM — per-outlet stock does not exist

Right now the database has **one global stock number**:
`productModel.stock` (a single Number on the product).

The outlet role needs to know **how much of a product a specific outlet has**.
That concept does not exist anywhere in the schema. **This is the main thing you
need to build.**

### Recommended: two new collections

**`Outlet`** — the shop itself:
```js
{
  name: String,          // "VS Arogya Ballari"
  pincode: String,
  district: String,
  address: String,
  active: { type: Boolean, default: true }
}
```

**`OutletStock`** — how much of each product each outlet holds:
```js
{
  outlet:  { type: ObjectId, ref: "Outlet",  required: true },
  product: { type: ObjectId, ref: "product", required: true },
  qty:     { type: Number, default: 0 },
  reserved:{ type: Number, default: 0 }   // held by unpaid orders
}
// unique compound index on { outlet, product }
```

Then link staff to their outlet: add `outlet: { type: ObjectId, ref: "Outlet" }`
to the `Vendor` schema. An outlet staff user = `Vendor` with `role: "outlet"`
and an `outlet` reference.

**Why a separate collection and not a stock field per product:** it keeps ONE
product catalog, so the customer app, marketing and admin all keep working
untouched. Please don't duplicate product documents per outlet.

### Reserved stock
When an order is created it is `AWAITING_PAYMENT` — the stock must be **held**
(`reserved += qty`) so it can't be double-sold, and **released**
(`reserved -= qty`) if the order is cancelled or expires. On payment, actually
deduct (`qty -= n`, `reserved -= n`). Available to sell = `qty - reserved`.

## B3. Route prefix — NEEDS A DECISION

The app currently expects outlet paths at **`/outlet/...`** (no `/vsArogya`).
Everything else in the server is under `/vsArogya`.

**Recommendation:** mount at `/vsArogya/outlet/...` for consistency. That's a
one-line change in the app (`lib/services/api_config.dart`). Tell us which you
pick — just be consistent.

Paths below are written **without** the prefix.

## B4. Exact wire strings (do not change these)

The app already parses these exact uppercase strings.

**Order type:** `COUNTER` | `DELIVERY`

**Payment method:** `QR` | `PAYMENT_LINK`

**Order status:**
```
AWAITING_PAYMENT | PAID | HANDED_OVER | READY_FOR_PICKUP
OUT_FOR_DELIVERY | DELIVERED | CANCELLED | EXPIRED
```

Lifecycle:
```
AWAITING_PAYMENT
   └─(Razorpay confirms)→ PAID
                            ├─ COUNTER  → HANDED_OVER        (end)
                            └─ DELIVERY → READY_FOR_PICKUP
                                            → OUT_FOR_DELIVERY
                                              → DELIVERED     (end)
AWAITING_PAYMENT ─(cancel / timeout)→ CANCELLED / EXPIRED  (release stock)
```

## B5. Endpoints to build

### `GET /outlet/stock`
Auth required. Returns the staff's **own** outlet stock **and** the read-only
district stock, **in one flat array**. `isOwnOutlet` tells them apart.

```json
{
  "success": true,
  "stock": [
    {
      "id": "665f...",
      "name": "Paracetamol 500mg",
      "packSize": "10 tablets",
      "category": "Painkiller",
      "price": 25,
      "qtyAvailable": 40,
      "isOwnOutlet": true,
      "outletName": "VS Arogya Ballari",
      "district": "Ballari"
    },
    {
      "id": "665a...",
      "name": "Cough Syrup",
      "packSize": "100 ml",
      "category": "Syrup",
      "price": 85,
      "qtyAvailable": 12,
      "isOwnOutlet": false,
      "outletName": "VS Arogya Hospet",
      "district": "Ballari"
    }
  ]
}
```
- `qtyAvailable` should be `qty - reserved`.
- Own rows = staff's outlet. District rows = other outlets with the same
  `district`.

### `GET /outlet/vendors`
The approved vendors an order can be placed for.
**You can simply reuse the existing `getAllActiveVendor` logic** — the app
already parses the server's own field names (`_id`, `store_name`,
`contact_person_name`, `mobile_no`, `full_address`, `city`, `state`,
`pin_code`). Just add `.select("-password")` and don't 404 on an empty list —
return an empty array.

### `POST /outlet/orders` — create order
Request body the app sends:
```json
{
  "type": "DELIVERY",
  "paymentMethod": "QR",
  "idempotencyKey": "outlet-1721112233-abc",
  "total": 210,
  "lines": [
    { "productId": "665f...", "name": "Paracetamol 500mg", "packSize": "10 tablets", "price": 25, "qty": 3 }
  ],
  "customer": {
    "name": "Sri Sai Medicals",
    "phone": "9876500011",
    "address": "Gandhi Nagar, Main Road, Ballari, Karnataka, 583101",
    "vendorId": "665c..."
  }
}
```

Rules:
- **`idempotencyKey` must be honoured.** If an order already exists with that
  key, return **that same order** with 200 — do not create a second one. Store
  it in `clientOrderId` (already unique + sparse).
- **Recompute `total` on the server** from your own product prices. Never trust
  the client's `total` or `price`. Reject if the client's total disagrees.
- New order starts at `AWAITING_PAYMENT` and **reserves** the stock.
- `customer.address` is present **only** for `DELIVERY`. For `COUNTER` it is
  absent — that is correct, not a bug.
- Reject if `type: "DELIVERY"` and there's no address.
- Reject if the outlet doesn't have enough available stock.

Response = the order object (see B6).

### `GET /outlet/orders`
All orders for the staff's outlet, newest first. `{ "success": true, "orders": [ ...order objects... ] }`

### `GET /outlet/orders/:id`
One order object.

### `GET /outlet/orders/:id/status`
Cheap polling endpoint — the payment screen calls this on a timer.
`{ "success": true, "status": "PAID" }`

### `POST /outlet/orders/:id/payment` — create QR / link
Body: `{ "method": "QR" }` or `{ "method": "PAYMENT_LINK" }`
```json
{
  "success": true,
  "orderId": "665f...",
  "amount": 210,
  "status": "AWAITING_PAYMENT",
  "qrImageData": "https://...  (or base64)",
  "paymentLink": null,
  "expiresAt": "2026-07-16T10:12:00.000Z"
}
```
Exactly one of `qrImageData` / `paymentLink` is filled, matching `method`.

### `POST /outlet/orders/:id/razorpay` — checkout sheet
Mirrors the existing customer `create-payment`. Amount in **paise**.
```json
{
  "success": true,
  "razorpayOrderId": "order_Nxxxx",
  "amount": 21000,
  "currency": "INR",
  "razorpayKeyId": "rzp_live_xxxx"
}
```

### `POST /outlet/orders/:id/verify` — verify signature
Body: `{ "razorpayOrderId": "...", "paymentId": "...", "signature": "..." }`
Recompute the signature server-side (same as the existing `verifyPayment`).
Only on a valid signature: set `status: "PAID"`, set `paidAt`, and **convert the
reservation into a real deduction**.
Response: `{ "success": true, "verified": true, "status": "PAID" }`

### `PUT /outlet/orders/:id/advance` — fulfilment
Body: `{ "to": "HANDED_OVER" }` (or `READY_FOR_PICKUP`, `OUT_FOR_DELIVERY`,
`DELIVERED`, `CANCELLED`).

**Must reject any fulfilment move unless the order is already `PAID` or later.**
Cancel/expire releases reserved stock.

## B6. The order object the app expects

Same shape from create, list, and detail:
```json
{
  "id": "665f...",
  "type": "DELIVERY",
  "status": "AWAITING_PAYMENT",
  "paymentMethod": "QR",
  "total": 210,
  "createdAt": "2026-07-16T09:12:00.000Z",
  "paidAt": null,
  "idempotencyKey": "outlet-1721112233-abc",
  "lines": [
    { "name": "Paracetamol 500mg", "packSize": "10 tablets", "qty": 3, "price": 25 }
  ],
  "customer": {
    "name": "Sri Sai Medicals",
    "phone": "9876500011",
    "address": "Gandhi Nagar, Main Road, Ballari, Karnataka, 583101",
    "vendorId": "665c..."
  }
}
```

## B7. Rules that must not be broken

These are hard rules in the app — please respect them server-side:

1. **The client can never mark an order paid.** Only the server, and only after
   verifying the Razorpay signature. The app only ever *reads* status.
2. **No cash, no COD** anywhere in this role. QR or payment link only.
3. **Nothing is handed over or dispatched before `PAID`.** Enforce it on the
   server, not just in the UI.
4. **District stock is read-only.** Outlet staff can only sell their own stock.

---

## 3. Marketing → Outlet stock assignment (related, please read)

The marketing app has a "Select Outlet" screen: the marketing head enters a
pincode, picks an outlet, searches medicines, enters quantities, and taps
"Done · Update stock".

**This currently saves nowhere — it's UI-only.** Once `Outlet` and `OutletStock`
exist, it needs one endpoint:

### `POST /vsArogya/marketing/outlets/:outletId/stock`
```json
{ "items": [ { "productId": "665f...", "qty": 50 } ] }
```

**Decision needed:** should this **add to** the outlet's existing stock
(`qty += 50`) or **replace** it (`qty = 50`)? The screen says "update stock",
which reads like adding. Please confirm which you implement — the app must match.

Also needed so the marketing screen can pick a real outlet:

### `GET /vsArogya/outlets?pincode=411001`
```json
{ "success": true, "outlets": [ { "id": "...", "name": "VS Arogya Ballari", "pincode": "411001" } ] }
```

---

## 4. Summary of decisions we need from you

1. **Outlet route prefix** — `/outlet/...` or `/vsArogya/outlet/...`?
2. **Agent status mapping** — confirm you'll send the raw server status
   (including `Shipped` / `Cancelled`) and we'll handle them in the app.
3. **Per-outlet stock model** — confirm the `Outlet` + `OutletStock` collections
   approach (vs. any alternative you prefer).
4. **Marketing stock assignment** — add to existing qty, or replace it?
5. **Payment expiry window** — how long before an `AWAITING_PAYMENT` outlet
   order becomes `EXPIRED` and releases stock? (15 min?)

## 5. Build order (suggested)

1. Fix `staffRoles` (add `agent`, `outlet`) — 5 minutes, unblocks both logins.
2. **Agent role** — no schema changes, 3 endpoints. Ship this first, it's small.
3. `Outlet` + `OutletStock` collections + seed one outlet.
4. `GET /outlet/stock` and `GET /outlet/vendors`.
5. Outlet orders (create with idempotency + reserve, list, detail, status).
6. Outlet payments (QR/link, razorpay, verify) — reuse the customer flow.
7. `PUT /outlet/orders/:id/advance` with the paid-gate.
8. Marketing → outlet stock assignment.
