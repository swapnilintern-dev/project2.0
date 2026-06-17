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
  CategorySplit('Tablets', 0.38, AdminColors.green),
  CategorySplit('Injections', 0.24, AdminColors.blue),
  CategorySplit('Surgical', 0.18, AdminColors.purple),
  CategorySplit('Wellness', 0.12, AdminColors.orange),
  CategorySplit('Devices', 0.08, AdminColors.darkGreen),
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
  const VendorDoc(this.name, this.verified);
  final String name;
  final bool verified;
}

class Vendor {
  Vendor({
    required this.name,
    required this.legalName,
    required this.city,
    required this.gstin,
    required this.orders,
    required this.rating,
    required this.appliedOn,
    required this.status,
    required this.docs,
  });

  final String name;
  final String legalName;
  final String city;
  final String gstin;
  final int orders;
  final double rating;
  final String appliedOn;
  VendorStatus status;
  final List<VendorDoc> docs;
}

// TODO: GET /api/admin/vendors
final List<Vendor> kVendors = [
  Vendor(
    name: 'MedSupply Co.',
    legalName: 'MedSupply Distributors Pvt Ltd',
    city: 'Mumbai',
    gstin: '27MEDSP1234K1Z5',
    orders: 1240,
    rating: 4.8,
    appliedOn: '02 Jan 2026',
    status: VendorStatus.active,
    docs: const [
      VendorDoc('Drug Licence (Form 20B)', true),
      VendorDoc('GST Certificate', true),
      VendorDoc('FSSAI Licence', true),
      VendorDoc('PAN Card', true),
      VendorDoc('Bank Proof', true),
    ],
  ),
  Vendor(
    name: 'HealthFirst Dist.',
    legalName: 'HealthFirst Distribution LLP',
    city: 'Pune',
    gstin: '27HLTHF5678M1Z2',
    orders: 890,
    rating: 4.6,
    appliedOn: '08 Jan 2026',
    status: VendorStatus.active,
    docs: const [
      VendorDoc('Drug Licence (Form 20B)', true),
      VendorDoc('GST Certificate', true),
      VendorDoc('FSSAI Licence', true),
      VendorDoc('PAN Card', true),
      VendorDoc('Bank Proof', true),
    ],
  ),
  Vendor(
    name: 'CarePlus Wholesale',
    legalName: 'CarePlus Wholesale Pvt Ltd',
    city: 'Thane',
    gstin: '27CRPLS5678K1Z2',
    orders: 0,
    rating: 0,
    appliedOn: '14 Jun 2026',
    status: VendorStatus.pending,
    docs: const [
      VendorDoc('Drug Licence (Form 20B)', true),
      VendorDoc('GST Certificate', true),
      VendorDoc('FSSAI Licence', true),
      VendorDoc('PAN Card', false),
      VendorDoc('Bank Proof', false),
    ],
  ),
  Vendor(
    name: 'QuickMeds Supply',
    legalName: 'QuickMeds Supply Co.',
    city: 'Nashik',
    gstin: '27QKMDS9012P1Z8',
    orders: 12,
    rating: 4.1,
    appliedOn: '11 Jun 2026',
    status: VendorStatus.review,
    docs: const [
      VendorDoc('Drug Licence (Form 20B)', true),
      VendorDoc('GST Certificate', true),
      VendorDoc('FSSAI Licence', false),
      VendorDoc('PAN Card', true),
      VendorDoc('Bank Proof', false),
    ],
  ),
  Vendor(
    name: 'ValueRx Traders',
    legalName: 'ValueRx Traders Pvt Ltd',
    city: 'Nagpur',
    gstin: '27VLRXT3456R1Z1',
    orders: 340,
    rating: 3.2,
    appliedOn: '20 Feb 2026',
    status: VendorStatus.suspended,
    docs: const [
      VendorDoc('Drug Licence (Form 20B)', true),
      VendorDoc('GST Certificate', true),
      VendorDoc('FSSAI Licence', true),
      VendorDoc('PAN Card', true),
      VendorDoc('Bank Proof', true),
    ],
  ),
];

// -----------------------------------------------------------------------------
// ORDERS
// -----------------------------------------------------------------------------

enum AdminOrderStatus { processing, transit, delivered, disputed }

extension AdminOrderStatusX on AdminOrderStatus {
  String get label => switch (this) {
        AdminOrderStatus.processing => 'Processing',
        AdminOrderStatus.transit => 'In Transit',
        AdminOrderStatus.delivered => 'Delivered',
        AdminOrderStatus.disputed => 'Disputed',
      };

  Color get color => switch (this) {
        AdminOrderStatus.processing => AdminColors.orange,
        AdminOrderStatus.transit => AdminColors.blue,
        AdminOrderStatus.delivered => AdminColors.darkGreen,
        AdminOrderStatus.disputed => AdminColors.red,
      };
}

class AdminOrder {
  const AdminOrder({
    required this.id,
    required this.buyer,
    required this.vendor,
    required this.amount,
    required this.items,
    required this.status,
    this.disputeId,
  });

  final String id;
  final String buyer;
  final String vendor;
  final double amount;
  final int items;
  final AdminOrderStatus status;
  final String? disputeId;
}

// TODO: GET /api/admin/orders
const List<AdminOrder> kOrders = [
  AdminOrder(
      id: 'MCP-48210',
      buyer: 'Apollo Pharmacy',
      vendor: 'MedSupply Co.',
      amount: 1519,
      items: 8,
      status: AdminOrderStatus.transit),
  AdminOrder(
      id: 'MCP-48196',
      buyer: 'HealthFirst',
      vendor: 'CarePlus',
      amount: 14280,
      items: 36,
      status: AdminOrderStatus.processing),
  AdminOrder(
      id: 'MCP-47120',
      buyer: 'Wellness Mart',
      vendor: 'ValueRx',
      amount: 6240,
      items: 15,
      status: AdminOrderStatus.disputed,
      disputeId: 'DSP-1042'),
  AdminOrder(
      id: 'MCP-48108',
      buyer: 'MedPlus',
      vendor: 'HealthFirst',
      amount: 3380,
      items: 11,
      status: AdminOrderStatus.delivered),
  AdminOrder(
      id: 'MCP-48090',
      buyer: 'City Care Chemist',
      vendor: 'QuickMeds',
      amount: 9870,
      items: 24,
      status: AdminOrderStatus.transit),
  AdminOrder(
      id: 'MCP-48055',
      buyer: 'Green Cross Pharma',
      vendor: 'MedSupply Co.',
      amount: 2110,
      items: 6,
      status: AdminOrderStatus.processing),
  AdminOrder(
      id: 'MCP-47980',
      buyer: 'Sunrise Medicals',
      vendor: 'ValueRx',
      amount: 540,
      items: 3,
      status: AdminOrderStatus.delivered),
];

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

enum UserTag { premium, isNew, flagged, suspended, active, onDuty }

extension UserTagX on UserTag {
  String get label => switch (this) {
        UserTag.premium => 'Premium',
        UserTag.isNew => 'New',
        UserTag.flagged => 'Flagged',
        UserTag.suspended => 'Suspended',
        UserTag.active => 'Active',
        UserTag.onDuty => 'On Duty',
      };

  Color get color => switch (this) {
        UserTag.premium => AdminColors.purple,
        UserTag.isNew => AdminColors.blue,
        UserTag.flagged => AdminColors.amber,
        UserTag.suspended => AdminColors.red,
        UserTag.active => AdminColors.green,
        UserTag.onDuty => AdminColors.green,
      };
}

extension UserKindX on UserKind {
  String get label => switch (this) {
        UserKind.customer => 'Customer',
        UserKind.agent => 'Delivery Agent',
        UserKind.staff => 'Staff Member',
      };

  String get detailTitle => switch (this) {
        UserKind.customer => 'Customer Details',
        UserKind.agent => 'Agent Details',
        UserKind.staff => 'Staff Details',
      };

  Color get color => switch (this) {
        UserKind.customer => AdminColors.blue,
        UserKind.agent => AdminColors.purple,
        UserKind.staff => AppColors.darkGreen,
      };

  IconData get icon => switch (this) {
        UserKind.customer => Icons.local_pharmacy_outlined,
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
  });

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
}

const int kCustomerCount = 12400;
const int kVendorCount = 486;
const int kAgentCount = 128;

// TODO: GET /api/admin/users  (and GET /api/admin/users/:id for the detail view)
const List<PlatformUser> kUsers = [
  // --- Customers (B2B pharmacy buyers) -------------------------------------
  PlatformUser(
    name: 'Apollo Pharmacy',
    kind: UserKind.customer,
    meta: '48 orders · Mumbai',
    tag: UserTag.premium,
    phone: '+91 98200 11234',
    email: 'orders@apollopharma.in',
    location: 'Andheri East, Mumbai',
    joinedOn: '12 Jan 2024',
    stats: [
      UserStat('48', 'Orders', color: AdminColors.blue),
      UserStat('₹3.2L', 'Lifetime Spend', color: AppColors.primary),
      UserStat('★ 4.9', 'Buyer Rating', color: AdminColors.orange),
    ],
    info: [
      InfoPair('Account Type', 'Premium B2B'),
      InfoPair('GSTIN', '27APLLO1234K1Z9'),
      InfoPair('Credit Limit', '₹5,00,000'),
      InfoPair('Outstanding', '₹42,000'),
      InfoPair('Open Disputes', '0'),
      InfoPair('Member Since', '12 Jan 2024'),
    ],
    timelineTitle: 'Recent Orders',
    timeline: [
      TimelineEntry(
          icon: Icons.check_circle_outline,
          color: AppColors.darkGreen,
          title: '#MCP-48210 · ₹1,519',
          subtitle: 'Delivered · MedSupply Co.',
          time: '2d ago'),
      TimelineEntry(
          icon: Icons.local_shipping_outlined,
          color: AdminColors.blue,
          title: '#MCP-48055 · ₹2,110',
          subtitle: 'Processing · MedSupply Co.',
          time: '4d ago'),
      TimelineEntry(
          icon: Icons.check_circle_outline,
          color: AppColors.darkGreen,
          title: '#MCP-47980 · ₹540',
          subtitle: 'Delivered · ValueRx',
          time: '1w ago'),
    ],
  ),
  PlatformUser(
    name: 'MedPlus Retail',
    kind: UserKind.customer,
    meta: '210 orders · Pune',
    tag: UserTag.premium,
    phone: '+91 98220 55678',
    email: 'procure@medplusretail.in',
    location: 'Kothrud, Pune',
    joinedOn: '03 Feb 2024',
    stats: [
      UserStat('210', 'Orders', color: AdminColors.blue),
      UserStat('₹14.6L', 'Lifetime Spend', color: AppColors.primary),
      UserStat('★ 4.7', 'Buyer Rating', color: AdminColors.orange),
    ],
    info: [
      InfoPair('Account Type', 'Premium B2B'),
      InfoPair('GSTIN', '27MEDPL5678M1Z2'),
      InfoPair('Credit Limit', '₹10,00,000'),
      InfoPair('Outstanding', '₹1,18,500'),
      InfoPair('Open Disputes', '0'),
      InfoPair('Member Since', '03 Feb 2024'),
    ],
    timelineTitle: 'Recent Orders',
    timeline: [
      TimelineEntry(
          icon: Icons.local_shipping_outlined,
          color: AdminColors.blue,
          title: '#MCP-48196 · ₹14,280',
          subtitle: 'In Transit · CarePlus',
          time: '6h ago'),
      TimelineEntry(
          icon: Icons.check_circle_outline,
          color: AppColors.darkGreen,
          title: '#MCP-48108 · ₹3,380',
          subtitle: 'Delivered · HealthFirst',
          time: '3d ago'),
    ],
  ),
  PlatformUser(
    name: 'Wellness Mart',
    kind: UserKind.customer,
    meta: '12 orders · Thane',
    tag: UserTag.isNew,
    phone: '+91 98330 44210',
    email: 'buy@wellnessmart.in',
    location: 'Ghodbunder Rd, Thane',
    joinedOn: '28 May 2026',
    stats: [
      UserStat('12', 'Orders', color: AdminColors.blue),
      UserStat('₹48.2K', 'Lifetime Spend', color: AppColors.primary),
      UserStat('1', 'Open Disputes', color: AdminColors.red),
    ],
    info: [
      InfoPair('Account Type', 'Standard B2B'),
      InfoPair('GSTIN', '27WELLN4210T1Z7'),
      InfoPair('Credit Limit', '₹1,00,000'),
      InfoPair('Outstanding', '₹6,240'),
      InfoPair('Open Disputes', '1 · #DSP-1042'),
      InfoPair('Member Since', '28 May 2026'),
    ],
    timelineTitle: 'Recent Orders',
    timeline: [
      TimelineEntry(
          icon: Icons.report_gmailerrorred_outlined,
          color: AdminColors.red,
          title: '#MCP-47120 · ₹6,240',
          subtitle: 'Disputed · ValueRx',
          time: '2d ago'),
      TimelineEntry(
          icon: Icons.check_circle_outline,
          color: AppColors.darkGreen,
          title: '#MCP-46980 · ₹1,180',
          subtitle: 'Delivered · MedSupply Co.',
          time: '1w ago'),
    ],
  ),
  PlatformUser(
    name: 'City Care Chemist',
    kind: UserKind.customer,
    meta: '6 orders · Nashik',
    tag: UserTag.isNew,
    phone: '+91 98600 77820',
    email: 'citycare.nsk@gmail.com',
    location: 'College Rd, Nashik',
    joinedOn: '04 Jun 2026',
    stats: [
      UserStat('6', 'Orders', color: AdminColors.blue),
      UserStat('₹19.4K', 'Lifetime Spend', color: AppColors.primary),
      UserStat('0', 'Open Disputes', color: AppColors.darkGreen),
    ],
    info: [
      InfoPair('Account Type', 'Standard B2B'),
      InfoPair('GSTIN', '27CTYCR7820N1Z4'),
      InfoPair('Credit Limit', '₹50,000'),
      InfoPair('Outstanding', '₹0'),
      InfoPair('Open Disputes', '0'),
      InfoPair('Member Since', '04 Jun 2026'),
    ],
    timelineTitle: 'Recent Orders',
    timeline: [
      TimelineEntry(
          icon: Icons.check_circle_outline,
          color: AppColors.darkGreen,
          title: '#MCP-48090 · ₹9,870',
          subtitle: 'In Transit · QuickMeds',
          time: '1d ago'),
    ],
  ),
  PlatformUser(
    name: 'Green Cross Pharma',
    kind: UserKind.customer,
    meta: 'Suspended · 2 disputes',
    tag: UserTag.flagged,
    phone: '+91 98190 33110',
    email: 'admin@greencrosspharma.in',
    location: 'Sitabuldi, Nagpur',
    joinedOn: '19 Mar 2025',
    stats: [
      UserStat('64', 'Orders', color: AdminColors.blue),
      UserStat('₹2.1L', 'Lifetime Spend', color: AppColors.primary),
      UserStat('2', 'Open Disputes', color: AdminColors.red),
    ],
    info: [
      InfoPair('Account Type', 'Suspended'),
      InfoPair('GSTIN', '27GRNCR3110R1Z0'),
      InfoPair('Credit Limit', '₹0 (frozen)'),
      InfoPair('Outstanding', '₹78,900'),
      InfoPair('Open Disputes', '2'),
      InfoPair('Flagged For', 'Repeated chargebacks'),
    ],
    timelineTitle: 'Recent Activity',
    timeline: [
      TimelineEntry(
          icon: Icons.block,
          color: AdminColors.red,
          title: 'Account suspended',
          subtitle: 'By Risk team',
          time: '5d ago'),
      TimelineEntry(
          icon: Icons.report_gmailerrorred_outlined,
          color: AdminColors.red,
          title: 'Dispute opened · ₹12,400',
          subtitle: 'Non-payment · HealthFirst',
          time: '2w ago'),
    ],
  ),

  // --- Delivery agents ------------------------------------------------------
  PlatformUser(
    name: 'Suresh Patil',
    kind: UserKind.agent,
    meta: 'Andheri–Bandra · 312 deliveries',
    tag: UserTag.onDuty,
    phone: '+91 98201 55420',
    email: 'suresh.patil@medicaplus.in',
    location: 'Andheri–Bandra Zone',
    joinedOn: '21 Mar 2024',
    stats: [
      UserStat('312', 'Deliveries', color: AdminColors.purple),
      UserStat('★ 4.8', 'Rating', color: AdminColors.orange),
      UserStat('98%', 'On-time', color: AppColors.primary),
    ],
    info: [
      InfoPair('Login ID', 'DA-55420'),
      InfoPair('Service Zone', 'Andheri–Bandra'),
      InfoPair('Vehicle', 'Bike · MH02 AB 1234'),
      InfoPair('Current Status', 'On Duty'),
      InfoPair("Today's Trips", '7'),
      InfoPair('Earnings (MTD)', '₹18,400'),
    ],
    timelineTitle: 'Recent Deliveries',
    timeline: [
      TimelineEntry(
          icon: Icons.check_circle_outline,
          color: AppColors.darkGreen,
          title: '#MCP-48210 · Apollo Pharmacy',
          subtitle: 'Delivered on time',
          time: '1h ago'),
      TimelineEntry(
          icon: Icons.two_wheeler_outlined,
          color: AdminColors.blue,
          title: '#MCP-48055 · Green Cross',
          subtitle: 'Out for delivery',
          time: 'Now'),
    ],
  ),
  PlatformUser(
    name: 'Neha Tiwari',
    kind: UserKind.agent,
    meta: 'Pune Central · 198 deliveries',
    tag: UserTag.onDuty,
    phone: '+91 98223 90187',
    email: 'neha.tiwari@medicaplus.in',
    location: 'Pune Central Zone',
    joinedOn: '02 May 2024',
    stats: [
      UserStat('198', 'Deliveries', color: AdminColors.purple),
      UserStat('★ 4.9', 'Rating', color: AdminColors.orange),
      UserStat('99%', 'On-time', color: AppColors.primary),
    ],
    info: [
      InfoPair('Login ID', 'DA-39018'),
      InfoPair('Service Zone', 'Pune Central'),
      InfoPair('Vehicle', 'Scooter · MH12 KL 8890'),
      InfoPair('Current Status', 'On Duty'),
      InfoPair("Today's Trips", '5'),
      InfoPair('Earnings (MTD)', '₹14,950'),
    ],
    timelineTitle: 'Recent Deliveries',
    timeline: [
      TimelineEntry(
          icon: Icons.check_circle_outline,
          color: AppColors.darkGreen,
          title: '#MCP-48108 · MedPlus',
          subtitle: 'Delivered on time',
          time: '3h ago'),
    ],
  ),
  PlatformUser(
    name: 'Arjun Kapoor',
    kind: UserKind.agent,
    meta: 'Thane West · 87 deliveries',
    tag: UserTag.active,
    phone: '+91 98337 21640',
    email: 'arjun.kapoor@medicaplus.in',
    location: 'Thane West Zone',
    joinedOn: '08 Apr 2026',
    stats: [
      UserStat('87', 'Deliveries', color: AdminColors.purple),
      UserStat('★ 4.5', 'Rating', color: AdminColors.orange),
      UserStat('94%', 'On-time', color: AppColors.primary),
    ],
    info: [
      InfoPair('Login ID', 'DA-21640'),
      InfoPair('Service Zone', 'Thane West'),
      InfoPair('Vehicle', 'Bike · MH04 GH 4521'),
      InfoPair('Current Status', 'Off Duty'),
      InfoPair("Today's Trips", '0'),
      InfoPair('Earnings (MTD)', '₹6,200'),
    ],
    timelineTitle: 'Recent Deliveries',
    timeline: [
      TimelineEntry(
          icon: Icons.check_circle_outline,
          color: AppColors.darkGreen,
          title: '#MCP-47990 · Sunrise Medicals',
          subtitle: 'Delivered · 8 min late',
          time: 'Yesterday'),
    ],
  ),

  // --- Staff (platform team) ------------------------------------------------
  PlatformUser(
    name: 'Priya Menon',
    kind: UserKind.staff,
    meta: 'Operations Manager',
    tag: UserTag.active,
    phone: '+91 98765 10020',
    email: 'priya.menon@medicaplus.in',
    location: 'HQ · Mumbai',
    joinedOn: '15 Aug 2023',
    stats: [
      UserStat('142', 'Tickets Closed', color: AppColors.darkGreen),
      UserStat('6', 'Team Size', color: AdminColors.blue),
      UserStat('Admin', 'Access', color: AdminColors.purple),
    ],
    info: [
      InfoPair('Designation', 'Operations Manager'),
      InfoPair('Department', 'Operations'),
      InfoPair('Access Level', 'Admin'),
      InfoPair('Reporting To', 'VS Arogya'),
      InfoPair('Last Active', '2h ago'),
      InfoPair('Joined', '15 Aug 2023'),
    ],
    timelineTitle: 'Recent Activity',
    timeline: [
      TimelineEntry(
          icon: Icons.verified_outlined,
          color: AppColors.darkGreen,
          title: 'Approved vendor',
          subtitle: 'CarePlus Wholesale',
          time: '2h ago'),
      TimelineEntry(
          icon: Icons.delivery_dining_outlined,
          color: AdminColors.blue,
          title: 'Onboarded agent',
          subtitle: 'Suresh Patil',
          time: '3h ago'),
    ],
  ),
  PlatformUser(
    name: 'Rohit Verma',
    kind: UserKind.staff,
    meta: 'Finance · Payouts',
    tag: UserTag.active,
    phone: '+91 98765 33450',
    email: 'rohit.verma@medicaplus.in',
    location: 'HQ · Mumbai',
    joinedOn: '02 Nov 2023',
    stats: [
      UserStat('₹3.4L', 'Payouts Today', color: AppColors.primary),
      UserStat('486', 'Vendors Paid', color: AdminColors.blue),
      UserStat('Finance', 'Access', color: AdminColors.purple),
    ],
    info: [
      InfoPair('Designation', 'Finance Associate'),
      InfoPair('Department', 'Finance · Payouts'),
      InfoPair('Access Level', 'Finance'),
      InfoPair('Reporting To', 'Priya Menon'),
      InfoPair('Last Active', '20m ago'),
      InfoPair('Joined', '02 Nov 2023'),
    ],
    timelineTitle: 'Recent Activity',
    timeline: [
      TimelineEntry(
          icon: Icons.account_balance_wallet_outlined,
          color: AdminColors.orange,
          title: 'Payout processed · ₹3.4L',
          subtitle: 'Apollo Pharmacy',
          time: '20m ago'),
    ],
  ),
  PlatformUser(
    name: 'Sana Shaikh',
    kind: UserKind.staff,
    meta: 'Support Lead',
    tag: UserTag.active,
    phone: '+91 98765 78900',
    email: 'sana.shaikh@medicaplus.in',
    location: 'HQ · Mumbai',
    joinedOn: '19 Jan 2024',
    stats: [
      UserStat('38', 'Open Tickets', color: AdminColors.orange),
      UserStat('4', 'Team Size', color: AdminColors.blue),
      UserStat('Support', 'Access', color: AdminColors.purple),
    ],
    info: [
      InfoPair('Designation', 'Support Lead'),
      InfoPair('Department', 'Customer Support'),
      InfoPair('Access Level', 'Support'),
      InfoPair('Reporting To', 'Priya Menon'),
      InfoPair('Last Active', '5m ago'),
      InfoPair('Joined', '19 Jan 2024'),
    ],
    timelineTitle: 'Recent Activity',
    timeline: [
      TimelineEntry(
          icon: Icons.gavel_outlined,
          color: AdminColors.red,
          title: 'Escalated dispute',
          subtitle: '#DSP-1042 · Wellness Mart',
          time: '5m ago'),
    ],
  ),
];

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
  'Tablets',
  'Injections',
  'Surgical',
  'Wellness',
  'Devices',
];

// TODO: GET /api/admin/products
final List<AdminProduct> kProducts = [
  AdminProduct(name: 'Paracetamol 650mg', sku: 'PCM-650-15', price: 36, stock: 500, category: 'Tablets'),
  AdminProduct(name: 'Amoxicillin 500mg', sku: 'AMX-500-10', price: 84, stock: 240, category: 'Tablets'),
  AdminProduct(name: 'Insulin Glargine', sku: 'INS-GLA-3', price: 845, stock: 8, category: 'Injections'),
  AdminProduct(name: 'Surgical Gloves (L)', sku: 'SGL-L-100', price: 320, stock: 0, category: 'Surgical'),
  AdminProduct(name: 'Digital Thermometer', sku: 'DTH-001', price: 199, stock: 84, category: 'Devices'),
  AdminProduct(name: 'Azithromycin 500mg', sku: 'AZI-500-3', price: 112, stock: 12, category: 'Tablets'),
  AdminProduct(name: 'ORS Sachets', sku: 'ORS-200', price: 22, stock: 640, category: 'Wellness'),
];
