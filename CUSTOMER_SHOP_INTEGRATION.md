# Customer Shop — Backend Integration Guide (Products + Cart)

How the customer shop loads products and syncs the cart with the backend, where
each piece lives, and the known limits. (Companion to
[VENDOR_REGISTRATION_INTEGRATION.md](VENDOR_REGISTRATION_INTEGRATION.md).)

> **Design change:** The shop used to be a live view of the **Marketing**
> in-app inventory (`MarketingProductsController`). It now sources products from
> the **backend** (`GET /vsArogya/all-products`). The customer → marketing link
> in `catalog.dart` was removed.

---

## 1. Files involved

| File | Role |
|---|---|
| [lib/customer/catalog.dart](lib/customer/catalog.dart) | Facade + in-memory product cache. Screens read `Catalog.all` / `Catalog.byId` / `Catalog.listenable`. |
| [lib/customer/customer_api.dart](lib/customer/customer_api.dart) | Network calls for products + cart. |
| [lib/customer/customer_controllers.dart](lib/customer/customer_controllers.dart) | `CartController` — local cart state; mirrors changes to the backend. |
| [lib/services/auth_service.dart](lib/services/auth_service.dart) | `login()` captures the session cookie into `AuthService.sessionCookie`. |
| [lib/auth/session.dart](lib/auth/session.dart) | `logout()` clears the cart + session cookie. |
| `server/controller/postController.js` | `getAllProducts` |
| `server/controller/cartController.js` | add / get / increase / decrease / remove / clear |
| `server/middlewares/isAuthenticated.js` | reads the JWT from `req.cookies.token` |

---

## 2. Products flow

```
Home / Product list screen (initState)
      │  _api.getProducts()
      ▼
CustomerApi.getProducts()
      │  GET /vsArogya/all-products
      │  body.products → Product.fromJson(...)
      ▼
Catalog.setProducts(list)   ← fills the cache, notifies listeners
      ▼
Screens read Catalog.all / Catalog.byId(id) / listen to Catalog.listenable
```

- **No auth needed** for products → works on web and mobile.
- Offline fallback: if the request fails, the cached list is kept; if the cache
  is empty, `MockData.products` is seeded so the shop is never blank.
- `Product.fromJson` already maps the backend shape (`_id`, `image:[{url}]`,
  `price` as number/string).

---

## 3. Cart flow

The **local `CartController` is authoritative** for the UI. Every mutation is
mirrored to the backend **best-effort** (fire-and-forget, never blocks, never
throws). So the cart always works locally; the server copy stays in sync when
the user is authenticated.

| CartController method | Backend mirror | Route |
|---|---|---|
| `add(product, qty)` | `addToCart` (1 add + qty-1 increases) | `POST /add-cart/:id` (+ `/increase-cart-item/:id`) |
| `setQuantity` / `increment` / `decrement` | `increaseCartItem` / `decreaseCartItem` (by delta) | `POST /increase-cart-item/:id`, `POST /dec-cart-itm/:id` |
| `remove` | `removeFromCart` | `DELETE /remove-cart-item/:id` |
| `clear` | **not mirrored** (see below) | — |
| (read) | `getCart` → `List<CartItem>` | `GET /getCart-product` |

Why `clear()` is **not** mirrored: it runs on logout (via
`resetCustomerSession`) and after placing an order. Mirroring it would risk
wiping the server cart in those flows, so the order/logout flow owns that.

---

## 4. Authentication (important)

- Login (`POST /login`) does **not** return a token in the JSON body. It sets an
  **httpOnly cookie** `token`, and `isAuthenticated` only reads
  `req.cookies.token`.
- `AuthService.login` captures the `Set-Cookie` header into
  `AuthService.sessionCookie` (`"token=..."`), and `CustomerApi` resends it as
  the `Cookie` header on every call.

| Platform | Cart auth works? | Why |
|---|---|---|
| **Android / iOS / desktop** | ✅ Yes | `http` exposes Set-Cookie and lets us set the Cookie header. |
| **Web (Chrome)** | ❌ Not yet | Browsers hide Set-Cookie from JS and block manual Cookie headers; `SameSite=strict` + cross-origin also blocks it. Needs **backend** CORS (`Access-Control-Allow-Credentials`) + `SameSite=None; Secure`. |

On web the cart still works **locally**; only the server mirror is skipped.

---

## 5. Known gaps / next steps

- **Web cart auth** — needs the backend cookie/CORS change above (server-side).
- **Login role** — `/login` doesn't return `role`, so `sign_in_screen` always
  lands on the customer shell. Add `role` to the login response to route admins/
  delivery/marketing.
- **Stock** — the backend product model has no stock field, so
  `Catalog.decrementForOrder` is a no-op and "Out of Stock" never shows.
- **Orders / Payment** — still mock (`CustomerApi.placeOrder` / `getOrders`).
  That's the next integration.

---

## 6. Quick test

```bash
flutter run            # Android (cart auth works here)
# or: flutter run -d chrome   (products work; cart syncs locally only)
```
1. Make sure the backend has products (POST /add-product) so the shop isn't empty.
2. Log in → shop loads from `/all-products`.
3. Add items / change quantity / remove → on Android, check the server cart via
   `GET /getCart-product`.
