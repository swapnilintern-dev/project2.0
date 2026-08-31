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
  // Outlet Staff — physical-outlet operator (counter + delivery orders).
  // Outlets live in their OWN collection with their own login (POST
  // /outlet-login, handled by the sign-in screen), which populates
  // OutletSession with the outlet id + token every outlet-scoped call needs.
  // Only route to the shell when that live session exists — a name-only
  // session would run the whole role on mock data. A restored app start can't
  // rebuild it (the session is in-memory), so it goes back to sign-in.
  if (role.contains('outlet')) {
    if (OutletSession.instance.isLive) return const OutletMain();
    return const SignInScreen();
  }
  if (role.contains('delivery')) {
    // A delivery user in the Vendor collection (role == delivery).
    DeliveryController.instance.setAgent(mobile: mobile ?? '', name: name);
    return const DeliveryMain();
  }
  // Area Agent — pincode-scoped order monitor. Checked AFTER delivery so a
  // "delivery agent" role never mis-routes here. A real login (backend returns
  // role: "agent") populates AgentSession with the agent id + token inside
  // AuthService.login. Only route to the portal when that live session exists —
  // a name-only session would run the dashboard on mock data. A restored app
  // start can't rebuild it (the session is in-memory), so it re-authenticates.
  if (role.contains('agent')) {
    if (AgentSession.instance.isLive) return const AgentMain();
    return const SignInScreen();
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
