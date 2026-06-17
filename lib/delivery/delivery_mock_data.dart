// =============================================================================
// MediCaPlus — Delivery Partner Mock Data
// =============================================================================

import 'delivery_models.dart';

class DeliveryMockData {
  DeliveryMockData._();

  static const rider = RiderProfile(
    id: 'DA-2048',
    name: 'Rahul Kumar',
    initials: 'RK',
    phone: '+91 98765 43210',
    role: 'Delivery Partner',
    rating: 4.9,
    totalDeliveries: 1240,
    vehicle: VehicleInfo(
      number: 'MH 12 AB 4521',
      type: 'Two-wheeler',
      verified: true,
    ),
  );

  static List<DeliveryTask> get tasks => [
        DeliveryTask(
          id: 'MCP-48210',
          pharmacyName: 'Apollo Pharmacy',
          address: 'Sector 62, Commercial Complex, Block C',
          distanceKm: 2.4,
          itemCount: 6,
          codAmount: 4820,
          status: DeliveryTaskStatus.active,
          customerName: 'MedCare Pharmacy',
          customerPhone: '+91 98111 22334',
          pharmacyPhone: '+91 98222 33445',
          turnInstruction: 'Turn right onto Link Rd',
          etaMinutes: 8,
          routeDistanceKm: 2.4,
          items: const [
            DeliveryTaskItem(name: 'Paracetamol 650mg', quantity: 2),
            DeliveryTaskItem(name: 'Amoxicillin 250mg', quantity: 1),
            DeliveryTaskItem(name: 'Cetirizine 10mg', quantity: 3),
          ],
        ),
        DeliveryTask(
          id: 'MCP-48211',
          pharmacyName: 'MedPlus Pharmacy',
          address: 'Andheri West, SV Road',
          distanceKm: 3.1,
          itemCount: 4,
          codAmount: 2310,
          status: DeliveryTaskStatus.next,
          customerName: 'City Hospital',
          customerPhone: '+91 98333 44556',
          pharmacyPhone: '+91 98444 55667',
          turnInstruction: 'Continue straight for 1.2 km',
          etaMinutes: 12,
          routeDistanceKm: 3.1,
          items: const [
            DeliveryTaskItem(name: 'Azithromycin 500mg', quantity: 2),
            DeliveryTaskItem(name: 'Pantoprazole 40mg', quantity: 2),
          ],
        ),
        DeliveryTask(
          id: 'MCP-48212',
          pharmacyName: 'Wellness Store',
          address: 'Bandra Kurla Complex, Gate 4',
          distanceKm: 5.6,
          itemCount: 8,
          codAmount: 7650,
          status: DeliveryTaskStatus.queued,
          customerName: 'Green Cross',
          customerPhone: '+91 98555 66778',
          pharmacyPhone: '+91 98666 77889',
          turnInstruction: 'Head north on BKC Rd',
          etaMinutes: 18,
          routeDistanceKm: 5.6,
          items: const [
            DeliveryTaskItem(name: 'Metformin 500mg', quantity: 4),
            DeliveryTaskItem(name: 'Vitamin D3 60k', quantity: 4),
          ],
        ),
      ];

  static const earnings = EarningsSummary(
    today: 680,
    week: 4820,
    month: 18420,
    totalTrips: 48,
    perTrip: 100,
    onTimePct: 98,
    weekChart: [320, 410, 380, 520, 480, 610, 680],
  );

  static List<CompletedTrip> get recentTrips => [
        CompletedTrip(
          orderId: 'MCP-48205',
          route: 'Andheri → Bandra',
          earnings: 95,
          completedAt: DateTime(2026, 6, 17, 9, 30),
        ),
        CompletedTrip(
          orderId: 'MCP-48203',
          route: 'Powai → Ghatkopar',
          earnings: 110,
          completedAt: DateTime(2026, 6, 17, 7, 15),
        ),
        CompletedTrip(
          orderId: 'MCP-48198',
          route: 'Thane → Mulund',
          earnings: 85,
          completedAt: DateTime(2026, 6, 16, 18, 45),
        ),
        CompletedTrip(
          orderId: 'MCP-48192',
          route: 'Dadar → Worli',
          earnings: 75,
          completedAt: DateTime(2026, 6, 16, 15, 20),
        ),
      ];

  static void seed() {
    DeliveryController.instance.initialize(
      rider: rider,
      tasks: tasks,
      earnings: earnings,
      trips: recentTrips,
    );
  }
}
