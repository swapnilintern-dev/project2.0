// =============================================================================
// VS Arogya — Price gate (browse-only accounts)
//
// Prices and ordering are for APPROVED vendors only. Everyone else — an email
// OTP guest with no account yet, or a vendor whose registration is pending /
// rejected — can browse the catalogue, but sees a blurred price and is sent to
// registration when they try to add anything to the cart.
//
// The state comes from VendorApproval (the client mirror of the backend's
// `approvalStatus`; a guest login reports "Not Registered"). The server blocks
// a guest token from cart / order / payment on its own (isAuthenticated), so
// this file is the presentational half only.
//
// The blurred price is a PLACEHOLDER, not the real amount behind a filter —
// the real price is never put into the widget tree for a locked account.
// =============================================================================

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../services/vendor_approval.dart';
import '../vendor_registration_screen.dart'
    show AppColors, VendorRegistrationScreen;
import '../vendor_status_screen.dart';

/// Whether the signed-in account may see prices and order.
bool get pricesUnlocked => VendorApproval.instance.canSeePrices;

/// Label for the "way forward" button, per registration state.
String vendorCtaLabel() => switch (VendorApproval.instance.status) {
  VendorApprovalStatus.pending => 'View Registration Status',
  VendorApprovalStatus.rejected => 'Update & Resubmit',
  _ => 'Complete Vendor Registration',
};

/// Opens the vendor registration flow, or the status screen when a
/// registration has already been submitted / rejected.
void openVendorFlow(BuildContext context) {
  final status = VendorApproval.instance.status;
  final Widget screen =
      (status == VendorApprovalStatus.pending ||
          status == VendorApprovalStatus.rejected)
      ? const VendorStatusScreen()
      : const VendorRegistrationScreen();
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// Call before any add-to-cart / buy action. Returns true when the account may
/// order; otherwise explains why and offers the registration flow.
bool ensureCanOrder(BuildContext context) {
  if (pricesUnlocked) return true;

  final message = switch (VendorApproval.instance.status) {
    VendorApprovalStatus.pending =>
      'Your registration is under review. You can order once it is approved.',
    VendorApprovalStatus.rejected =>
      'Your registration was rejected. Update it to start ordering.',
    _ => 'Register as a vendor to see prices and place orders.',
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: VendorApproval.instance.status == VendorApprovalStatus.pending
              ? 'STATUS'
              : 'REGISTER',
          onPressed: () => openVendorFlow(context),
        ),
      ),
    );
  return false;
}

/// A blurred stand-in for a price.
class LockedPrice extends StatelessWidget {
  const LockedPrice({super.key, this.fontSize = 15});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Price available after vendor verification',
      excludeSemantics: true,
      // Scales down instead of overflowing on narrow catalogue cards.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Text(
                '₹ 0,000',
                maxLines: 1,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGreen,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.lock_outline,
              size: fontSize * 0.9,
              color: AppColors.greyText,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [child] (the real price) to an approved account and [LockedPrice] to
/// everyone else; rebuilds when the approval state changes.
class PriceOrLocked extends StatelessWidget {
  const PriceOrLocked({super.key, required this.child, this.fontSize = 15});

  final Widget child;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: VendorApproval.instance,
      builder: (context, _) =>
          pricesUnlocked ? child : LockedPrice(fontSize: fontSize),
    );
  }
}
