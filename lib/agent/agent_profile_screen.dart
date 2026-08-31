// =============================================================================
// VS Arogya — Area Agent · Profile
//
// The agent's own account, opened from the dashboard header. Fetched live from
// the backend (GET /vsArogya/agent-profile/:id) so name, pincode and contact
// details always match what marketing registered. A demo (non-live) session
// falls back to the identity captured at sign-in. Ends with a sign-out action.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import '../auth/session.dart' show logout;
import '../services/live_refresh.dart';
import 'agent_api.dart';
import 'agent_session.dart';

class AgentProfileScreen extends StatefulWidget {
  const AgentProfileScreen({super.key});

  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends State<AgentProfileScreen>
    with LiveRefreshMixin {
  final _api = AgentApi();

  AgentProfile? _profile;
  bool _loading = false;
  String? _error;

  // The profile changes rarely — a slow poll keeps it fresh without noise.
  @override
  Duration get liveRefreshInterval => const Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    // First load, then keep it live (poll + app-resume); immediate: false avoids
    // a duplicate fetch on open.
    _load();
    startLiveRefresh(immediate: false);
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => _load();

  Future<void> _load() async {
    final session = AgentSession.instance;

    // Demo login (no backend id) — show what we captured at sign-in.
    if (!session.isLive) {
      setState(() {
        _profile = AgentProfile(
          id: '',
          name: session.name,
          pincode: session.pincode,
        );
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final (profile, error) =
        await _api.fetchProfile(session.agentId!, token: session.token);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (error != null) {
        _error = error;
      } else {
        _profile = profile;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _identityCard(),
            if (_loading && _profile == null)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _profile == null)
              _errorBox(_error!)
            else if (_profile != null) ...[
              const SizedBox(height: 14),
              _detailsCard(_profile!),
            ],
            const SizedBox(height: 14),
            _signOutButton(),
          ],
        ),
      ),
    );
  }

  Widget _identityCard() {
    final p = _profile;
    final name = p != null && p.name.isNotEmpty
        ? p.name
        : AgentSession.instance.name;
    final pincode = p != null && p.pincode.isNotEmpty
        ? p.pincode
        : AgentSession.instance.pincode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkGreen, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Area Agent',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800)),
                if (pincode.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('Pincode $pincode',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(AgentProfile p) {
    final rows = <Widget>[
      if (p.name.isNotEmpty)
        _infoRow(Icons.person_outline, 'Name', p.name),
      if (p.mobileNo.isNotEmpty)
        _infoRow(Icons.call_outlined, 'Mobile', p.mobileNo),
      if (p.email.isNotEmpty)
        _infoRow(Icons.mail_outline, 'Email', p.email),
      if (p.pincode.isNotEmpty)
        _infoRow(Icons.pin_drop_outlined, 'Assigned pincode', p.pincode),
      if (p.fullAddress.isNotEmpty)
        _infoRow(Icons.location_on_outlined, 'Address', p.fullAddress),
      if (p.approvalStatus.isNotEmpty)
        _infoRow(Icons.verified_user_outlined, 'Status', p.approvalStatus),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.darkGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.greyText)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 40, 4, 8),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.greyText, size: 36),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.greyText)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _signOutButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => logout(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.red),
              SizedBox(width: 12),
              Text('Sign out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
