// =============================================================================
// MediCaPlus — Admin · Delivery Management (pushed from Overview / Users)
//
// The agent-onboarding console. A live stat strip (total agents / on-duty /
// pending), then a "Create New Agent Login" form: name, mobile, email, and a
// generated credentials card. The LOGIN ID is the agent's mobile number and the
// password is a one-time random 6-digit code. On "Create Agent" the credentials
// are sent to the backend, which creates the delivery user and emails them the
// login details.
// =============================================================================

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../admin_api.dart';
import '../admin_common.dart';
import '../admin_models.dart';

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({super.key});

  @override
  State<DeliveryManagementScreen> createState() =>
      _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();

  /// One-time random 6-digit password for the agent (created once, never a
  /// throwaway "temporary" code). Generated on screen load.
  late final String _password;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _password = _generatePassword();
    // Keep the credentials card's LOGIN ID in sync with the mobile field.
    _mobile.addListener(_onMobileChanged);
  }

  @override
  void dispose() {
    _mobile.removeListener(_onMobileChanged);
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    super.dispose();
  }

  void _onMobileChanged() => setState(() {});

  /// A random 6-digit numeric password (100000–999999).
  String _generatePassword() => (100000 + Random().nextInt(900000)).toString();

  String get _loginId =>
      _mobile.text.trim().isEmpty ? 'Enter mobile number' : _mobile.text.trim();

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
    // Sends the credentials to the backend, which creates the delivery user and
    // emails the login details to the agent. (Local backend for now.)
    final ok = await AdminApi().createDeliveryAgent(
      name: name,
      mobile: mobile,
      email: email,
      password: _password,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      adminSnack(context, 'Agent $name created — credentials emailed to $email');
      Navigator.of(context).pop();
    } else {
      adminSnack(context, 'Could not create agent. Check connection and retry.',
          color: AdminColors.red);
    }
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
          Row(
            children: [
              Expanded(
                  child: MiniStat(
                      value: '$kAgentsTotal',
                      label: 'Agents',
                      color: AdminColors.purple)),
              const SizedBox(width: 10),
              Expanded(
                  child: MiniStat(
                      value: '$kAgentsOnDuty',
                      label: 'On Duty',
                      color: AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(
                  child: MiniStat(
                      value: '$kAgentsPending',
                      label: 'Pending',
                      color: AdminColors.orange)),
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
          const SizedBox(height: 20),
          _credentialsCard(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AdminButton(
                  label: 'Share',
                  icon: Icons.ios_share,
                  outlined: true,
                  onPressed: () => _copy(
                      'Login: ${_mobile.text.trim()}  Password: $_password',
                      'Credentials'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AdminButton(
                  label: _saving ? 'Creating…' : 'Create Agent',
                  icon: Icons.check,
                  onPressed: () => _create(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _credentialsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_outlined,
                  size: 18, color: AppColors.darkGreen),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Generated Login Credentials',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText)),
              ),
              const StatusBadge(
                  label: 'Auto', color: AppColors.darkGreen, dense: true),
            ],
          ),
          const SizedBox(height: 14),
          _CredRow(
            label: 'LOGIN ID (MOBILE NO.)',
            value: _loginId,
            onCopy: () => _copy(_mobile.text.trim(), 'Login ID'),
          ),
          const SizedBox(height: 10),
          _CredRow(
            label: 'PASSWORD',
            value: _password,
            onCopy: () => _copy(_password, 'Password'),
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
