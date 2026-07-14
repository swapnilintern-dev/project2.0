// =============================================================================
// VS Arogya — Outlet Staff · Session
//
// Holds the signed-in outlet staff's identity for the duration of the session.
// This is the state the outlet "route guard" checks: [OutletMain] refuses to
// render (and bounces to sign-in) unless [isSignedIn] is true.
//
// Set on sign-in (demo login hook in sign_in_screen.dart, and homeForRole in
// auth/session.dart for a restored/real "outlet" role); cleared on logout.
// Mirrors DeliveryController's in-memory session pattern.
// =============================================================================

class OutletSession {
  OutletSession._();
  static final OutletSession instance = OutletSession._();

  String? staffName;
  String? outletName;
  String? district;

  /// True once an outlet staff member has signed in this session.
  bool get isSignedIn => (outletName ?? '').isNotEmpty;

  /// A friendly label for the header ("Ballari Outlet · Ballari").
  String get outletLabel {
    final o = outletName ?? 'Outlet';
    final d = district ?? '';
    return d.isEmpty ? o : '$o · $d';
  }

  void signIn({String? name, String? outlet, String? district}) {
    staffName = name;
    outletName = outlet ?? 'Ballari Outlet';
    this.district = district ?? 'Ballari';
  }

  void clear() {
    staffName = null;
    outletName = null;
    district = null;
  }
}
