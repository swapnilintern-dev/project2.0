// =============================================================================
// VS Arogya — Outlet Staff · Stock revision signal
//
// A one-line notifier every screen that CHANGES outlet inventory bumps, and
// every screen that DISPLAYS it listens to. The stock screens already poll the
// server (LiveRefreshMixin), so this is not how stock stays fresh — it is how a
// change this app just made shows up immediately instead of on the next tick.
//
// Bumped after a manual order is placed (the server has deducted the outlet's
// batches by then), so the Stock tab behind the order screen re-reads the live
// quantities the moment the user comes back.
// =============================================================================

import 'package:flutter/foundation.dart';

class OutletStockSignal {
  const OutletStockSignal._();

  /// Increments every time this app commits something that changes outlet
  /// stock. Listeners re-fetch from the server — the value itself carries no
  /// data, so nothing can ever be rendered from it.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Announce that outlet stock has changed server-side.
  static void bump() => revision.value++;
}
