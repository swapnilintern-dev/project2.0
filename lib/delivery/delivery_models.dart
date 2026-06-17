// =============================================================================
// MediCaPlus — Delivery Partner Models
// =============================================================================

import 'package:flutter/foundation.dart';

enum DeliveryTaskStatus { active, next, queued, completed }

extension DeliveryTaskStatusX on DeliveryTaskStatus {
  String get label => switch (this) {
        DeliveryTaskStatus.active => 'Pickup',
        DeliveryTaskStatus.next => 'Next',
        DeliveryTaskStatus.queued => 'Queue',
        DeliveryTaskStatus.completed => 'Done',
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

/// Lightweight session state — ChangeNotifier only, no external packages.
class DeliveryController extends ChangeNotifier {
  DeliveryController._();
  static final DeliveryController instance = DeliveryController._();

  bool _online = true;
  List<DeliveryTask> _tasks = [];
  EarningsSummary? _earnings;
  List<CompletedTrip> _trips = [];
  RiderProfile? _rider;
  bool _initialized = false;

  bool get online => _online;
  List<DeliveryTask> get tasks => List.unmodifiable(_tasks);
  EarningsSummary? get earnings => _earnings;
  List<CompletedTrip> get trips => List.unmodifiable(_trips);
  RiderProfile? get rider => _rider;

  DeliveryTask? get activeTask {
    for (final t in _tasks) {
      if (t.status == DeliveryTaskStatus.active) return t;
    }
    return _tasks.isNotEmpty ? _tasks.first : null;
  }

  List<DeliveryTask> get todayTasks =>
      _tasks.where((t) => t.status != DeliveryTaskStatus.completed).toList();

  int get todayDeliveryCount =>
      _tasks.where((t) => t.status == DeliveryTaskStatus.completed).length + 3;

  double get todayEarnings => _earnings?.today ?? 0;

  void initialize({
    required RiderProfile rider,
    required List<DeliveryTask> tasks,
    required EarningsSummary earnings,
    required List<CompletedTrip> trips,
  }) {
    if (_initialized) return;
    _rider = rider;
    _tasks = List.of(tasks);
    _earnings = earnings;
    _trips = List.of(trips);
    _initialized = true;
    notifyListeners();
  }

  void setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    notifyListeners();
  }

  DeliveryTask? taskById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  void updateTaskItems(String id, List<DeliveryTaskItem> items) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _tasks[index] = _tasks[index].copyWith(items: items);
    notifyListeners();
  }

  void completeDelivery(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _tasks[index] =
        _tasks[index].copyWith(status: DeliveryTaskStatus.completed);

    final task = _tasks[index];
    _trips.insert(
      0,
      CompletedTrip(
        orderId: task.id,
        route: '${task.pharmacyName} → ${task.customerName}',
        earnings: 85,
        completedAt: DateTime.now(),
      ),
    );

    final nextIndex = _tasks.indexWhere(
      (t) => t.status == DeliveryTaskStatus.next,
    );
    if (nextIndex >= 0) {
      _tasks[nextIndex] =
          _tasks[nextIndex].copyWith(status: DeliveryTaskStatus.active);
    }

    if (_earnings != null) {
      _earnings = EarningsSummary(
        today: _earnings!.today + 85,
        week: _earnings!.week + 85,
        month: _earnings!.month + 85,
        totalTrips: _earnings!.totalTrips + 1,
        perTrip: _earnings!.perTrip,
        onTimePct: _earnings!.onTimePct,
        weekChart: _earnings!.weekChart,
      );
    }

    notifyListeners();
  }
}
