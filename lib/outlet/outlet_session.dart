// =============================================================================
// VS Arogya — Outlet Staff · Session
//
// Holds the signed-in outlet staff's identity for the duration of the session.
// This is the state the outlet "route guard" checks: [OutletMain] refuses to
// render (and bounces to sign-in) unless [isSignedIn] is true.
//
// Set on sign-in by OutletApi.login (POST /outlet-login), which captures the
// outlet id + token every outlet-scoped call needs; cleared on logout.
// Mirrors DeliveryController's in-memory session pattern.
// =============================================================================

class OutletSession {
  OutletSession._();
  static final OutletSession instance = OutletSession._();

  String? staffName;
  String? outletName;
  String? district;

  /// The signed-in outlet's `_id` from the backend. Every outlet-scoped call
  /// needs it (GET /outlet-products/:id), so a session is only usable once
  /// this is set.
  String? outletId;

  /// Session auth captured from POST /outlet-login. [token] is the reliable
  /// path (the server's cookie is httpOnly + sameSite:strict, so it never comes
  /// back on web); [cookie] is kept for parity with AuthService.
  String? token;
  String? cookie;

  /// True once an outlet staff member has signed in this session.
  bool get isSignedIn => (outletName ?? '').isNotEmpty;

  /// True when this session is backed by a real backend login (not the local
  /// demo hook) — i.e. outlet-scoped API calls can actually be made.
  bool get isLive => (outletId ?? '').isNotEmpty;

  /// A friendly label for the header ("Ballari Outlet · Ballari").
  String get outletLabel {
    final o = outletName ?? 'Outlet';
    final d = district ?? '';
    return d.isEmpty ? o : '$o · $d';
  }

  void signIn({
    String? name,
    String? outlet,
    String? district,
    String? outletId,
    String? token,
    String? cookie,
  }) {
    staffName = name;
    outletName = outlet ?? 'Outlet';
    this.district = district ?? '';
    this.outletId = outletId;
    this.token = token;
    this.cookie = cookie;
  }

  void clear() {
    staffName = null;
    outletName = null;
    district = null;
    outletId = null;
    token = null;
    cookie = null;
  }
}
