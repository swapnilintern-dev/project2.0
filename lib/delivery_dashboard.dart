import 'package:flutter/material.dart';

import 'delivery/delivery_main.dart';

/// Thin entry point — sign-in routes here for the delivery role.
class DeliveryDashboardScreen extends StatelessWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DeliveryMain();
  }
}
