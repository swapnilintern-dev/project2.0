// =============================================================================
// VS Arogya — Area Agent · Session
//
// Tiny in-memory identity for the signed-in Area Agent (name + assigned
// pincode). Mirrors lib/outlet/outlet_session.dart. Populated at login (via the
// demo hook or, later, the backend) and cleared on logout so nothing leaks into
// the next account's session.
// =============================================================================

class AgentSession {
  AgentSession._();
  static final AgentSession instance = AgentSession._();

  String? _name;
  String? _pincode;

  String get name => _name ?? 'Area Agent';
  String get pincode => _pincode ?? '';
  bool get isSignedIn => _name != null;

  void signIn({String? name, String? pincode}) {
    _name = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Area Agent';
    _pincode = pincode?.trim();
  }

  void clear() {
    _name = null;
    _pincode = null;
  }
}
