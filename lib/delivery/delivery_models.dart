// =============================================================================
// MediCaPlus — Delivery Partner Models
// =============================================================================

import 'package:flutter/foundation.dart';

import 'delivery_api.dart';

/// A delivery task's stage, mapped from the backend order status:
///   Shipped          -> [next]   (waiting for an agent to pick up)
///   Out for Delivery -> [active] (agent is delivering it now)
/// [completed] is used locally once an agent marks it delivered this session.
enum DeliveryTaskStatus { active, next, queued, completed }

extension DeliveryTaskStatusX on DeliveryTaskStatus {
  String get label => switch (this) {
        DeliveryTaskStatus.active => 'Out for Delivery',
        DeliveryTaskStatus.next => 'Ready to Pick Up',
        DeliveryTaskStatus.queued => 'Queued',
        DeliveryTaskStatus.completed => 'Delivered',
      };

  /// The action button label that advances this task, or null when there's
  /// nothing to do.
  String? get actionLabel => switch (this) {
        DeliveryTaskStatus.next => 'Accept & Pick Up',
        DeliveryTaskStatus.active => 'Start Delivery',
        _ => null,
      };
}

class RiderProfile {
  const RiderProfile({
    required this.id,
    required this.name,
    required this.initials,
    required this.phone,
    required this.role,
    required this.rating,
    required this.totalDeliveries,
    required this.vehicle,
  });

  final String id;
  final String name;
  final String initials;
  final String phone;
  final String role;
  final double rating;
  final int totalDeliveries;
  final VehicleInfo vehicle;
}

class VehicleInfo {
  const VehicleInfo({
    required this.number,
    required this.type,
    required this.verified,
  });

  final String number;
  final String type;
  final bool verified;
}

class DeliveryTaskItem {
  const DeliveryTaskItem({
    required this.name,
    required this.quantity,
    this.verified = false,
  });

  final String name;
  final int quantity;
  final bool verified;

  DeliveryTaskItem copyWith({bool? verified}) => DeliveryTaskItem(
        name: name,
        quantity: quantity,
        verified: verified ?? this.verified,
      );
}

class DeliveryTask {
  const DeliveryTask({
    required this.id,
    required this.pharmacyName,
    required this.address,
    required this.distanceKm,
    required this.itemCount,
    required this.codAmount,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.pharmacyPhone,
    required this.items,
    required this.turnInstruction,
    required this.etaMinutes,
    required this.routeDistanceKm,
  });

  final String id;
  final String pharmacyName;
  final String address;
  final double distanceKm;
  final int itemCount;
  final double codAmount;
  final DeliveryTaskStatus status;
  final String customerName;
  final String customerPhone;
  final String pharmacyPhone;
  final List<DeliveryTaskItem> items;
  final String turnInstruction;
  final int etaMinutes;
  final double routeDistanceKm;

  DeliveryTask copyWith({
    DeliveryTaskStatus? status,
    List<DeliveryTaskItem>? items,
  }) =>
      DeliveryTask(
        id: id,
        pharmacyName: pharmacyName,
        address: address,
        distanceKm: distanceKm,
        itemCount: itemCount,
        codAmount: codAmount,
        status: status ?? this.status,
        customerName: customerName,
        customerPhone: customerPhone,
        pharmacyPhone: pharmacyPhone,
        items: items ?? this.items,
        turnInstruction: turnInstruction,
        etaMinutes: etaMinutes,
        routeDistanceKm: routeDistanceKm,
      );

  /// Builds a delivery task from a backend order (GET /all-orders shape). The
  /// buyer/pharmacy is the order's user; the drop address + items come from the
  /// order. Distance / ETA aren't tracked by the backend, so they default to 0
  /// and the UI hides them.
  factory DeliveryTask.fromOrderJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map : const {};
    final addr =
        j['shippingAddress'] is Map ? j['shippingAddress'] as Map : const {};
    final itemsRaw = (j['orderItems'] as List?) ?? const [];
    final items = <DeliveryTaskItem>[];
    var count = 0;
    for (final it in itemsRaw.whereType<Map>()) {
      final p = it['product'] is Map ? it['product'] as Map : const {};
      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
      count += qty;
      items.add(DeliveryTaskItem(
        name: (p['title'] ?? 'Item').toString(),
        quantity: qty,
      ));
    }
    final addressStr =
        [addr['address'], addr['city'], addr['state'], addr['pincode']]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .join(', ');
    final buyer =
        (user['store_name'] ?? user['contact_person_name'] ?? 'Customer')
            .toString();
    final status = (j['orderStatus'] ?? '').toString() == 'Out for Delivery'
        ? DeliveryTaskStatus.active
        : DeliveryTaskStatus.next;
    return DeliveryTask(
      id: (j['_id'] ?? '').toString(),
      pharmacyName: buyer,
      address: addressStr,
      distanceKm: 0,
      itemCount: count,
      codAmount: _numOf(j['totalAmount']),
      status: status,
      customerName: buyer,
      customerPhone: (addr['phoneNo'] ?? user['mobile_no'] ?? '').toString(),
      pharmacyPhone: (user['mobile_no'] ?? '').toString(),
      items: items,
      turnInstruction: '',
      etaMinutes: 0,
      routeDistanceKm: 0,
    );
  }
}

double _numOf(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// A completed (Delivered) order, used by the agent's delivery-history screen.
/// Built from a backend order (GET /all-orders) whose status is "Delivered".
class DeliveredRecord {
  const DeliveredRecord({
    required this.id,
    required this.buyer,
    required this.amount,
    required this.itemCount,
    required this.deliveredAt,
  });

  final String id;
  final String buyer;
  final double amount;
  final int itemCount;
  final DateTime deliveredAt;

  factory DeliveredRecord.fromOrderJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map : const {};
    final itemsRaw = (j['orderItems'] as List?) ?? const [];
    var count = 0;
    for (final it in itemsRaw.whereType<Map>()) {
      count += (it['quantity'] as num?)?.toInt() ?? 0;
    }
    // The backend doesn't stamp deliveredAt, so the order's updatedAt (last
    // change = the delivered status update) is the best available timestamp.
    final date =
        DateTime.tryParse((j['updatedAt'] ?? j['createdAt'] ?? '').toString())
                ?.toLocal() ??
            DateTime.now();
    return DeliveredRecord(
      id: (j['_id'] ?? '').toString(),
      buyer: (user['store_name'] ?? user['contact_person_name'] ?? 'Customer')
          .toString(),
      amount: _numOf(j['totalAmount']),
      itemCount: count,
      deliveredAt: date,
    );
  }
}

class EarningsSummary {
  const EarningsSummary({
    required this.today,
    required this.week,
    required this.month,
    required this.totalTrips,
    required this.perTrip,
    required this.onTimePct,
    required this.weekChart,
  });

  final double today;
  final double week;
  final double month;
  final int totalTrips;
  final double perTrip;
  final double onTimePct;
  final List<double> weekChart;
}

class CompletedTrip {
  const CompletedTrip({
    required this.orderId,
    required this.route,
    required this.earnings,
    required this.completedAt,
  });

  final String orderId;
  final String route;
  final double earnings;
  final DateTime completedAt;
}

/// Backend-driven delivery session state — ChangeNotifier only, no external
/// packages. Holds the signed-in agent's identity (captured at login) and the
/// live dispatch queue fetched from the backend.
class DeliveryController extends ChangeNotifier {
  DeliveryController._();
  static final DeliveryController instance = DeliveryController._();

  final DeliveryApi _api = DeliveryApi();

  String? _agentMobile;
  String? _agentName;

  /// The agent's JWT from POST /agent-login — required by the doorstep
  /// payment endpoints (they are role-gated to "delivery" server-side).
  String? _token;
  final List<DeliveryTask> _tasks = [];
  bool _loading = false;
  bool _loaded = false;
  int _deliveredThisSession = 0;

  String? get agentMobile => _agentMobile;
  String? get token => _token;
  List<DeliveryTask> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  int get deliveredThisSession => _deliveredThisSession;

  /// Records the signed-in agent (from the login screen). Name is optional
  /// (we show the mobile when it's unknown); the token authenticates the
  /// doorstep payment calls.
  void setAgent({required String mobile, String? name, String? token}) {
    _agentMobile = mobile;
    _agentName = (name != null && name.trim().isNotEmpty) ? name.trim() : null;
    _token = (token != null && token.trim().isNotEmpty) ? token.trim() : null;
    notifyListeners();
  }

  /// A profile built from the REAL signed-in agent — no fabricated rating,
  /// vehicle or trip history (the backend doesn't track those yet).
  RiderProfile get rider {
    final name = _agentName ?? 'Delivery Partner';
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? 'DP'
        : parts.length == 1
            ? parts.first
                .substring(0, parts.first.length >= 2 ? 2 : 1)
                .toUpperCase()
            : (parts[0][0] + parts[1][0]).toUpperCase();
    return RiderProfile(
      id: _agentMobile ?? '—',
      name: name,
      initials: initials,
      phone: _agentMobile ?? '',
      role: 'Delivery Partner',
      rating: 0,
      totalDeliveries: _deliveredThisSession,
      vehicle:
          const VehicleInfo(number: '', type: 'Delivery Partner', verified: false),
    );
  }

  /// Orders currently Out for Delivery (this agent is delivering them now).
  List<DeliveryTask> get activeTasks =>
      _tasks.where((t) => t.status == DeliveryTaskStatus.active).toList();

  /// Orders currently Shipped (waiting to be picked up).
  List<DeliveryTask> get pickupTasks =>
      _tasks.where((t) => t.status == DeliveryTaskStatus.next).toList();

  DeliveryTask? taskById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Re-fetches the live dispatch queue from the backend. Offline-safe: keeps
  /// the current list on failure.
  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    final list = await _api.getTasks();
    if (list != null) {
      _tasks
        ..clear()
        ..addAll(list);
    }
    _loading = false;
    _loaded = true;
    notifyListeners();
  }

  /// Shipped -> Out for Delivery. Returns null on success, else an error.
  Future<String?> pickUp(String id) async {
    final ok = await _api.pickUp(id);
    if (!ok) return 'Could not update the order. Check your connection.';
    await refresh();
    return null;
  }

  /// Out for Delivery -> Delivered. Returns null on success, else an error.
  Future<String?> markDelivered(String id) async {
    final ok = await _api.markDelivered(id);
    if (!ok) return 'Could not mark delivered. Check your connection.';
    _deliveredThisSession++;
    await refresh();
    return null;
  }

  /// Local-only checklist toggle used by the confirm-delivery screen (the
  /// backend doesn't persist per-item verification).
  void updateTaskItems(String id, List<DeliveryTaskItem> items) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _tasks[index] = _tasks[index].copyWith(items: items);
    notifyListeners();
  }

  /// Clears the delivery session on logout.
  void reset() {
    _agentMobile = null;
    _agentName = null;
    _tasks.clear();
    _loading = false;
    _loaded = false;
    _deliveredThisSession = 0;
    notifyListeners();
  }
}
