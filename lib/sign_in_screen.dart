// ============================================================================
import 'services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard (tap-to-copy support details)

import 'vendor_registration_screen.dart'; // AppColors + VendorRegistrationScreen
import 'auth/forgot_password_screen.dart';
import 'customer/customer_shell.dart';
import 'delivery/delivery_main.dart';
import 'admin/admin_main.dart';
import 'marketing/marketing_role_main.dart';

/// The account types a user can sign in as. The role is decided by the account
/// (returned by the backend at login) — there is no on-screen role picker.
/// `vendor` is the B2B buyer (a pharmacy/clinic) who shops via the customer app.
enum SignInRole { vendor, admin, delivery, marketing }

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Local UI state.
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
Future<void> _onSignIn() async {

  FocusScope.of(context).unfocus();

  if (!(_formKey.currentState?.validate() ?? false)) return;

  setState(() => _isSubmitting = true);

  try {
    final response = await AuthService.login(
      mobileNo: _identifierCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (response['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message'] ?? 'Login Failed',
          ),
        ),
      );
      return;
    }

    // Route to the portal for the account's role. The backend MUST return
    // `role` in the login response (server: userController.login -> add
    // `role: user.role`). Matching is keyword-based so values like "admin",
    // "Admin", "marketing head", "delivery boy" all route correctly. Anything
    // missing / unrecognised falls back to the vendor/buyer shopping app.
    final role = (response['role'] ?? '').toString().toLowerCase();
    final Widget nextScreen;
    if (role.contains('admin')) {
      nextScreen = const AdminRoleMain();
    } else if (role.contains('marketing')) {
      nextScreen = const MarketingRoleMain();
    } else if (role.contains('delivery')) {
      nextScreen = const DeliveryMain();
    } else {
      nextScreen = const CustomerShell();
    }
/////////////////////////////////////////
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => nextScreen,
      ),
    );
  } catch (e) {
    if (!mounted) return;

    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
      ),
    );
  }
}


  void _openVendorRegistration() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VendorRegistrationScreen()),
    );
  }

  /// Opens the "Contact Support" bottom sheet (company phone + email, each
  /// tap-to-copy).
  void _showSupportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _SupportSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Hero is sized off screen height but clamped so it works on small phones.
    final heroHeight = (size.height * 0.34).clamp(220.0, 320.0);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              _buildHero(heroHeight),
              // Pull the card up so it overlaps the hero by 32px.
              Transform.translate(
                offset: const Offset(0, -32),
                child: _buildCard(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO
  // ---------------------------------------------------------------------------

  Widget _buildHero(double height) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Gradient background.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.darkGreen, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Decorative translucent circles.
          Positioned(
            top: -40,
            right: -30,
            child: _circle(140, Colors.white.withValues(alpha: 0.12)),
          ),
          Positioned(
            top: 60,
            left: -50,
            child: _circle(120, Colors.white.withValues(alpha: 0.10)),
          ),
          Positioned(
            bottom: 10,
            right: 40,
            child: _circle(60, Colors.white.withValues(alpha: 0.10)),
          ),
          // Hero content.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // White medicine-cross icon.
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.local_pharmacy_rounded,
                    color: AppColors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                // Logo pill.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.local_pharmacy,
                          color: AppColors.primary, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'VS Arogya',
                        style: TextStyle(
                          color: AppColors.darkGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  // ---------------------------------------------------------------------------
  // CARD
  // ---------------------------------------------------------------------------

  Widget _buildCard(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sign in to continue to your account',
              style: TextStyle(fontSize: 13, color: AppColors.greyText),
            ),
            const SizedBox(height: 20),
            


            // Identifier field.
            _InputField(
              label: 'Mobile Number / Email',
              hint: 'Enter mobile or email',
              controller: _identifierCtrl,
              icon: Icons.person_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Mobile number or email is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password field with show/hide toggle.
            _InputField(
              label: 'Password',
              hint: 'Enter your password',
              controller: _passwordCtrl,
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffix: IconButton(
                onPressed: ( 

                ) =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.greyText,
                  size: 20,
                ),
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 4) return 'Password must be at least 6 characters';
                return null;
              },
            ),

            // Forgot password.
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen()),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Sign In button with green glow.
            _GlowGradientButton(
              label: 'Sign In →',
              loading: _isSubmitting,
              onPressed: _isSubmitting ? null : _onSignIn,
            ),
            const SizedBox(height: 22),

            // Divider with label.
            //////////////////////////////////////////////////////////////
            Row(
              children: const [
                Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or continue with',
                    style: TextStyle(color: AppColors.greyText, fontSize: 12.5),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.border)),
              ],
            ),
          
            const SizedBox(height: 16),

            // New Vendor Registration banner.
            _buildVendorBanner(),
            const SizedBox(height: 20),

            // Support footer.
            Center(
              child: TextButton(
                onPressed: _showSupportSheet,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.greyText,
                ),
                child: RichText(
                  text: const TextSpan(
                    text: 'Need help? ',
                    style: TextStyle(color: AppColors.greyText, fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'Contact Support',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // VENDOR REGISTRATION BANNER
  // ---------------------------------------------------------------------------

  Widget _buildVendorBanner() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openVendorRegistration,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.lightGreenBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_outlined,
                    color: AppColors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'New Vendor Registration',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // "NEW" badge pill.
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Register your store on MediCaPlus →',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.darkGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// REUSABLE WIDGETS
// =============================================================================

/// Labelled input with a green circular icon prefix and inline validation.
class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 14, color: AppColors.darkText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.greyText, fontSize: 13),
            filled: true,
            fillColor: AppColors.pageBg,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            // Green circular icon prefix.
            prefixIcon: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
              child: Container(
                width: 30,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.white, size: 16),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: suffix,
            enabledBorder: border(AppColors.border),
            focusedBorder: border(AppColors.primary),
            errorBorder: border(AppColors.error),
            focusedErrorBorder: border(AppColors.error),
            errorStyle: const TextStyle(color: AppColors.error, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

/// Full-width gradient button with a green glow shadow + optional spinner.
class _GlowGradientButton extends StatelessWidget {
  const _GlowGradientButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.8,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              height: 54,
              decoration: BoxDecoration(
                gradient: AppColors.greenGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.white),
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Contact Support" bottom sheet — the company's phone & email, each tappable
/// to copy. Replace the placeholder values below with the real support details.
class _SupportSheet extends StatelessWidget {
  const _SupportSheet();

  // TODO: replace with the company's real support contact details.
  static const String _phone = '+91 1800 123 4567';
  static const String _email = 'support@vsarogya.in';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.lightGreenBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent_rounded,
                    color: AppColors.darkGreen, size: 30),
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Contact Support',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                "We're here to help — reach us anytime.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.greyText),
              ),
            ),
            const SizedBox(height: 20),
            const _SupportContactTile(
              icon: Icons.call_outlined,
              label: 'Phone',
              value: _phone,
              copiedMessage: 'Phone number copied',
            ),
            const SizedBox(height: 12),
            const _SupportContactTile(
              icon: Icons.mail_outline,
              label: 'Email',
              value: _email,
              copiedMessage: 'Email copied',
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Mon–Sat · 9:00 AM – 7:00 PM',
                style: TextStyle(fontSize: 12, color: AppColors.greyText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tap-to-copy support channel row (phone / email) inside [_SupportSheet].
/// Tapping the row OR the trailing copy button writes [value] to the system
/// clipboard and shows a confirmation toast.
class _SupportContactTile extends StatelessWidget {
  const _SupportContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.copiedMessage,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Shown in the confirmation toast, e.g. "Phone number copied".
  final String copiedMessage;

  /// Writes [value] to the real device clipboard, then shows a toast that
  /// floats ABOVE the bottom sheet (a SnackBar would render on the Scaffold
  /// underneath the sheet and stay hidden).
  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    _showCopiedToast(context, copiedMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _copy(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.greyText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: AppColors.greyText,
                splashRadius: 20,
                tooltip: 'Copy $label',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating confirmation toast inserted into the ROOT overlay so it renders
/// above modal bottom sheets / dialogs. Auto-dismisses after ~1.4s.
void _showCopiedToast(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.of(context).viewInsets.bottom + 40,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.darkGreen,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 1400), () {
    if (entry.mounted) entry.remove();
  });
}
