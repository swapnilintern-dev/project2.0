# Backend fixes needed before wiring Orders + Payment (and web cart)

These are the **server-side** changes required so the Flutter Orders/Payment
(and web cart) integration can be done cleanly. Ordered by priority. Each item
says the file, the exact change, and why it matters.

> The Flutter client is intentionally NOT wired to these endpoints yet — do
> these fixes first, then we wire the app.

---

## 1. 🔴 HIGH — Make the login cookie work cross-site (web)

**File:** `server/controller/userController.js` (login, ~line 220) and logout (~246).

The cookie is `sameSite: "strict"`, so the browser never sends it from the web
app (localhost) to the render backend → web cart/orders auth fails. CORS is
already fine (`origin: true, credentials: true` in index.js).

```js
// login — change the cookie options:
res.cookie("token", token, {
  httpOnly: true,
  maxAge: 1 * 24 * 60 * 60 * 1000,
  sameSite: "none",   // was "strict"  → allow cross-site
  secure: true,        // required when sameSite is "none" (render is HTTPS)
});

// logout — clear with the SAME options so the browser actually removes it:
res.cookie("token", "", { httpOnly: true, sameSite: "none", secure: true, maxAge: 0 });
```

**Why:** without this, cart/order/payment only work on Android/iOS, never web.

---

## 2. 🔴 HIGH — Fix the "cart empty" check in place-order

**File:** `server/controller/orderController.js`, line 35.

```js
// BUG (always false → empty/₹0 orders get created):
if( !user.cart.length === 0 ) { ... }

// FIX:
if (user.cart.length === 0) {
  return res.status(400).json({ message: "Cart is empty !! Plz add product", success: false });
}
```

**Why:** `!user.cart.length === 0` evaluates as `(!length) === 0`, which is never
true, so orders can be created from an empty cart with `totalAmount: 0`.

---

## 3. 🔴 HIGH — Add a Razorpay payment-verification route

Right now `create-payment` returns a `razorpayOrderId`, but there is **no route
to verify the signature** after the user pays, so online payments can't be
confirmed securely. COD works without this; ONLINE needs it.

**New controller** in `server/controller/paymentController.js`:
```js
import crypto from "crypto";

export const verifyPayment = async (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, orderId } = req.body;

    const expected = crypto
      .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET) // match utils/razorpay.js
      .update(`${razorpay_order_id}|${razorpay_payment_id}`)
      .digest("hex");

    if (expected !== razorpay_signature) {
      return res.status(400).json({ success: false, message: "Invalid signature" });
    }

    const ord = await order.findById(orderId);
    if (!ord) return res.status(404).json({ success: false, message: "Order not found" });

    ord.paymentInfo = {
      raz_id: razorpay_payment_id,
      raz_orderId: razorpay_order_id,
      raz_signature: razorpay_signature,
      status: "Completed",
    };
    ord.paidAt = new Date();
    ord.orderStatus = "Confirm Order";
    await ord.save();

    return res.status(200).json({ success: true, message: "Payment verified" });
  } catch (er) {
    console.log("verifyPayment error:", er);
    return res.status(500).json({ success: false, message: "Internal server error" });
  }
};
```

**New route** in `server/routes/paymentRoute.js`:
```js
router.post("/verify-payment/:id", isAuthenticated, verifyPayment);
```

**Why:** lets the app confirm a real online payment server-side (HMAC check is
the standard Razorpay flow). Without it, the app can only fake success.

---

## 4. 🟠 MEDIUM — Return `role` from login (for correct routing)

**File:** `server/controller/userController.js` (login response) + `server/model/userModel.js`.

`sign_in_screen.dart` reads `response['role']` to route admin / delivery /
marketing / customer, but login returns only `{ message, success }`, so every
user lands on the customer shell.

- Add a `role` field to the Vendor/user schema (enum e.g. `["buyer","admin","delivery","marketing"]`, default `"buyer"`).
- Return it on login:
```js
return res.status(201).json({ message: "Login success", success: true, role: user.role });
```

---

## 5. 🟡 LOW (bonus, unrelated to orders) — deleteProduct crash

**File:** `server/controller/postController.js`, deleteProduct (~line 104, 116).

It uses `product.findById(...)` / `product.findByIdAndDelete(...)` but the model
is imported as `Product`. `product` is undefined → the route throws. Rename to
`Product`.

---

## After these are done

Tell me and I'll wire the Flutter side:
- `placeOrder` → `POST /place-order` (shipping address) → `POST /create-payment/:orderId` (COD / ONLINE).
- ONLINE → open Razorpay with the server `razorpayOrderId` → `POST /verify-payment/:id` on success.
- `getOrders` → `GET /get-order` (mapped to the app's `Order` model).
- `cancelOrder` → `PUT /cancel-order/:orderId`.
- Web cart + orders will start working once fix #1 lands.
