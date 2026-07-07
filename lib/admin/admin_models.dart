// =============================================================================
// MediCaPlus — Admin (Platform Operator) · Models & dummy data
//
// Frontend-only models for the platform-operator role (think "VS Arogya"):
// vendors awaiting approval, marketplace orders, disputes, platform users,
// delivery agents, the product catalogue and analytics series.
//
// Every list below is static dummy data. Replace each `// TODO: GET …` with a
// real API call when the backend lands; the screens read these lists directly.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../vendor_registration_screen.dart' show AppColors;
import 'admin_common.dart';

// -----------------------------------------------------------------------------
// OVERVIEW / KPIs
// -----------------------------------------------------------------------------

// TODO: GET /api/admin/overview
const double kGmvMtd = 28400000; // ₹2.84 Cr
const double kGmvChangePct = 31;
const int kTotalOrders = 14208;
const int kActiveVendors = 486;
const int kPendingApprovals = 23;
const int kOpenDisputes = 6;

// 6-month GMV trend (₹ crore).
const List<FlSpot> kGmvTrend = [
  FlSpot(0, 1.6),
  FlSpot(1, 1.9),
  FlSpot(2, 1.8),
  FlSpot(3, 2.2),
  FlSpot(4, 2.5),
  FlSpot(5, 2.84),
];
const List<String> kGmvMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];

class ActivityItem {
  const ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.timeAgo,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String timeAgo;
}

// TODO: GET /api/admin/activity
const List<ActivityItem> kActivity = [
  ActivityItem(
    icon: Icons.verified_outlined,
    color: AdminColors.green,
    title: 'New vendor approved',
    subtitle: 'CarePlus Wholesale · Thane',
    timeAgo: '12m ago',
  ),
  ActivityItem(
    icon: Icons.report_gmailerrorred_outlined,
    color: AdminColors.red,
    title: 'Dispute raised',
    subtitle: '#DSP-1042 · Wellness Mart',
    timeAgo: '1h ago',
  ),
  ActivityItem(
    icon: Icons.local_shipping_outlined,
    color: AdminColors.blue,
    title: 'Agent onboarded',
    subtitle: 'Suresh Patil · Andheri–Bandra',
    timeAgo: '3h ago',
  ),
  ActivityItem(
    icon: Icons.inventory_2_outlined,
    color: AdminColors.purple,
    title: 'Catalogue updated',
    subtitle: 'MedPlus Retail · 48 new SKUs',
    timeAgo: '5h ago',
  ),
  ActivityItem(
    icon: Icons.account_balance_wallet_outlined,
    color: AdminColors.orange,
    title: 'Payout processed',
    subtitle: 'Apollo Pharmacy · ₹3.4L',
    timeAgo: 'Yesterday',
  ),
];

// -----------------------------------------------------------------------------
// ANALYTICS
// -----------------------------------------------------------------------------

const double kPlatformRevenue = 28400000; // ₹2.84 Cr
const double kTakeRate = 8.5; // %
const double kOnTimeDelivery = 0.86;
const double kBuyerRetention = 0.64;

class CitySales {
  const CitySales(this.city, this.value);
  final String city;
  final double value; // relative bar height
}

// TODO: GET /api/admin/analytics/cities
const List<CitySales> kOrdersByCity = [
  CitySales('Mum', 9.2),
  CitySales('Pun', 7.4),
  CitySales('Tha', 6.1),
  CitySales('Nsk', 4.3),
  CitySales('Ngp', 3.8),
  CitySales('Aur', 2.6),
];

class CategorySplit {
  const CategorySplit(this.name, this.fraction, this.color);
  final String name;
  final double fraction;
  final Color color;
}

// TODO: GET /api/admin/analytics/categories
const List<CategorySplit> kCategorySplit = [
  CategorySplit('Medicine', 0.52, AdminColors.green),
  CategorySplit('Lifesaving Injections', 0.30, AdminColors.blue),
  CategorySplit('Vaccines', 0.18, AdminColors.purple),
];

// -----------------------------------------------------------------------------
// VENDORS
// -----------------------------------------------------------------------------

enum VendorStatus { active, pending, review, suspended }

extension VendorStatusX on VendorStatus {
  String get label => switch (this) {
    VendorStatus.active => 'Active',
    VendorStatus.pending => 'Pending',
    VendorStatus.review => 'Review',
    VendorStatus.suspended => 'Suspended',
  };

  Color get color => switch (this) {
    VendorStatus.active => AdminColors.green,
    VendorStatus.pending => AdminColors.orange,
    VendorStatus.review => AdminColors.blue,
    VendorStatus.suspended => AdminColors.red,
  };
}

class VendorDoc {
  const VendorDoc(this.name, this.verified, {this.url});
  final String name;
  final bool verified;

  /// The uploaded document's image URL (Cloudinary), or null when not provided.
  final String? url;
}

class Vendor {
  Vendor({
    this.id = '',
    required this.name,
    required this.legalName,
    required this.city,
    required this.gstin,
    required this.orders,
    required this.rating,
    required this.appliedOn,
    required this.status,
    required this.docs,
    this.mobile = '',
    this.email = '',
    this.fullAddress = '',
    this.state = '',
    this.pincode = '',
    this.storePhotoUrl,
    this.vendorType = '',
    this.shopType = '',
  });

  /// Backend _id (empty for the seeded demo vendors). Used to approve via API.
  final String id;
  final String name;
  final String legalName;
  final String city;
  final String gstin;
  final int orders;
  final double rating;
  final String appliedOn;
  VendorStatus status;
  final List<VendorDoc> docs;

  // --- Extra detail fields (populated from the backend) ---
  final String mobile;
  final String email;
  final String fullAddress;
  final String state;
  final String pincode;
  final String? storePhotoUrl; // shown as the header avatar
  final String vendorType;
  final String shopType;
}

// Vendors are fetched live from the backend (GET /vsArogya/all-vendors) via
// AdminApi.getAllVendors() — there is no dummy/seed vendor list.

// -----------------------------------------------------------------------------
// ORDERS
// -----------------------------------------------------------------------------

// Backend order lifecycle (server orderModel enum):
// Pending → Confirm Order → Shipped → Out for Delivery → Delivered / Cancelled.
enum AdminOrderStatus {
  pending,
  confirmed,
  shipped,
  outForDelivery,
  delivered,
  cancelled,
}

extension AdminOrderStatusX on AdminOrderStatus {
  String get label => switch (this) {
    AdminOrderStatus.pending => 'Pending',
    AdminOrderStatus.confirmed => 'Confirmed',
    AdminOrderStatus.shipped => 'Shipped',
    AdminOrderStatus.outForDelivery => 'Out for Delivery',
    AdminOrderStatus.delivered => 'Delivered',
    AdminOrderStatus.cancelled => 'Cancelled',
  };

  Color get color => switch (this) {
    AdminOrderStatus.pending => AdminColors.orange,
    AdminOrderStatus.confirmed => AdminColors.blue,
    AdminOrderStatus.shipped => AdminColors.purple,
    AdminOrderStatus.outForDelivery => AdminColors.amber,
    AdminOrderStatus.delivered => AdminColors.darkGreen,
    AdminOrderStatus.cancelled => AdminColors.red,
  };

  /// The label for the button that advances this order to the next stage, or
  /// null when the order is in a terminal state (delivered / cancelled).
  String? get advanceLabel => switch (this) {
    AdminOrderStatus.pending => 'Confirm Order',
    AdminOrderStatus.confirmed => 'Mark Shipped',
    AdminOrderStatus.shipped => 'Out for Delivery',
    AdminOrderStatus.outForDelivery => 'Mark Delivered',
    AdminOrderStatus.delivered => null,
    AdminOrderStatus.cancelled => null,
  };

  /// The status this order moves to when the admin advances it.
  AdminOrderStatus? get next => switch (this) {
    AdminOrderStatus.pending => AdminOrderStatus.confirmed,
    AdminOrderStatus.confirmed => AdminOrderStatus.shipped,
    AdminOrderStatus.shipped => AdminOrderStatus.outForDelivery,
    AdminOrderStatus.outForDelivery => AdminOrderStatus.delivered,
    AdminOrderStatus.delivered => null,
    AdminOrderStatus.cancelled => null,
  };
}

/// One line item inside an [AdminOrder] (product + quantity + price).
class AdminOrderLine {
  const AdminOrderLine({
    required this.name,
    required this.brand,
    required this.quantity,
    required this.price,
  });

  final String name;
  final String brand;
  final int quantity;
  final double price;
}

/// A marketplace order, mapped from the backend (GET /vsArogya/all-orders).
class AdminOrder {
  AdminOrder({
    required this.id,
    required this.buyer,
    required this.amount,
    required this.itemCount,
    required this.status,
    required this.lines,
    this.placedAt,
    this.phone = '',
    this.address = '',
    this.paymentMethod = '',
  });

  final String id;
  final String buyer;
  final double amount;
  final int itemCount;
  AdminOrderStatus status; // mutable so status advances update in place
  final List<AdminOrderLine> lines;
  final DateTime? placedAt;
  final String phone;
  final String address;
  final String paymentMethod;
}

// -----------------------------------------------------------------------------
// DISPUTES
// -----------------------------------------------------------------------------

class DisputeMessage {
  const DisputeMessage({
    required this.fromVendor,
    required this.author,
    required this.text,
  });

  final bool fromVendor;
  final String author;
  final String text;
}

class Dispute {
  const Dispute({
    required this.id,
    required this.orderId,
    required this.reason,
    required this.detail,
    required this.buyer,
    required this.vendor,
    required this.amount,
    required this.openedAgo,
    required this.messages,
    required this.evidenceCount,
  });

  final String id;
  final String orderId;
  final String reason;
  final String detail;
  final String buyer;
  final String vendor;
  final double amount;
  final String openedAgo;
  final List<DisputeMessage> messages;
  final int evidenceCount;
}

// TODO: GET /api/admin/disputes/:id
const Dispute kSampleDispute = Dispute(
  id: 'DSP-1042',
  orderId: 'MCP-47120',
  reason: 'Wrong Items Delivered',
  detail: 'Raised by Wellness Mart · 2 days ago',
  buyer: 'Wellness Mart',
  vendor: 'ValueRx Traders',
  amount: 6240,
  openedAgo: '2 days ago',
  evidenceCount: 2,
  messages: [
    DisputeMessage(
      fromVendor: false,
      author: 'Wellness Mart',
      text: 'Received Amoxicillin instead of Azithromycin. 90 units affected.',
    ),
    DisputeMessage(
      fromVendor: true,
      author: 'ValueRx',
      text: 'Apologies — we’ll arrange a replacement dispatch today.',
    ),
  ],
);

// -----------------------------------------------------------------------------
// PLATFORM USERS (User Management)
// -----------------------------------------------------------------------------

enum UserKind { customer, agent, staff }

enum UserTag { premium, isNew, flagged, suspended, active, onDuty, pending }

extension UserTagX on UserTag {
  String get label => switch (this) {
    UserTag.premium => 'Premium',
    UserTag.isNew => 'New',
    UserTag.flagged => 'Flagged',
    UserTag.suspended => 'Suspended',
    UserTag.active => 'Active',
    UserTag.onDuty => 'On Duty',
    UserTag.pending => 'Pending',
  };

  Color get color => switch (this) {
    UserTag.premium => AdminColors.purple,
    UserTag.isNew => AdminColors.blue,
    UserTag.flagged => AdminColors.amber,
    UserTag.suspended => AdminColors.red,
    UserTag.active => AdminColors.green,
    UserTag.onDuty => AdminColors.green,
    UserTag.pending => AdminColors.orange,
  };
}

extension UserKindX on UserKind {
  String get label => switch (this) {
    UserKind.customer => 'Vendor',
    UserKind.agent => 'Delivery Agent',
    UserKind.staff => 'Staff Member',
  };

  String get detailTitle => switch (this) {
    UserKind.customer => 'Vendor Details',
    UserKind.agent => 'Agent Details',
    UserKind.staff => 'Staff Details',
  };

  Color get color => switch (this) {
    UserKind.customer => AdminColors.blue,
    UserKind.agent => AdminColors.purple,
    UserKind.staff => AppColors.darkGreen,
  };

  IconData get icon => switch (this) {
    UserKind.customer => Icons.storefront_outlined,
    UserKind.agent => Icons.delivery_dining_outlined,
    UserKind.staff => Icons.badge_outlined,
  };
}

/// A headline metric tile shown at the top of the detail screen.
class UserStat {
  const UserStat(this.value, this.label, {this.color});
  final String value;
  final String label;
  final Color? color;
}

/// A label → value row inside the "Information" card.
class InfoPair {
  const InfoPair(this.label, this.value);
  final String label;
  final String value;
}

/// One entry in the per-user activity timeline (orders / deliveries / actions).
class TimelineEntry {
  const TimelineEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
}

class PlatformUser {
  const PlatformUser({
    this.id = '',
    required this.name,
    required this.kind,
    required this.meta,
    this.tag,
    this.phone = '+91 98xxx xxxxx',
    this.email = '—',
    this.location = '—',
    this.joinedOn = '—',
    this.stats = const [],
    this.info = const [],
    this.timelineTitle = 'Recent Activity',
    this.timeline = const [],
    this.photoUrl,
    this.documents = const [],
  });

  /// Backend _id (empty for seeded/test users). Used to identify a user across
  /// refreshes and for any future server-side action.
  final String id;
  final String name;
  final UserKind kind;
  final String meta;
  final UserTag? tag;

  // Shared profile fields.
  final String phone;
  final String email;
  final String location;
  final String joinedOn;

  // Role-specific detail content.
  final List<UserStat> stats;
  final List<InfoPair> info;
  final String timelineTitle;
  final List<TimelineEntry> timeline;

  /// The store/profile photo (Cloudinary), shown as the detail header image
  /// when present; falls back to initials otherwise.
  final String? photoUrl;

  /// Uploaded verification documents (store photo, GST, drug license) as
  /// name → URL entries. Empty for delivery agents / when nothing was uploaded.
  final List<VendorDoc> documents;
}

// Platform users (vendors + delivery agents) are fetched live from the
// backend (GET /vsArogya/all-vendors) via AdminApi.getAllPlatformUsers() and
// held in AdminUsersController � there is no dummy/seed user list or count.

// -----------------------------------------------------------------------------
// DELIVERY AGENTS
// -----------------------------------------------------------------------------

const int kAgentsTotal = 128;
const int kAgentsOnDuty = 86;
const int kAgentsPending = 12;

const List<String> kServiceZones = [
  'Andheri – Bandra',
  'Pune Central',
  'Thane West',
  'Nashik City',
  'Nagpur East',
];

// -----------------------------------------------------------------------------
// PRODUCTS (catalogue)
// -----------------------------------------------------------------------------

class AdminProduct {
  AdminProduct({
    required this.name,
    required this.sku,
    required this.price,
    required this.stock,
    required this.category,
    this.active = true,
  });

  final String name;
  final String sku;
  final double price;
  final int stock;
  final String category;
  bool active;
}

const int kSkusTotal = 312;
const int kSkusActive = 298;
const int kSkusLow = 7;
const int kSkusOut = 7;

const List<String> kProductCategories = [
  'Lifesaving Injections',
  'Vaccines',
  'Medicine',
];

// TODO: GET /api/admin/products
final List<AdminProduct> kProducts = [
  AdminProduct(
    name: 'Paracetamol 650mg',
    sku: 'PCM-650-15',
    price: 36,
    stock: 500,
    category: 'Medicine',
  ),
  AdminProduct(
    name: 'Amoxicillin 500mg',
    sku: 'AMX-500-10',
    price: 84,
    stock: 240,
    category: 'Medicine',
  ),
  AdminProduct(
    name: 'Insulin Glargine',
    sku: 'INS-GLA-3',
    price: 845,
    stock: 8,
    category: 'Lifesaving Injections',
  ),
  AdminProduct(
    name: 'Surgical Gloves (L)',
    sku: 'SGL-L-100',
    price: 320,
    stock: 0,
    category: 'Medicine',
  ),
  AdminProduct(
    name: 'Digital Thermometer',
    sku: 'DTH-001',
    price: 199,
    stock: 84,
    category: 'Medicine',
  ),
  AdminProduct(
    name: 'Azithromycin 500mg',
    sku: 'AZI-500-3',
    price: 112,
    stock: 12,
    category: 'Medicine',
  ),
  AdminProduct(
    name: 'ORS Sachets',
    sku: 'ORS-200',
    price: 22,
    stock: 640,
    category: 'Medicine',
  ),
];
