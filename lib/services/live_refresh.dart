// =============================================================================
// MediCaPlus — Live Refresh Mixin
//
// A tiny, package-free helper that keeps a screen's data continuously in sync
// with the backend so a status change made by ONE role (e.g. the marketing team
// advancing an order to "Shipped") shows up on ANOTHER role's screen (e.g. the
// customer's order tracker) without a manual refresh.
//
// It drives [onLiveRefresh]:
//   • once when the screen mounts (unless immediate: false),
//   • on a fixed [liveRefreshInterval] poll while the screen is alive, and
//   • every time the app returns to the foreground (app resume).
//
// The backend has no realtime channel (and the server is intentionally left
// untouched), so short-interval polling is how "instant" is achieved. Every
// refresh callback is expected to be offline-safe (keep current data on
// failure, never inject mock/dummy data), matching the existing controllers.
// =============================================================================

import 'dart:async';

import 'package:flutter/widgets.dart';

/// Forwards app lifecycle events to a callback without forcing the host State
/// to itself be a [WidgetsBindingObserver].
class _LifecycleWatcher extends WidgetsBindingObserver {
  _LifecycleWatcher(this.onResumed);

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}

/// Mix into a screen's [State] and implement [onLiveRefresh]. Call
/// [startLiveRefresh] from initState and [stopLiveRefresh] from dispose.
mixin LiveRefreshMixin<T extends StatefulWidget> on State<T> {
  Timer? _liveTimer;
  _LifecycleWatcher? _watcher;

  /// How often to re-fetch while the screen is visible. Kept short so
  /// cross-role status changes feel near-instant. Override to tune per screen.
  Duration get liveRefreshInterval => const Duration(seconds: 8);

  /// Re-fetch the screen's data from the backend. Must be offline-safe.
  Future<void> onLiveRefresh();

  /// Begins polling + lifecycle-aware refreshing. When [immediate] is true the
  /// data is fetched right away (before the first interval elapses).
  void startLiveRefresh({bool immediate = true}) {
    if (immediate) unawaited(onLiveRefresh());
    _watcher = _LifecycleWatcher(() {
      if (mounted) unawaited(onLiveRefresh());
    });
    WidgetsBinding.instance.addObserver(_watcher!);
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(liveRefreshInterval, (_) {
      if (mounted) unawaited(onLiveRefresh());
    });
  }

  /// Stops polling and detaches the lifecycle observer. Safe to call twice.
  void stopLiveRefresh() {
    _liveTimer?.cancel();
    _liveTimer = null;
    final w = _watcher;
    if (w != null) {
      WidgetsBinding.instance.removeObserver(w);
      _watcher = null;
    }
  }
}
