# Batch & Expiry — Invoice (DONE) + optional hardening

## Status: implemented ✅

Batch + Expiry render **inside the Description cell**, below the medicine name —
no extra row, no extra column, existing table width kept. The only file changed
was `server/templates/invoiceTemplate.js`:

- Added an `expText()` formatter → `Jul-2027` (locale-safe; `"N/A"` for old orders).
- The Description `<td>` now renders:
  `<strong>${title}</strong><br><span style="font-size:9px;color:var(--text-muted);">Batch: … | Exp: …</span>`
  (reuses the same muted-9px style the GST cell already uses).

`invoice.html` was **not** touched — template/layout/fonts/colours/totals all
unchanged. Data was already supplied by `invoiceGenerator.js` (`batch_no`/
`exp_date` per item).

Verified by rendering:
`Paracetamol 650 Tablet` → `Batch: BCH240701A | Exp: Jul-2027`; old product →
`Batch: N/A | Exp: N/A`.

> Note: invoice generation is idempotent — an order that already has an invoice
> keeps its cached PDF. The batch row therefore appears on **newly generated**
> invoices (orders accepted/placed after deploy), not on already-generated ones.

---

## Order-line batch snapshot — also DONE ✅

"Never fetch latest batch": the invoice now reflects the **exact batch sold**,
frozen at order time, so a later batch edit on the product can't rewrite a
historical invoice.

1. `orderModel.js` → each `orderItems` sub-doc gained `batch_no: String`,
   `exp_date: Date` (optional → old orders still valid).
2. All 5 order-creation paths snapshot `product.batch_no`/`exp_date` onto the
   line: `orderController.js` (vendor cart + buy-now), `manualOrderController.js`
   (marketing), `outletController.js` (outlet checkout + outlet items order).
3. `invoiceGenerator.js` prefers the snapshot:
   `batch_no: it.batch_no || it.product?.batch_no || "N/A"` (same for exp_date).

The two inline outlet invoice builders (outletController.js ~582, ~858) generate
the PDF at sale time from the freshly-read product, so they already reflect the
sold batch — left unchanged.

Backward compatible: orders placed before this change have no line snapshot →
fall back to the product's batch → then `"N/A"`.
