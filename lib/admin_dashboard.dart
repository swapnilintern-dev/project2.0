// =============================================================================
// MediCaPlus — B2B Medicine Delivery
// Admin Dashboard (frontend only — all data is static dummy data)
//
// Five screens in one file, switched by the bottom navigation bar on
// [AdminDashboardScreen] (the root):
//   1. DashboardHomeScreen      — KPIs, revenue chart, recent orders, actions
//   2. OrderManagementScreen    — search, status tabs, order cards
//   3. MedicineManagementScreen — search, add, medicine cards
//   4. UserManagementScreen     — role tabs, user cards
//   5. AdminSettingsScreen      — profile, settings groups, logout
//
// Colours come from the shared `AppColors` (vendor_registration_screen.dart) so
// the whole app stays on one palette. Replace each `// TODO: GET ...` point with
// a real API call when the backend is ready.
// =============================================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'sign_in_screen.dart';
import 'vendor_registration_screen.dart' show AppColors;

// =============================================================================
// EXTRA THEME COLOURS (status pills / stock levels not in AppColors)
// =============================================================================

class AdminColors {
  AdminColors._();
  static const Color orange = Color(0xFFF59E0B); // pending / low stock
  static const Color red = AppColors.error; // cancelled / out of stock
  static const Color green = AppColors.primary; // active / in stock
  static const Color darkGreen = AppColors.darkGreen; // delivered
}

// =============================================================================
// DUMMY DATA (top of file, per the spec) — swap for API responses later
// =============================================================================

/// A single KPI tile's content. [target] is the numeric value to count up to;
/// [prefix]/[suffix] decorate it (e.g. ₹ … L), [changePct] is the trend badge.
class KpiData {
  const KpiData({
    required this.title,
    required this.target,
    required this.icon,
    required this.color,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.grouped = false,
    this.changePct,
  });

  final String title;
  final double target;
  final IconData icon;
  final Color color;
  final String prefix;
  final String suffix;
  final int decimals;
  final bool grouped; // show thousands separators (e.g. 2,841)
  final double? changePct;
}

// TODO: GET /api/admin/dashboard  → KPI summary
const List<KpiData> kDummyKpis = [
  KpiData(
    title: "Today's Revenue",
    target: 1.24,
    prefix: '₹',
    suffix: 'L',
    decimals: 2,
    icon: Icons.currency_rupee,
    color: AppColors.primary,
    changePct: 12.4,
  ),
  KpiData(
    title: 'Orders Today',
    target: 348,
    icon: Icons.receipt_long_outlined,
    color: Color(0xFF3B82F6),
    changePct: 8.2,
  ),
  KpiData(
    title: 'Active Users',
    target: 2841,
    grouped: true,
    icon: Icons.people_alt_outlined,
    color: Color(0xFF8B5CF6),
  ),
  KpiData(
    title: 'Active Vendors',
    target: 156,
    icon: Icons.storefront_outlined,
    color: AdminColors.orange,
  ),
];

// TODO: GET /api/admin/dashboard  → last 7 days revenue series
const List<FlSpot> kRevenueSpots = [
  FlSpot(0, 3.1),
  FlSpot(1, 2.6),
  FlSpot(2, 4.2),
  FlSpot(3, 3.8),
  FlSpot(4, 5.1),
  FlSpot(5, 4.4),
  FlSpot(6, 6.2),
];

enum OrderStatus { pending, active, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Pending',
        OrderStatus.active => 'Active',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        OrderStatus.pending => AdminColors.orange,
        OrderStatus.active => AdminColors.green,
        OrderStatus.delivered => AdminColors.darkGreen,
        OrderStatus.cancelled => AdminColors.red,
      };
}

class AdminOrder {
  const AdminOrder({
    required this.id,
    required this.customer,
    required this.agent,
    required this.amount,
    required this.items,
    required this.status,
  });

  final String id;
  final String customer;
  final String agent;
  final double amount;
  final int items;
  final OrderStatus status;
}

// TODO: GET /api/admin/orders
const List<AdminOrder> kDummyOrders = [
  AdminOrder(id: 'ORD-10482', customer: 'MedCare Pharmacy', agent: 'Rahul S.', amount: 4820, items: 12, status: OrderStatus.active),
  AdminOrder(id: 'ORD-10481', customer: 'City Hospital', agent: 'Unassigned', amount: 12990, items: 34, status: OrderStatus.pending),
  AdminOrder(id: 'ORD-10480', customer: 'Apollo Clinic', agent: 'Priya M.', amount: 2310, items: 6, status: OrderStatus.delivered),
  AdminOrder(id: 'ORD-10479', customer: 'Wellness Store', agent: 'Arjun K.', amount: 7650, items: 19, status: OrderStatus.active),
  AdminOrder(id: 'ORD-10478', customer: 'Sunrise Medicals', agent: 'Unassigned', amount: 980, items: 3, status: OrderStatus.cancelled),
  AdminOrder(id: 'ORD-10477', customer: 'Green Cross', agent: 'Neha T.', amount: 5430, items: 15, status: OrderStatus.delivered),
  AdminOrder(id: 'ORD-10476', customer: 'LifeLine Pharma', agent: 'Rahul S.', amount: 3120, items: 9, status: OrderStatus.pending),
];

class Medicine {
  const Medicine({
    required this.name,
    required this.brand,
    required this.price,
    required this.stock,
  });

  final String name;
  final String brand;
  final double price;
  final int stock;
}

// TODO: GET /api/admin/medicines
const List<Medicine> kDummyMedicines = [
  Medicine(name: 'Paracetamol 500mg', brand: 'Cipla', price: 28, stock: 420),
  Medicine(name: 'Amoxicillin 250mg', brand: 'Sun Pharma', price: 96, stock: 18),
  Medicine(name: 'Cetirizine 10mg', brand: 'Dr. Reddy’s', price: 35, stock: 0),
  Medicine(name: 'Azithromycin 500mg', brand: 'Mankind', price: 112, stock: 240),
  Medicine(name: 'Pantoprazole 40mg', brand: 'Alkem', price: 78, stock: 12),
  Medicine(name: 'Metformin 500mg', brand: 'USV', price: 44, stock: 530),
];

enum UserRole { customer, vendor, delivery, marketing }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.customer => 'Customer',
        UserRole.vendor => 'Vendor',
        UserRole.delivery => 'Delivery',
        UserRole.marketing => 'Marketing',
      };

  Color get color => switch (this) {
        UserRole.customer => const Color(0xFF3B82F6),
        UserRole.vendor => AppColors.primary,
        UserRole.delivery => AdminColors.orange,
        UserRole.marketing => const Color(0xFF8B5CF6),
      };
}

class AdminUser {
  const AdminUser({
    required this.name,
    required this.role,
    required this.joinDate,
    required this.active,
  });

  final String name;
  final UserRole role;
  final String joinDate;
  final bool active;
}

// TODO: GET /api/admin/users
const List<AdminUser> kDummyUsers = [
  AdminUser(name: 'Rahul Sharma', role: UserRole.customer, joinDate: '12 Jan 2024', active: true),
  AdminUser(name: 'MedCare Pharmacy', role: UserRole.vendor, joinDate: '03 Feb 2024', active: true),
  AdminUser(name: 'Priya Menon', role: UserRole.delivery, joinDate: '21 Mar 2024', active: false),
  AdminUser(name: 'Arjun Kapoor', role: UserRole.marketing, joinDate: '08 Apr 2024', active: true),
  AdminUser(name: 'City Hospital', role: UserRole.vendor, joinDate: '17 Apr 2024', active: true),
  AdminUser(name: 'Neha Tiwari', role: UserRole.delivery, joinDate: '02 May 2024', active: true),
  AdminUser(name: 'Sanjay Verma', role: UserRole.customer, joinDate: '29 May 2024', active: false),
];

// =============================================================================
// SHARED SMALL HELPERS
// =============================================================================

/// Groups an integer with thousands separators, e.g. 2841 -> "2,841".
String _grouped(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Two initials from a name, e.g. "MedCare Pharmacy" -> "MP".
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts.first[0] + parts[1][0]).toUpperCase();
}

const ScrollPhysics _bouncing = BouncingScrollPhysics();

// =============================================================================
// ROOT — Bottom navigation host
// =============================================================================

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // IndexedStack keeps each screen's state (scroll, tab, search) alive.
    final screens = [
      DashboardHomeScreen(onQuickNav: _goTo),
      const OrderManagementScreen(),
      const MedicineManagementScreen(),
      const UserManagementScreen(),
      const AdminSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.lightGreenBg,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.darkGreen
                  : AppColors.greyText,
            ),
          ),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: AppColors.darkGreen),
                label: 'Dashboard'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long, color: AppColors.darkGreen),
                label: 'Orders'),
            NavigationDestination(
                icon: Icon(Icons.medication_outlined),
                selectedIcon: Icon(Icons.medication, color: AppColors.darkGreen),
                label: 'Products'),
            NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people, color: AppColors.darkGreen),
                label: 'Users'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings, color: AppColors.darkGreen),
                label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SCREEN 1 — Dashboard Home
// =============================================================================

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key, required this.onQuickNav});

  /// Lets the quick-action grid jump to another bottom-nav tab.
  final ValueChanged<int> onQuickNav;

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  // TODO: GET /api/admin/dashboard  → load KPIs, chart and recent orders.
  final List<KpiData> _kpis = kDummyKpis;
  final List<AdminOrder> _recentOrders = kDummyOrders.take(5).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: _bouncing,
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateChip(),
                    const SizedBox(height: 16),
                    _buildKpiGrid(),
                    const SizedBox(height: 20),
                    const _SectionTitle('Revenue (Last 7 days)'),
                    const SizedBox(height: 12),
                    _buildRevenueChart(),
                    const SizedBox(height: 20),
                    const _SectionTitle('Recent Orders'),
                    const SizedBox(height: 12),
                    ..._recentOrders.map((o) => _CompactOrderTile(order: o)),
                    const SizedBox(height: 20),
                    const _SectionTitle('Quick Actions'),
                    const SizedBox(height: 12),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom app bar: avatar, title, notification bell with badge.
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.pageBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          const _AvatarCircle(text: 'AD', size: 40),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('Admin Panel',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText)),
              Text('Welcome back, Admin',
                  style: TextStyle(fontSize: 12, color: AppColors.greyText)),
            ],
          ),
          const Spacer(),
          _NotificationBell(
            count: 3,
            onTap: () => _snack(context, 'Notifications'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.darkGreen),
          SizedBox(width: 6),
          // TODO: GET /api/admin/dashboard → server date, or use DateTime.now().
          Text('Monday, 15 Jun 2024',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreen)),
        ],
      ),
    );
  }

  // 2x2 KPI grid.
  Widget _buildKpiGrid() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: _kpis.map((k) => _StatCard(data: k)).toList(),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 18, 16, 8),
      decoration: _cardDecoration(),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: kRevenueSpots,
              isCurved: true,
              barWidth: 3,
              color: AppColors.primary,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.35),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2x2 quick-action grid.
  Widget _buildQuickActions() {
    final actions = [
      (_QuickAction(icon: Icons.receipt_long, label: 'Manage Orders'), 1),
      (_QuickAction(icon: Icons.medication, label: 'Medicines'), 2),
      (_QuickAction(icon: Icons.storefront, label: 'Vendors'), 3),
      (_QuickAction(icon: Icons.bar_chart, label: 'Reports'), -1),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: actions.map((a) {
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => a.$2 >= 0
              ? widget.onQuickNav(a.$2)
              : _snack(context, 'Reports coming soon'),
          child: a.$1,
        );
      }).toList(),
    );
  }
}

// =============================================================================
// SCREEN 2 — Order Management
// =============================================================================

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  // TODO: GET /api/admin/orders
  final List<AdminOrder> _orders = kDummyOrders;
  String _query = '';

  static const _tabs = ['All', 'Pending', 'Active', 'Delivered', 'Cancelled'];

  List<AdminOrder> _filter(int tabIndex) {
    Iterable<AdminOrder> list = _orders;
    if (tabIndex > 0) {
      final status = OrderStatus.values[tabIndex - 1];
      list = list.where((o) => o.status == status);
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((o) =>
          o.id.toLowerCase().contains(q) ||
          o.customer.toLowerCase().contains(q));
    }
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _snack(context, 'Exporting orders…'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Export'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              const _ScreenHeader(title: 'Order Management'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SearchBar(
                  hint: 'Search by order ID or customer',
                  onChanged: (v) => setState(() => _query = v),
                  onFilter: () => _snack(context, 'Filters'),
                ),
              ),
              _PillTabBar(tabs: _tabs),
              Expanded(
                child: TabBarView(
                  physics: _bouncing,
                  children: List.generate(_tabs.length, (i) {
                    final list = _filter(i);
                    if (list.isEmpty) return const _EmptyState(label: 'No orders');
                    return ListView.builder(
                      physics: _bouncing,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: list.length,
                      itemBuilder: (_, idx) => _OrderCard(order: list[idx]),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SCREEN 3 — Medicine Management
// =============================================================================

class MedicineManagementScreen extends StatefulWidget {
  const MedicineManagementScreen({super.key});

  @override
  State<MedicineManagementScreen> createState() =>
      _MedicineManagementScreenState();
}

class _MedicineManagementScreenState extends State<MedicineManagementScreen> {
  // TODO: GET /api/admin/medicines
  final List<Medicine> _medicines = kDummyMedicines;
  String _query = '';

  List<Medicine> get _filtered {
    if (_query.isEmpty) return _medicines;
    final q = _query.toLowerCase();
    return _medicines
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            m.brand.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const _ScreenHeader(title: 'Medicines'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _SearchBar(
                      hint: 'Search medicines',
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // "Add Medicine" green button.
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _snack(context, 'Add Medicine'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const _EmptyState(label: 'No medicines found')
                  : ListView.builder(
                      physics: _bouncing,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _MedicineCard(
                        medicine: list[i],
                        onEdit: () => _snack(context, 'Edit ${list[i].name}'),
                        onDelete: () => _snack(context, 'Delete ${list[i].name}'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SCREEN 4 — User Management
// =============================================================================

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  // TODO: GET /api/admin/users
  final List<AdminUser> _users = List.of(kDummyUsers);

  static const _tabs = ['All Users', 'Customers', 'Vendors', 'Delivery', 'Marketing'];

  List<AdminUser> _filter(int tabIndex) {
    if (tabIndex == 0) return _users;
    final role = UserRole.values[tabIndex - 1];
    return _users.where((u) => u.role == role).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: SafeArea(
          child: Column(
            children: [
              const _ScreenHeader(title: 'User Management'),
              _PillTabBar(tabs: _tabs),
              Expanded(
                child: TabBarView(
                  physics: _bouncing,
                  children: List.generate(_tabs.length, (i) {
                    final list = _filter(i);
                    if (list.isEmpty) return const _EmptyState(label: 'No users');
                    return ListView.builder(
                      physics: _bouncing,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (_, idx) {
                        final user = list[idx];
                        return _UserCard(
                          user: user,
                          onToggle: (val) {
                            // Local-only toggle; persist via API later.
                            // TODO: PATCH /api/admin/users/:id { active }
                            final realIndex = _users.indexOf(user);
                            setState(() {
                              _users[realIndex] = AdminUser(
                                name: user.name,
                                role: user.role,
                                joinDate: user.joinDate,
                                active: val,
                              );
                            });
                          },
                        );
                      },
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SCREEN 5 — Admin Settings
// =============================================================================

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: ListView(
          physics: _bouncing,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _ScreenHeader(title: 'Settings'),
            // Profile section.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  const _AvatarCircle(text: 'AD', size: 56),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Admin User',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkText)),
                      SizedBox(height: 3),
                      _RoleBadge(label: 'Super Admin', color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SettingsGroup(title: 'Account', items: [
              _SettingsItem(icon: Icons.person_outline, label: 'Edit Profile'),
              _SettingsItem(icon: Icons.lock_outline, label: 'Change Password'),
            ]),
            _SettingsGroup(title: 'App Config', items: [
              _SettingsItem(icon: Icons.language_outlined, label: 'Language', trailingText: 'English'),
              _SettingsItem(icon: Icons.attach_money, label: 'Currency', trailingText: 'INR ₹'),
            ]),
            _SettingsGroup(title: 'Notifications', items: const [
              _SettingsItem(icon: Icons.notifications_outlined, label: 'Push Notifications', toggle: true, initialValue: true),
              _SettingsItem(icon: Icons.email_outlined, label: 'Email Alerts', toggle: true, initialValue: false),
            ]),
            _SettingsGroup(title: 'Security', items: const [
              _SettingsItem(icon: Icons.fingerprint, label: 'Biometric Login', toggle: true, initialValue: true),
              _SettingsItem(icon: Icons.shield_outlined, label: 'Two-Factor Auth'),
            ]),
            _SettingsGroup(title: 'Support', items: const [
              _SettingsItem(icon: Icons.help_outline, label: 'Help Center'),
              _SettingsItem(icon: Icons.info_outline, label: 'About MediCaPlus', trailingText: 'v1.0.0'),
            ]),
            const SizedBox(height: 12),

            // Logout (red outlined).
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.red,
                  side: const BorderSide(color: AdminColors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Logout',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// REUSABLE WIDGETS
// =============================================================================

BoxDecoration _cardDecoration() => BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.darkGreen,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1200),
    ));
}

/// Simple title used at the top of the non-home screens.
class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText)),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.darkText));
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.text, this.size = 40});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: AppColors.greenGradient,
        shape: BoxShape.circle,
      ),
      child: Text(text,
          style: TextStyle(
              color: AppColors.white,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w800)),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_outlined,
                size: 22, color: AppColors.darkText),
            if (count > 0)
              Positioned(
                right: -3,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: const BoxDecoration(
                    color: AdminColors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text('$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// KPI stat card: icon, animated count, optional % change badge.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, size: 20, color: data.color),
              ),
              const Spacer(),
              if (data.changePct != null) _ChangeBadge(pct: data.changePct!),
            ],
          ),
          _AnimatedCount(
            target: data.target,
            decimals: data.decimals,
            grouped: data.grouped,
            prefix: data.prefix,
            suffix: data.suffix,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText),
          ),
          Text(data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
        ],
      ),
    );
  }
}

/// Counts up from 0 to [target] once, then formats with prefix/suffix.
class _AnimatedCount extends StatelessWidget {
  const _AnimatedCount({
    required this.target,
    required this.style,
    this.decimals = 0,
    this.grouped = false,
    this.prefix = '',
    this.suffix = '',
  });

  final double target;
  final TextStyle style;
  final int decimals;
  final bool grouped;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) {
        final String body = decimals > 0
            ? value.toStringAsFixed(decimals)
            : (grouped ? _grouped(value.round()) : value.round().toString());
        return Text('$prefix$body$suffix',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
      },
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.pct});
  final double pct;

  @override
  Widget build(BuildContext context) {
    final up = pct >= 0;
    final color = up ? AppColors.darkGreen : AdminColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
              size: 11, color: color),
          const SizedBox(width: 2),
          Text('${pct.abs().toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Compact order row used on the dashboard "Recent Orders" list.
class _CompactOrderTile extends StatelessWidget {
  const _CompactOrderTile({required this.order});
  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.id,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
                const SizedBox(height: 2),
                Text(order.customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${_grouped(order.amount.round())}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText)),
              const SizedBox(height: 4),
              _StatusPill(label: order.status.label, color: order.status.color),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full order card used on the Order Management screen.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(order.id,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText)),
              const Spacer(),
              _StatusPill(label: order.status.label, color: order.status.color),
            ],
          ),
          const SizedBox(height: 10),
          _kv(Icons.person_outline, 'Customer', order.customer),
          const SizedBox(height: 6),
          _kv(Icons.delivery_dining_outlined, 'Agent', order.agent),
          const Divider(height: 22, color: AppColors.border),
          Row(
            children: [
              Text('${order.items} items',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.greyText)),
              const Spacer(),
              Text('₹${_grouped(order.amount.round())}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _snack(context, 'Open ${order.id}'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.lighterGreen,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('View →',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.greyText),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(fontSize: 12.5, color: AppColors.greyText)),
        Expanded(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText)),
        ),
      ],
    );
  }
}

/// Medicine list card: image placeholder, name/brand/price, stock, actions.
class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.medicine,
    required this.onEdit,
    required this.onDelete,
  });

  final Medicine medicine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Stock colour: out = red, low (<=20) = orange, otherwise green.
    final stock = medicine.stock;
    final (Color stockColor, String stockLabel) = stock == 0
        ? (AdminColors.red, 'Out of stock')
        : stock <= 20
            ? (AdminColors.orange, 'Low: $stock left')
            : (AdminColors.green, 'In stock: $stock');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          // Image placeholder.
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medication, color: AppColors.darkGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medicine.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
                const SizedBox(height: 2),
                Text(medicine.brand,
                    style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('₹${medicine.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkText)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: stockColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(stockLabel,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: stockColor)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Edit + delete icon buttons.
          Column(
            children: [
              _IconBtn(icon: Icons.edit_outlined, color: AppColors.darkGreen, onTap: onEdit),
              const SizedBox(height: 6),
              _IconBtn(icon: Icons.delete_outline, color: AdminColors.red, onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

/// User card: avatar initials, name, role badge, join date, status toggle.
class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onToggle});
  final AdminUser user;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _AvatarCircle(text: _initials(user.name), size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText)),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(label: user.role.label, color: user.role.color),
                  ],
                ),
                const SizedBox(height: 3),
                Text('Joined ${user.joinDate}',
                    style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
              ],
            ),
          ),
          Switch.adaptive(
            value: user.active,
            activeThumbColor: AppColors.primary,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.lightGreenBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.darkGreen, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
          ),
        ],
      ),
    );
  }
}

/// Search field with an optional filter button.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint, required this.onChanged, this.onFilter});
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppColors.greyText, size: 20),
              filled: true,
              fillColor: AppColors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
        if (onFilter != null) ...[
          const SizedBox(width: 10),
          InkWell(
            onTap: onFilter,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.tune, color: AppColors.white, size: 20),
            ),
          ),
        ],
      ],
    );
  }
}

/// A scrollable pill-style TabBar used by the Orders and Users screens.
class _PillTabBar extends StatelessWidget {
  const _PillTabBar({required this.tabs});
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 4),
      alignment: Alignment.centerLeft,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.greyText,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tabs: tabs
            .map((t) => Tab(
                  height: 34,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: Text(t),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.items});
  final String title;
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.greyText)),
        ),
        Container(
          decoration: _cardDecoration(),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i != items.length - 1)
                  const Divider(height: 1, indent: 52, color: AppColors.border),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// One settings row — icon + label, then either a toggle or a chevron/trailing.
class _SettingsItem extends StatefulWidget {
  const _SettingsItem({
    required this.icon,
    required this.label,
    this.trailingText,
    this.toggle = false,
    this.initialValue = false,
  });

  final IconData icon;
  final String label;
  final String? trailingText;
  final bool toggle;
  final bool initialValue;

  @override
  State<_SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<_SettingsItem> {
  late bool _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.toggle ? null : () => _snack(context, widget.label),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(widget.icon, size: 20, color: AppColors.darkGreen),
            const SizedBox(width: 14),
            Expanded(
              child: Text(widget.label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText)),
            ),
            if (widget.toggle)
              Switch.adaptive(
                value: _value,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _value = v),
              )
            else ...[
              if (widget.trailingText != null)
                Text(widget.trailingText!,
                    style: const TextStyle(fontSize: 13, color: AppColors.greyText)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.greyText),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 44, color: AppColors.greyText),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.greyText)),
        ],
      ),
    );
  }
}
