# Order Lifecycle · Invoice · Stock — Backend Integration Contract

> **Audience:** backend developer. The Flutter app (vendor / marketing / admin
> panels) has been fully implemented against the contracts below. **No file in
> `server/` was modified by the app team** — this document is the exact spec to
> implement on the server. Until each item lands, the app degrades gracefully
> (it shows the server's error message and offers a retry; it never fakes
> success).

Base URL: `https://backend-new-0ady.onrender.com` (see `lib/services/api_config.dart`).
All paths below are under the existing `/vsArogya` prefix.

---

## Business rules being implemented

1. **Invoice only after acceptance.** A vendor-placed order starts `Pending`.
   The invoice (document + PDF) must be generated **only when marketing
   accepts** the order — never at place-order time. The app already hides all
   invoice UI while `orderStatus == "Pending"`, so the client is safe either
   way, but the invoice/PDF generation block currently inside
   `orderController.placeOrder` should MOVE into the accept flow.
2. **Stock is deducted at accept, restored on cancel-before-delivery, and can
   never go negative.** The server is the single source of truth — the app
   never computes or writes stock; it only re-reads `/all-products` after
   accept/cancel.
3. **Marketing can create an order on a vendor's behalf** (phone orders), with
   an audit trail (`source`, `createdBy`) and idempotent creation.

---

## 1) Accept order — `PUT /vsArogya/confirm-order/:id` (existing route, extend)

Current behaviour: sets `orderStatus = "Confirm Order"` only.

Required behaviour (all-or-nothing):

1. Load the order with `orderItems.product` populated. Reject if not `Pending`.
2. **Stock check first** — for every line, if `product.stock < quantity`:
   do **not** modify anything and reply:

   ```json
   HTTP 409
   {
     "success": false,
     "message": "Insufficient stock for Paracetamol 500mg: available 4, ordered 10"
   }
   ```

   The app shows `message` **verbatim** to the marketing user and rolls the
   card back to Pending — so please keep this exact human-readable shape.
3. Atomically decrement each product's stock (e.g. `findOneAndUpdate` with
   `stock: { $gte: quantity }` filter + `$inc: { stock: -quantity }` per line,
   to survive concurrent accepts). Stock must never go below 0.
4. Set `orderStatus = "Confirm Order"`.
5. **Generate the invoice NOW** (move the invoice-number / GST-slab / HTML →
   PDF → Cloudinary → `invoice.create` block out of `placeOrder` into this
   handler), and link it: `order.invoice = createdInvoice._id`.
6. Reply:

   ```json
   HTTP 200
   {
     "success": true,
     "message": "order confirmed",
     "order": {
       "_id": "665f…",
       "orderStatus": "Confirm Order",
       "invoice": {
         "invoiceNumber": "INV-1720340000000",
         "pdfUrl": "https://res.cloudinary.com/…/invoices/….pdf"
       }
     }
   }
   ```

App behaviour already wired: on success it re-fetches `/all-orders`,
`/all-products` and the vendor panel picks the change up via its poll; on
failure it shows `message` and reverts the optimistic status.

## 2) Cancel order — `PUT /vsArogya/cancel-order/:id` (existing route, extend)

Current behaviour: owner-only; sets `Cancelled` unless `Delivered`.

Required changes:

1. **Authorize staff too.** Besides the order's owner, allow users whose
   `role` is `marketing` or `admin` (the app sends the logged-in staff JWT as
   `Authorization: Bearer <token>` and/or the cookie). Keep the Delivered
   guard: delivered orders can never be cancelled (already enforced — the app
   also hides the button).
2. **Restore stock** when the order had already been accepted (i.e. its status
   is `Confirm Order` / `Shipped` / `Out for Delivery`): `$inc` each line's
   product stock by `+quantity`. A `Pending` order never had stock deducted,
   so nothing to restore.
3. Reply (unchanged shape):

   ```json
   HTTP 200
   { "success": true, "message": "order cancel successfully" }
   ```

App behaviour already wired: vendor panel awaits the call and re-fetches
products; marketing/admin show a confirm dialog, call this route with the
staff token, and refresh orders + stock on success.

## 3) Manual order by marketing — `POST /vsArogya/manual-order` (**NEW route**)

Route: `router.post("/manual-order", isAuthenticated, createManualOrder)`.

Request (JSON, staff JWT in `Authorization` header):

```json
{
  "vendorId": "664a1f2e9b8c7d0012345678",
  "items": [
    { "productId": "6650aa11bb22cc33dd445566", "quantity": 10 },
    { "productId": "6650aa11bb22cc33dd445577", "quantity": 2 }
  ],
  "source": "MANUAL_BY_MARKETING",
  "clientOrderId": "MO-1720340000000-4821"
}
```

Required behaviour:

1. **Idempotency:** if an order with this `clientOrderId` already exists,
   return it with `200` instead of creating a duplicate (the app reuses the
   same `clientOrderId` when the user retries after a network drop, and it
   disables the submit button while a request is in flight).
2. Validate the vendor exists (and is `Approved`) and every product exists.
   Reject empty `items`.
3. Create the order exactly like `placeOrder` does, except:
   - `user = vendorId` (so the vendor sees it in their own panel via
     `GET /get-order` — no extra work needed),
   - `shippingAddress` from the vendor's registered profile
     (`full_address`, `city`, `state`, `pincode`, country `"India"`,
     `phoneNo = mobile_no`),
   - `orderPrice` snapshotted from each product's current price,
   - `totalAmount` / `orderNo` / `amountWord` computed the same way,
   - **audit fields:** `source: "MANUAL_BY_MARKETING"`,
     `createdBy: req.id` (the authenticated marketing user),
     `clientOrderId` stored for the idempotency check.
4. The order starts `Pending` — **no invoice, no stock change** (both happen
   at accept, rule #1/#2). Same lifecycle as any vendor-placed order.
5. Reply:

   ```json
   HTTP 201
   {
     "success": true,
     "message": "Order created for vendor",
     "Order": { "_id": "…", "orderStatus": "Pending", "source": "MANUAL_BY_MARKETING", … }
   }
   ```

### Order schema additions (`server/model/orderModel.js`)

```js
source:        { type: String },                                    // "MANUAL_BY_MARKETING"
createdBy:     { type: mongoose.Schema.Types.ObjectId, ref: "Vendor" },
clientOrderId: { type: String, index: true },                       // idempotency key
```

`GET /all-orders` should include `source` in each order (it will automatically
once it's on the schema) — the app renders a blue **Manual** badge from it.

## 4) Populated invoice in order reads (small change, big UX win)

- `GET /get-order` (vendor) and `GET /all-orders` (staff): add
  `.populate("invoice")` so each accepted order carries
  `invoice: { invoiceNumber, pdfUrl }`. The app then shows the **real**
  invoice number instead of a derived reference, and can open the PDF directly
  from `pdfUrl`.
- `GET /prev-invoice/:id` (existing) keeps working as the PDF source — the
  staff panels and the vendor panel both use it (302 → hosted PDF). No change
  needed there.

---

## Endpoint summary the app now calls

| Endpoint | Used by | Status |
|---|---|---|
| `PUT /vsArogya/confirm-order/:id` | Marketing/Admin accept | exists — extend per §1 |
| `PUT /vsArogya/shipped-order/:id`, `/outof-delivery/:id`, `/delivered-prder/:id` | Marketing/Admin pipeline | exists — unchanged |
| `PUT /vsArogya/cancel-order/:id` | Vendor (own), Marketing, Admin | exists — extend per §2 |
| `POST /vsArogya/manual-order` | Marketing manual order | **new** per §3 |
| `GET /vsArogya/all-vendors` | Manual-order vendor picker | exists — unchanged |
| `GET /vsArogya/all-products` | Live stock everywhere | exists — unchanged |
| `GET /vsArogya/all-orders`, `GET /vsArogya/get-order` | Order lists | exists — add `.populate("invoice")` + `source` per §3/§4 |
| `GET /vsArogya/prev-invoice/:id` | Invoice PDF (all roles) | exists — unchanged |

---

## Manual test checklist (app ↔ backend)

**Invoice gating**
1. Vendor places an order → vendor Order Details shows status **Pending
   Approval**, a "Pending approval — invoice will be generated once accepted"
   note, and **no** invoice button/number anywhere.
2. Marketing → Orders → New → **Accept** → order moves to Confirmed.
3. Vendor panel (within the ~8s poll) shows **Order Confirmed** and the **Tax
   Invoice** card appears (real invoice number once §4 lands); Preview /
   Download PDF works.
4. Marketing order details + Admin order sheet show **View Invoice** and open
   the same PDF.

**Stock deduct / restore**
5. Note a product's stock (Marketing → Products). Accept an order containing
   it → stock drops by the ordered quantity in the marketing inventory, the
   manual-order product picker and the vendor shop (no manual refresh).
6. Cancel that accepted order (marketing/admin, before delivery) → stock
   returns to the original number everywhere.
7. Set a product's stock below an order's quantity, then Accept → the accept
   FAILS, the card stays in New/Pending, and the snack shows
   "Insufficient stock for <product>: available X, ordered Y".
8. Deliver an order → the Cancel action disappears in every panel.

**Manual order**
9. Marketing → Orders → **Create Manual Order** FAB → pick a vendor
   (searchable) → add products (live stock badges; out-of-stock rows are not
   selectable) → quantity + beyond stock is blocked with a clear message →
   review summary → submit.
10. The new order appears in the marketing pipeline as **Pending** with a
    **Manual** badge, and in that vendor's own panel like any normal order.
11. Accept it → invoice + stock behave exactly as steps 2–5.
12. Kill connectivity and submit → error banner + **Retry** button; the button
    is disabled while in flight; retrying after reconnect creates exactly ONE
    order (idempotent `clientOrderId`).
13. Submit with no vendor / no products → blocked with a clear message.
