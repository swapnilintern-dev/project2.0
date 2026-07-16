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

import '../admin/admin_main.dart';
import '../agent/agent_main.dart';
import '../agent/agent_session.dart';
import '../customer/customer_controllers.dart';
import '../customer/customer_shell.dart';
import '../delivery/delivery_main.dart';
import '../delivery/delivery_models.dart' show DeliveryController;
import '../marketing/marketing_role_main.dart';
import '../outlet/outlet_main.dart';
import '../outlet/outlet_session.dart';
import '../services/auth_service.dart';
import '../sign_in_screen.dart';

/// The portal shell for an account's [role] — shared by the sign-in screen
/// (fresh login) and the splash screen (restored session), so both always
/// route identically. Matching is keyword-based ("admin", "Admin",
/// "marketing head", "delivery boy" all work); anything unrecognised falls
/// back to the vendor/buyer shopping app.
Widget homeForRole(String? roleRaw, {String? mobile, String? name}) {
  final role = (roleRaw ?? '').toLowerCase();
  if (role.contains('admin')) return const AdminRoleMain();
  if (role.contains('marketing')) return const MarketingRoleMain();
  // Outlet Staff — physical-outlet operator (counter + delivery orders). Routes
  // the same keyword way as the other roles once the backend returns
  // role: "outlet". See lib/outlet/.
  if (role.contains('outlet')) {
    OutletSession.instance.signIn(name: name);
    return const OutletMain();
  }
  if (role.contains('delivery')) {
    // A delivery user in the Vendor collection (role == delivery).
    DeliveryController.instance.setAgent(mobile: mobile ?? '', name: name);
    return const DeliveryMain();
  }
  // Area Agent — pincode-scoped order monitor. Checked AFTER delivery so a
  // "delivery agent" role never mis-routes here. The demo login sets the
  // AgentSession (name + pincode) before this runs; the production path (backend
  // returns role: "agent") falls back to signing in with the response name.
  if (role.contains('agent')) {
    if (!AgentSession.instance.isSignedIn) {
      AgentSession.instance.signIn(name: name);
    }
    return const AgentMain();
  }
  return const CustomerShell();
}

/// Logs the current user out of any role and returns to the sign-in screen.
void logout(BuildContext context) {
  // Per-user state that must never carry over to the next account's session.
  // (Marketing/Admin data is global demo catalog seeded once, not per-user, so
  // it is intentionally left intact; Delivery re-seeds on next shell init.)
  resetCustomerSession();
  // Clear the delivery agent's live session (identity + dispatch queue).
  DeliveryController.instance.reset();
  // Clear the outlet staff session (identity) so the guard requires a fresh login.
  OutletSession.instance.clear();
  // Clear the Area Agent session (identity) so the next login starts clean.
  AgentSession.instance.clear();
  // Drop the captured login cookie so the next account starts unauthenticated.
  AuthService.clearSession();

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const SignInScreen()),
    (route) => false,
  );
}
