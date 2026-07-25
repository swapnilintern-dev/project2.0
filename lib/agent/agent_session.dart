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

  /// The agent's backend `_id` and JWT — set only for a REAL backend login
  /// (a Vendor with role "agent"). Null for the local demo login, which is what
  /// tells the dashboard to fall back to mock data instead of the live API.
  String? _agentId;
  String? _token;

  String get name => _name ?? 'Area Agent';
  String get pincode => _pincode ?? '';
  String? get agentId => _agentId;
  String? get token => _token;
  bool get isSignedIn => _name != null;

  /// True when this session is backed by a real backend login — i.e. the
  /// pincode-wise order/vendor calls can actually be made.
  bool get isLive => (_agentId ?? '').isNotEmpty;

  void signIn({String? name, String? pincode, String? agentId, String? token}) {
    _name = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Area Agent';
    _pincode = pincode?.trim();
    _agentId = (agentId != null && agentId.trim().isNotEmpty) ? agentId.trim() : null;
    _token = (token != null && token.trim().isNotEmpty) ? token.trim() : null;
  }

  void clear() {
    _name = null;
    _pincode = null;
    _agentId = null;
    _token = null;
  }
}
