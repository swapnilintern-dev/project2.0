// =============================================================================
// MediCaPlus — Customer Dashboard (entry point)
//
// Kept as `CustomerDashboardScreen` so the existing sign-in flow
// (sign_in_screen.dart -> SignInRole.customer) routes here unchanged. It simply
// hosts the customer shell (Home / Search / Cart / Orders / Profile) and wires
// Logout back to the sign-in screen.
//
// The full customer experience lives under lib/customer/.
// =============================================================================

import 'package:flutter/material.dart';

import 'customer/customer_controllers.dart';
import 'customer/customer_shell.dart';
import 'sign_in_screen.dart';

class CustomerDashboardScreen extends StatelessWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomerShell(
      onLogout: () {
        // Clear in-memory session so the next user doesn't inherit this
        // account's cart / wishlist / orders / addresses.
        resetCustomerSession();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInScreen()),
          (route) => false,
        );
      },
    );
  }
}
