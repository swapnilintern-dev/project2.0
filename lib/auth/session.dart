// =============================================================================
// MediCaPlus — Session / Logout
//
// One logout entry point shared by every role shell (customer, admin,
// marketing, delivery). Centralised so all four roles log out identically:
//   1. clear in-memory per-user state so it never leaks into the next account,
//   2. return to the sign-in screen and wipe the navigation stack so Back can't
//      re-enter a role shell after signing out.
//
// When the backend lands and the other roles fetch real per-user data, add
// their resets here (e.g. resetDeliverySession()) so a single call clears
// everything regardless of which role is active.
// =============================================================================

import 'package:flutter/material.dart';

import '../customer/customer_controllers.dart';
import '../sign_in_screen.dart';

/// Logs the current user out of any role and returns to the sign-in screen.
void logout(BuildContext context) {
  // Per-user state that must never carry over to the next account's session.
  // (Marketing/Admin data is global demo catalog seeded once, not per-user, so
  // it is intentionally left intact; Delivery re-seeds on next shell init.)
  resetCustomerSession();

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const SignInScreen()),
    (route) => false,
  );
}
