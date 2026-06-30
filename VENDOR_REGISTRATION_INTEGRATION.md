# Vendor Registration — Backend Integration Guide

This document explains, **step by step**, how the Vendor Registration screen talks
to the backend, where every value lives, and how to fix the most likely bugs.

> TL;DR — The screen fills a `VendorRegistrationModel`, the Submit button calls
> `VendorApiService.registerVendor(model)`, and that builds **one multipart
> request** (text fields + document bytes) and POSTs it to
> `/vsArogya/register-vendor`. Works on **Android, iOS and Web**.

---

## 1. The files involved

| File | Role |
|---|---|
| [lib/vendor_registration_screen.dart](lib/vendor_registration_screen.dart) | UI, 4 steps, validation, holds `VendorRegistrationModel _model` |
| [lib/services/vendor_api_service.dart](lib/services/vendor_api_service.dart) | Builds + sends the network request, parses the reply |
| [lib/services/api_config.dart](lib/services/api_config.dart) | `ApiConfig.baseUrl` (shared base URL) |
| `server/routes/userRoute.js` | Declares the route + multer file keys |
| `server/middlewares/multer.js` | Which file types/sizes are allowed |
| `server/controller/userController.js` | Reads the fields, uploads to Cloudinary, saves vendor |

> Note: `lib/api_folder/register_api.dart` (`RegisterApi`) is an **empty unused
> stub**. The working path is `VendorApiService`. You can delete `RegisterApi`
> to avoid confusion — nothing references it.

---

## 2. The end-to-end flow (one by one)

```
User fills Step 1–3
      │  (_saveBasic / _saveBusiness / file pickers)
      ▼
_model  (VendorRegistrationModel)         ← all values live here
      │
Step 4 "🚀 Submit Registration" button
      │  onPressed: _submit
      ▼
_submit()                                  ← vendor_registration_screen.dart
      │  await VendorApiService().registerVendor(_model)
      ▼
registerVendor(model)                      ← vendor_api_service.dart
      │  builds http.MultipartRequest:
      │    • request.fields[...]  = text
      │    • request.files.add(...) = document BYTES
      ▼
POST {baseUrl}/vsArogya/register-vendor
      ▼
Backend (multer → controller → Cloudinary → MongoDB)
      ▼
{ success: true/false, message, vendor }
      ▼
_submit() shows success screen OR _showSnack(message)
```

---

## 3. Where each value is declared

### Text values
- Typed into `TextEditingController`s (`_storeNameCtrl`, `_mobileCtrl`, …) declared
  in `_VendorRegistrationScreenState`.
- Copied into `_model` by `_saveBasic()` and `_saveBusiness()` when the user
  taps **Continue**.

### Document values
- Declared in `VendorRegistrationModel` as **`XFile?`** (not a String path):
  ```dart
  XFile? storePhotoFile;
  XFile? drugLicenseCopyFile;
  XFile? gstCertificateFile;
  ```
- Filled by `_pickDoc()` → stores the whole `XFile` (so `readAsBytes()` works on
  every platform). A blob URL string is NOT enough — the server needs the bytes.

---

## 4. Field mapping (Flutter → Backend)

**These names MUST match the backend exactly.** Change one side, change the other.

### Text fields (`request.fields`)
| Model (`_model`) | Backend field (`req.body`) |
|---|---|
| `vendorType` | `vendor_type` |
| `shopType` | `shop_type` |
| `storeName` | `store_name` *(required)* |
| `contactPerson` | `contact_person_name` |
| `mobile` | `mobile_no` *(required)* |
| `email` | `email` *(required, unique)* |
| `fullAddress` | `full_address` |
| `city` | `city` |
| `state` | `state` |
| `pinCode` | `pin_code` |
| `gstStatus` (UI label) | `gst_status` → mapped to `"yes"`/`"no"` |
| `drugLicenseNumber` | `drug_lic_no` |
| `drugLicenseExpiry` | `drug_lic_ex_date` (ISO 8601) |

### File fields (`request.files`)
| Model (`_model`) | Backend multer key | Required? |
|---|---|---|
| `storePhotoFile` | `store_pic` | **Yes** (backend rejects without it) |
| `drugLicenseCopyFile` | `drug_lic_copy` | Yes (enforced in the UI) |
| `gstCertificateFile` | `gst_pdf` | Optional |

---

## 5. What the backend requires (so the upload succeeds)

1. **Multipart, not JSON.** Files cannot go in a JSON body. We use
   `http.MultipartRequest`.
2. **Correct `Content-Type` per file.** multer's `fileFilter` only allows
   `image/jpeg`, `image/png`, `image/webp`, `application/pdf`. We set this from
   the file extension in `_contentTypeFor()`.
3. **Filename must have an extension** (e.g. `shop.jpg`). The backend's
   `datauri.js` does `path.extname(originalname)`; no extension → Cloudinary
   upload breaks. `_safeName()` guarantees an extension.
4. **Size < 10 MB** each (multer limit). Images are downscaled at pick time
   (`maxWidth/maxHeight: 1600, imageQuality: 85`).
5. **`store_pic` is mandatory** — backend returns `"Store image is required"`
   otherwise.

---

## 6. The response

The service returns a `VendorApiResult`:
```dart
class VendorApiResult {
  final bool success;          // true only if HTTP 2xx AND body.success == true
  final String message;        // backend message, shown in a snackbar
  final Map<String, dynamic>? vendor;
}
```
On success → `RegistrationSuccessScreen`. On failure → snackbar with `message`.

---

## 7. Changing the server URL

`ApiConfig.baseUrl` / `VendorApiService.baseUrl` =
`https://backend-new-0ady.onrender.com`.

Override at run time without editing code:
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000
```
- Android emulator → host machine = `http://10.0.2.2:3000`
- iOS sim / desktop → `http://localhost:3000`
- Physical device → your PC's LAN IP

---

## 8. Common bugs & how to fix them

| Symptom | Likely cause | Fix |
|---|---|---|
| Web: text saves but no image reaches server | (old bug) blob URL sent instead of bytes | Already fixed — we send `XFile.readAsBytes()`. Confirm `_attachFile` uses `MultipartFile.fromBytes`. |
| `"Store image is required"` | `store_pic` not attached | Ensure `storePhotoFile != null` before submit; check the multer key spelling. |
| `"Only Images and PDFs are allowed"` | Wrong `Content-Type` | Check `_contentTypeFor()` / file extension. |
| Cloudinary error on GST / drug license | Filename had no extension | `_safeName()` should add one; verify `XFile.name`/`mimeType`. |
| `gst_status` validation error | Backend enum is `["yes","no"]` | `_gstStatusForApi()` maps the UI label — don't send the raw label. |
| Web: request blocked / CORS error in console | Backend must allow the web origin | Enable CORS for your localhost origin on the server (server-side fix). |
| Field saved but `undefined` on server | Frontend/backend name mismatch | Compare against the table in §4. |
| Hangs then "Request timed out" | Server asleep (Render free tier) / no network | Retry; first request to a sleeping Render server is slow. |
| PDF can't be selected | `ImagePicker` only picks images | Use `file_picker` if PDF support is needed (not wired yet). |

---

## 9. Quick test

```bash
flutter run -d chrome      # or: flutter run   (Android)
```
1. Fill Steps 1–3, upload **Store Photo** + **Drug License Copy**.
2. Step 4 → **🚀 Submit Registration**.
3. Watch the console + the snackbar for the backend `message`.
4. Success → you land on the "Registration Submitted!" screen.
