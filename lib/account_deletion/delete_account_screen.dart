// =============================================================================
// MediCaPlus — Delete Account screen (Vendor + Delivery Partner)
//
// Reached from Profile → Settings → Privacy & Security → Delete Account. The
// user states a reason and submits a deletion REQUEST, which goes to the admin
// for review (see AccountDeletionController). Matches the VS Arogya light-green
// Material 3 theme. Admin & Marketing never reach this screen.
// =============================================================================

import 'package:flutter/material.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'account_deletion_controller.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({
    super.key,
    required this.role,
    required this.userName,
    this.contact = '',
  });

  /// Only Vendor / Delivery Partner ever open this screen.
  final DeletionRole role;

  /// Display name attached to the request so the admin knows whose it is.
  final String userName;

  /// Optional phone/email shown to the admin for follow-up.
  final String contact;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  AccountDeletionController get _controller =>
      AccountDeletionController.instance;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit deletion request?'),
        content: const Text(
          'Your account and associated data may be permanently removed once '
          'the admin team approves this request. This may not be reversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    // TODO(backend): POST the request to the server here.
    final req = _controller.submit(
      userName: widget.userName,
      role: widget.role,
      reason: _reasonCtrl.text,
      contact: widget.contact,
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _submitting = false);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_outlined,
            color: AppColors.primary, size: 40),
        title: const Text('Request submitted'),
        content: Text(
          'Your deletion request (#${req.id}) has been sent to the VS Arogya '
          'admin team for review. You will be notified once it is processed.',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0.5,
        title: const Text('Delete Account',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final pending = _controller.hasPendingFor(widget.userName);
          return ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              _warningCard(),
              const SizedBox(height: 16),
              if (pending)
                _pendingCard(_controller.latestFor(widget.userName)!)
              else ...[
                _reasonForm(),
                const SizedBox(height: 16),
                _infoNote(),
                const SizedBox(height: 24),
                _submitButton(),
              ],
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _warningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Deleting your account may permanently remove access to your '
            'profile and associated data.',
            style: TextStyle(
                fontSize: 13.5, color: AppColors.darkText, height: 1.45),
          ),
          const SizedBox(height: 8),
          const Text(
            'This action may not be reversible.',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasonForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reason for deletion',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Tell us why you want to delete your account. This helps the '
              'admin team review your request.',
              style: TextStyle(fontSize: 12, color: AppColors.greyText),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 14, color: AppColors.darkText),
              decoration: InputDecoration(
                hintText: 'e.g. No longer using the platform…',
                hintStyle:
                    const TextStyle(color: AppColors.greyText, fontSize: 13),
                filled: true,
                fillColor: AppColors.lighterGreen,
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.4),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
              ),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Please enter a reason';
                if (text.length < 10) {
                  return 'Please add a little more detail (min 10 characters)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.shield_outlined, color: AppColors.darkGreen, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your request is sent to the VS Arogya admin team for review. '
              "You'll be notified once it is approved or rejected.",
              style: TextStyle(
                  fontSize: 12.5, color: AppColors.darkGreen, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _submitting ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.error,
          disabledBackgroundColor: AppColors.error.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : const Icon(Icons.delete_outline, size: 20),
        label: Text(
          _submitting ? 'Submitting…' : 'Submit Deletion Request',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _pendingCard(AccountDeletionRequest req) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Request under review',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Pending',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Reason submitted',
              style: TextStyle(fontSize: 12, color: AppColors.greyText)),
          const SizedBox(height: 4),
          Text('“${req.reason}”',
              style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.darkText,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 14),
          const Text(
            'You already have a deletion request awaiting admin review. '
            "You'll be notified once it is processed.",
            style: TextStyle(
                fontSize: 12.5, color: AppColors.greyText, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text('Reference: #${req.id}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen)),
        ],
      ),
    );
  }
}
