// =============================================================================
// MediCaPlus — Admin · Delivery Management (pushed from Overview / Users)
//
// The agent-onboarding console. A live stat strip (total agents / on-duty /
// pending), then a "Create New Agent Login" form: name, mobile, email. On
// "Create Agent" the details are sent to the backend (POST /agent-create),
// which creates the delivery agent and generates a 6-digit password. That
// SERVER-generated password is shown back here so the admin can share it with
// the agent (the login id is the agent's mobile number).
//
// NOTE: the backend does not currently email the credentials — it only returns
// them — so this screen surfaces them for the admin to send. Automatic email
// requires a server change (add nodemailer to the agent-create controller).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../../services/live_refresh.dart';
import '../admin_api.dart';
import '../admin_common.dart';
import '../admin_models.dart';

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({super.key});

  @override
  State<DeliveryManagementScreen> createState() =>
      _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen>
    with LiveRefreshMixin {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();

  bool _saving = false;

  /// The real delivery agents on the platform (users with role "delivery"),
  /// fetched live for the stat strip. Null until the first load answers.
  List<PlatformUser>? _agents;

  @override
  void initState() {
    super.initState();
    // Load on open, then keep the agent stat strip live (poll + app-resume).
    startLiveRefresh();
  }

  @override
  Future<void> onLiveRefresh() => _loadAgents();

  Future<void> _loadAgents() async {
    final users = await AdminApi().getAllPlatformUsers();
    if (!mounted || users == null) return;
    setState(() {
      _agents = users.where((u) => u.kind == UserKind.agent).toList();
    });
  }

  /// Distinct cities the agents cover (from their profile city rows).
  int get _citiesCovered {
    final cities = <String>{};
    for (final a in _agents ?? const <PlatformUser>[]) {
      for (final i in a.info) {
        if (i.label == 'City' && i.value.trim().isNotEmpty) {
          cities.add(i.value.trim().toLowerCase());
        }
      }
    }
    return cities.length;
  }

  @override
  void dispose() {
    stopLiveRefresh();
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    adminSnack(context, '$label copied');
  }

  Future<void> _create() async {
    if (_saving) return;
    final name = _name.text.trim();
    final mobile = _mobile.text.trim();
    final email = _email.text.trim();

    if (name.isEmpty || mobile.length < 10) {
      adminSnack(context, 'Enter a name and valid mobile number',
          color: AdminColors.red);
      return;
    }
    if (!_isValidEmail(email)) {
      adminSnack(context, 'Enter a valid email address',
          color: AdminColors.red);
      return;
    }

    setState(() => _saving = true);
    // The backend creates the agent and GENERATES the password, returning it.
    final (password, error) = await AdminApi().createDeliveryAgent(
      name: name,
      mobile: mobile,
      email: email,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      adminSnack(context, error, color: AdminColors.red);
      return;
    }
    // Show the real, server-generated credentials so the admin can share them.
    await _showCredentialsDialog(name: name, mobile: mobile, password: password ?? '');
    if (mounted) Navigator.of(context).pop();
  }

  /// A dialog with the created agent's real login id + server-generated
  /// password, each tap-to-copy, plus a one-tap "Copy both" to share.
  Future<void> _showCredentialsDialog({
    required String name,
    required String mobile,
    required String password,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Agent $name created',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share these credentials with the agent. The password is '
              'generated by the server and cannot be recovered later.',
              style: TextStyle(fontSize: 12.5, color: AppColors.greyText),
            ),
            const SizedBox(height: 14),
            _CredRow(
              label: 'LOGIN ID (MOBILE NO.)',
              value: mobile,
              onCopy: () => _copy(mobile, 'Login ID'),
            ),
            const SizedBox(height: 10),
            _CredRow(
              label: 'PASSWORD',
              value: password.isEmpty ? '—' : password,
              onCopy: () => _copy(password, 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _copy(
                'Login: $mobile  Password: $password', 'Credentials'),
            icon: const Icon(Icons.copy_all, size: 18),
            label: const Text('Copy both'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Delivery Management',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText)),
            Text('Manage agent logins',
                style: TextStyle(fontSize: 12, color: AppColors.greyText)),
          ],
        ),
      ),
      body: ListView(
        physics: adminScroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          // Live counts from the backend user directory (role "delivery").
          Row(
            children: [
              Expanded(
                  child: MiniStat(
                      value: _agents == null ? '—' : '${_agents!.length}',
                      label: 'Agents',
                      color: AdminColors.purple)),
              const SizedBox(width: 10),
              Expanded(
                  child: MiniStat(
                      value: _agents == null ? '—' : '$_citiesCovered',
                      label: 'Cities Covered',
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: const [
              Icon(Icons.person_add_alt_1, size: 20, color: AppColors.darkGreen),
              SizedBox(width: 8),
              Text('Create New Agent Login',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText)),
            ],
          ),
          const SizedBox(height: 16),
          _FieldLabel('Agent Full Name'),
          _Field(
            controller: _name,
            hint: 'e.g. Suresh Patil',
            icon: Icons.badge_outlined,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 14),
          _FieldLabel('Mobile Number'),
          _Field(
            controller: _mobile,
            hint: '98201 55420',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          _FieldLabel('Email Address'),
          _Field(
            controller: _email,
            hint: 'agent@example.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 8),
          // A short note — the password is created by the server and shown in a
          // popup after the agent is created (not previewed here).
          const Text(
            'A 6-digit password is generated automatically when you create the '
            'agent. Their login ID is this mobile number.',
            style: TextStyle(fontSize: 12, color: AppColors.greyText),
          ),
          const SizedBox(height: 24),
          AdminButton(
            label: _saving ? 'Creating…' : 'Create Agent',
            icon: Icons.check,
            onPressed: () => _create(),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, left: 2),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText)),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: AppColors.darkText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.greyText, size: 20),
        filled: true,
        fillColor: AppColors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _CredRow extends StatelessWidget {
  const _CredRow({required this.label, required this.value, required this.onCopy});
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.greyText)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText)),
              ],
            ),
          ),
          TintIconButton(
            icon: Icons.copy_rounded,
            color: AppColors.darkGreen,
            onTap: onCopy,
            size: 16,
          ),
        ],
      ),
    );
  }
}
