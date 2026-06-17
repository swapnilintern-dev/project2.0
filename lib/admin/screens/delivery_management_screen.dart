// =============================================================================
// MediCaPlus — Admin · Delivery Management (pushed from Overview / Users)
//
// The agent-onboarding console. A live stat strip (total agents / on-duty /
// pending), then a "Create New Agent Login" form: name, mobile, service zone,
// and an auto-generated credentials card (login id + temporary password) with
// copy & regenerate. Share / Create Agent actions at the bottom.
// =============================================================================

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../vendor_registration_screen.dart' show AppColors;
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
  String _zone = kServiceZones.first;

  late String _loginId;
  late String _password;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  void _regenerate() {
    final rnd = Random();
    final id = 100 + rnd.nextInt(900);
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final pwd = List.generate(7, (_) => chars[rnd.nextInt(chars.length)]).join();
    setState(() {
      _loginId = 'DA-$id${20 + rnd.nextInt(80)}';
      _password = 'Med-$pwd';
    });
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    adminSnack(context, '$label copied');
  }

  void _create() {
    if (_name.text.trim().isEmpty || _mobile.text.trim().length < 10) {
      adminSnack(context, 'Enter a name and valid mobile number',
          color: AdminColors.red);
      return;
    }
    adminSnack(context, 'Agent ${_name.text.trim()} created');
    Navigator.of(context).pop();
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
          _FieldLabel('Service Zone'),
          _zoneDropdown(),
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
                      'Login: $_loginId  Password: $_password', 'Credentials'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AdminButton(
                  label: 'Create Agent',
                  icon: Icons.check,
                  onPressed: _create,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _zoneDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _zone,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: AppColors.greyText),
          borderRadius: BorderRadius.circular(12),
          items: [
            for (final z in kServiceZones)
              DropdownMenuItem(
                value: z,
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 18, color: AppColors.darkGreen),
                    const SizedBox(width: 8),
                    Text(z,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.darkText)),
                  ],
                ),
              ),
          ],
          onChanged: (v) => setState(() => _zone = v ?? _zone),
        ),
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
              const StatusBadge(label: 'Auto', color: AppColors.darkGreen, dense: true),
            ],
          ),
          const SizedBox(height: 14),
          _CredRow(
            label: 'LOGIN ID',
            value: _loginId,
            onCopy: () => _copy(_loginId, 'Login ID'),
          ),
          const SizedBox(height: 10),
          _CredRow(
            label: 'TEMPORARY PASSWORD',
            value: _password,
            onCopy: () => _copy(_password, 'Password'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _regenerate,
              style: TextButton.styleFrom(foregroundColor: AppColors.darkGreen),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Regenerate',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
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
