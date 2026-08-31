// =============================================================================
// VS Arogya — Calendar dates on the wire
//
// Batch expiry, manufacturing and drug-licence dates are CALENDAR dates: "31
// December 2028" means that day everywhere, with no time and no timezone. They
// come out of `showDatePicker`, which returns LOCAL midnight.
//
// Serialising that with `toIso8601String()` produces "2028-12-31T00:00:00.000"
// — an ISO timestamp with NO timezone designator. Both the backend's
// parseDateInput and a bare Mongoose `type: Date` cast hand such a string to
// `new Date(...)`, which per the ECMAScript spec reads it as the SERVER's local
// time. On Render (UTC) that happens to land on the right day; on a machine
// running in IST it becomes 2028-12-30T18:30:00Z, and the app — which reads the
// UTC calendar fields back — then shows the lot expiring in December 30, or a
// month early once the day is the 1st. For medicine expiry that is not a
// cosmetic bug.
//
// Sending a date-only "YYYY-MM-DD" removes the ambiguity: the spec defines
// date-only forms as UTC, so the stored instant is UTC midnight of exactly the
// day the user picked, whatever timezone either the phone or the server is in.
// The backend already documents and accepts this form (server/utils/parseDate.js
// normalises date-only values to UTC midnight).
// =============================================================================

/// Formats [date] as the timezone-independent `YYYY-MM-DD` the API expects for
/// a calendar date. Uses the date's own calendar fields, so a picker's local
/// midnight keeps the day the user actually tapped.
///
/// Use this for expiry / manufacturing / licence dates. Do NOT use it for
/// instants (order placed-at, paid-at) — those are points in time and keep
/// their full ISO-8601 representation.
String apiCalendarDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
