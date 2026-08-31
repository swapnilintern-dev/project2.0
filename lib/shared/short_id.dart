// =============================================================================
// VS Arogya — Short Order Id
//
// The canonical way to render a backend id in the UI. Extracted here because
// the same six-character form was already being redefined per-screen (Admin
// Orders, Admin Overview, Delivery Tasks, Delivery History) and the roles that
// did NOT use it were overflowing their layouts.
//
// WHY SIX, AND WHY THE TAIL:
//
// Backend ids are 24-character Mongo ObjectIds. Two things follow from that.
//
//   • They are too wide to sit beside a status pill. At 18/w800 the string
//     "Order #6a7d57c7fd2912e52c42286e" is wider than a phone card, and the
//     Rows that hold it use Spacer()/spaceBetween — which only distribute
//     LEFTOVER space, so with none left the row overflows rather than shrinks.
//
//   • An ObjectId OPENS with a 4-byte timestamp, so every order placed in the
//     same window shares its leading characters (6a7d61bd…, 6a7d5968…,
//     6a7d57c7…). Truncating with a trailing ellipsis would therefore render
//     same-day orders visually identical — fixing the overflow while destroying
//     the user's ability to tell one order from another. The TAIL is the part
//     that actually varies, so that is the part worth showing.
//
// Uppercased because these get read aloud and written down.
// =============================================================================

/// The last six characters of a backend id, uppercased — e.g.
/// `6a7d57c7fd2912e52c42286e` → `42286E`. Ids of six characters or fewer are
/// returned whole.
String shortId(String id) {
  if (id.length <= 6) return id.toUpperCase();
  return id.substring(id.length - 6).toUpperCase();
}
