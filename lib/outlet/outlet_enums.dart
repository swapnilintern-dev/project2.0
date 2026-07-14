// =============================================================================
// VS Arogya — Outlet Staff · Domain Enums
//
// Foundational value types for the Outlet Staff role. Kept dependency-free so
// every later layer (models, repository, mock datasource, screens) shares ONE
// source of truth for the order lifecycle.
//
// IMPORTANT (locked rule #3): order status is OWNED BY THE SERVER. The client
// never sets `paid` locally — it only reads whatever status the backend/webhook
// reports. The `.api` tokens below are the exact strings exchanged with the
// backend, so parsing/serialising round-trips cleanly once the API is live.
// =============================================================================

/// How the walk-in order is fulfilled.
///
/// The address form appears ONLY for [delivery] (locked rule #2).
enum OutletOrderType {
  counter, // handed over at the shop counter
  delivery; // dispatched to the customer's address

  /// Wire token exchanged with the backend.
  String get api => switch (this) {
        OutletOrderType.counter => 'COUNTER',
        OutletOrderType.delivery => 'DELIVERY',
      };

  /// Human-friendly label for the UI.
  String get label => switch (this) {
        OutletOrderType.counter => 'Counter handover',
        OutletOrderType.delivery => 'Home delivery',
      };

  /// Whether a delivery address is required for this order type.
  bool get needsAddress => this == OutletOrderType.delivery;

  static OutletOrderType fromApi(String? raw) =>
      raw?.toUpperCase() == 'DELIVERY'
          ? OutletOrderType.delivery
          : OutletOrderType.counter;
}

/// Payment channel offered to the walk-in customer.
///
/// QR or payment link ONLY — no cash, no COD (locked rule #3).
enum OutletPaymentMethod {
  qr, // Razorpay QR shown at the counter
  paymentLink; // Razorpay payment link (e.g. sent to the customer's phone)

  String get api => switch (this) {
        OutletPaymentMethod.qr => 'QR',
        OutletPaymentMethod.paymentLink => 'PAYMENT_LINK',
      };

  String get label => switch (this) {
        OutletPaymentMethod.qr => 'Razorpay QR',
        OutletPaymentMethod.paymentLink => 'Payment link',
      };

  static OutletPaymentMethod fromApi(String? raw) =>
      raw?.toUpperCase() == 'PAYMENT_LINK'
          ? OutletPaymentMethod.paymentLink
          : OutletPaymentMethod.qr;
}

/// The server-owned order lifecycle.
///
/// Flow:
///   awaitingPayment
///     └─(Razorpay webhook)→ paid
///                             ├─ COUNTER   → handedOver
///                             └─ DELIVERY  → readyForPickup
///                                              → outForDelivery
///                                                → delivered
///   awaitingPayment ─(expiry / cancel)→ expired / cancelled  (releases stock)
///
/// Nothing is handed over or dispatched until the status is [paid] or later —
/// and only the SERVER may move an order to [paid].
enum OutletOrderStatus {
  awaitingPayment,
  paid,
  handedOver, // terminal (counter)
  readyForPickup, // paid + delivery, waiting for an agent
  outForDelivery,
  delivered, // terminal (delivery)
  cancelled, // terminal — reserved stock released
  expired; // terminal — payment window lapsed, reserved stock released

  /// Wire token exchanged with the backend.
  String get api => switch (this) {
        OutletOrderStatus.awaitingPayment => 'AWAITING_PAYMENT',
        OutletOrderStatus.paid => 'PAID',
        OutletOrderStatus.handedOver => 'HANDED_OVER',
        OutletOrderStatus.readyForPickup => 'READY_FOR_PICKUP',
        OutletOrderStatus.outForDelivery => 'OUT_FOR_DELIVERY',
        OutletOrderStatus.delivered => 'DELIVERED',
        OutletOrderStatus.cancelled => 'CANCELLED',
        OutletOrderStatus.expired => 'EXPIRED',
      };

  /// Short label for chips / status pills.
  String get label => switch (this) {
        OutletOrderStatus.awaitingPayment => 'Awaiting payment',
        OutletOrderStatus.paid => 'Paid',
        OutletOrderStatus.handedOver => 'Handed over',
        OutletOrderStatus.readyForPickup => 'Ready for pickup',
        OutletOrderStatus.outForDelivery => 'Out for delivery',
        OutletOrderStatus.delivered => 'Delivered',
        OutletOrderStatus.cancelled => 'Cancelled',
        OutletOrderStatus.expired => 'Expired',
      };

  /// The customer has paid (server-confirmed). Only past this point may staff
  /// hand over or dispatch medicine.
  bool get isPaid => this != OutletOrderStatus.awaitingPayment && !isReleased;

  /// Payment window still open — nothing has been collected yet.
  bool get isAwaitingPayment => this == OutletOrderStatus.awaitingPayment;

  /// Stock was released back (never paid, or cancelled after paying is N/A here).
  bool get isReleased =>
      this == OutletOrderStatus.cancelled || this == OutletOrderStatus.expired;

  /// No further transitions possible.
  bool get isTerminal =>
      this == OutletOrderStatus.handedOver ||
      this == OutletOrderStatus.delivered ||
      isReleased;

  static OutletOrderStatus fromApi(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'PAID':
        return OutletOrderStatus.paid;
      case 'HANDED_OVER':
        return OutletOrderStatus.handedOver;
      case 'READY_FOR_PICKUP':
        return OutletOrderStatus.readyForPickup;
      case 'OUT_FOR_DELIVERY':
        return OutletOrderStatus.outForDelivery;
      case 'DELIVERED':
        return OutletOrderStatus.delivered;
      case 'CANCELLED':
        return OutletOrderStatus.cancelled;
      case 'EXPIRED':
        return OutletOrderStatus.expired;
      case 'AWAITING_PAYMENT':
      default:
        return OutletOrderStatus.awaitingPayment;
    }
  }
}
