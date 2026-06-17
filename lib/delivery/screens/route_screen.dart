import 'package:flutter/material.dart';

import '../../vendor_registration_screen.dart' show AppColors;
import '../delivery_models.dart';

/// Clean placeholder for the Navigation Map screen.
class _NavigationMapPlaceholder extends StatelessWidget {
  const _NavigationMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.lightGreenBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.explore_outlined,
              color: AppColors.darkGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Navigation Map',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Live navigation integration is coming shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.greyText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Future updates will include:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 12),
                _bulletItem('Real-time navigation'),
                const SizedBox(height: 8),
                _bulletItem('Route optimization'),
                const SizedBox(height: 8),
                _bulletItem('Delivery tracking'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletItem(String text) {
    return Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.darkText,
          ),
        ),
      ],
    );
  }
}

class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key, this.taskId, this.embedded = false});

  final String? taskId;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DeliveryController.instance,
      builder: (context, _) {
        final task = taskId != null
            ? DeliveryController.instance.taskById(taskId!)
            : DeliveryController.instance.activeTask;

        if (task == null) {
          return _emptyState(context);
        }

        final body = Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFF0D3D32)),
            SafeArea(
              child: Column(
                children: [
                  if (!embedded) _topBar(context),
                  const Expanded(
                    child: Center(
                      child: _NavigationMapPlaceholder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        if (embedded) return body;
        return Scaffold(
          backgroundColor: const Color(0xFF0D3D32),
          body: body,
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    final content = const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No active route.\nAccept a task from the Tasks tab.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.greyText, fontSize: 14),
        ),
      ),
    );
    if (embedded) {
      return ColoredBox(color: AppColors.pageBg, child: content);
    }
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        title: const Text('Route',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: content,
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Text(
            'Navigation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
