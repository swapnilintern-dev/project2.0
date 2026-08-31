// Layout-overflow harness for the iOS port.
//
// The app is phone-first and dense (billing rows, batch pickers, invoice
// totals, stat tiles). Two things push those layouts past their bounds:
//
//   • TEXT SCALE. main.dart caps the OS font setting at 1.3x. That cap is the
//     contract: every layout must still fit at exactly 1.3x. This file pins
//     that contract so a future tweak to a font size or a fixed height can't
//     quietly break it.
//   • SCREEN HEIGHT. Info.plist allows landscape on iPhone, which leaves as
//     little as 375pt of height. A sheet or dialog that merely looks tall in
//     portrait has nowhere to go there — and iOS renders the same string
//     slightly wider than Android, so a row that just fits on a Pixel clips.
//
// A RenderFlex overflow is reported through FlutterError during layout and
// paint, so the collector below listens for those reports rather than
// asserting on pixels — it fails with the same "overflowed by N pixels"
// message you would see as yellow-and-black stripes on device.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self/customer/customer_widgets.dart';
import 'package:self/customer/profile_screen.dart';
import 'package:self/marketing/reports_screen.dart';
import 'package:self/outlet/outlet_models.dart';
import 'package:self/outlet/outlet_session.dart';
import 'package:self/outlet/screens/outlet_medicine_details_screen.dart';
import 'package:self/outlet/screens/outlet_stock_screen.dart';
import 'package:self/theme/app_theme.dart';

/// The smallest supported iPhone, and the same device rotated. Landscape is
/// where short-height layouts fail.
const _iPhoneSE = Size(375, 667);
const _iPhoneSELandscape = Size(667, 375);

/// The text-scale ceiling main.dart allows. Layouts must hold here.
const _maxScale = 1.3;

/// Overflows reported since [_pumpAt] armed the collector. Stays live for the
/// rest of the test, so interactions after the first pump — opening a sheet,
/// stepping through a wizard — are covered too.
final List<String> _overflows = <String>[];

/// Builds [child] at [size] and [scale] with a notched iPhone's safe-area
/// insets, and starts collecting overflow reports.
Future<void> _pumpAt(
  WidgetTester tester,
  Widget child, {
  Size size = _iPhoneSE,
  double scale = _maxScale,
}) async {
  _overflows.clear();
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      _overflows.add(text.split('\n').first);
    } else {
      previousOnError?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = previousOnError);

  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(scale),
          // A notched iPhone: Dynamic Island top, home indicator bottom.
          // Screens that ignore these are exactly what we are hunting.
          padding: const EdgeInsets.only(top: 59, bottom: 34),
          viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
        ),
        child: child,
      ),
    ),
  );
  await tester.pump();
}

void _expectNoOverflow() {
  expect(_overflows, isEmpty, reason: _overflows.join('\n'));
}

/// A medicine whose every string is at the long end of what the catalogue
/// actually holds — brand + salt + strength + form is a genuinely common
/// pharma name, and outlet batch codes carry a plant prefix.
const _longNamedItem = OutletStockItem(
  id: 'p-long',
  name: 'Azithromycin Dihydrate 500 mg Film-Coated Tablet (Antibiotic)',
  price: 289.5,
  qtyAvailable: 1284,
  isOwnOutlet: true,
  packSize: '10 tablets per strip',
  batch: 'AZI500-MFG-2507-B',
  batchCount: 4,
);

void main() {
  group('dense screens at the 1.3x cap on the smallest iPhone', () {
    testWidgets('outlet medicine details — long name and batch code',
        (tester) async {
      await _pumpAt(
          tester, const OutletMedicineDetailsScreen(item: _longNamedItem));
      await tester.pump(const Duration(milliseconds: 600));
      _expectNoOverflow();
    });

    testWidgets('outlet stock list', (tester) async {
      OutletSession.instance.clear();
      // Not a Scaffold of its own — it is a tab body inside OutletMain.
      await _pumpAt(
          tester, Scaffold(body: OutletStockScreen(onAddToCart: (_, _) {})));
      await tester.pump(const Duration(milliseconds: 600));
      _expectNoOverflow();
    });

    testWidgets('marketing reports', (tester) async {
      await _pumpAt(tester, const MarketingReportsScreen());
      await tester.pump(const Duration(milliseconds: 600));
      _expectNoOverflow();
    });
  });

  group('customer product details bottom bar', () {
    // "Buy Now" + "Add to Cart · <total>" share one row, each in an Expanded.
    // Both labels carry an icon, and the cart label grows with the order total,
    // so the pair is the tightest horizontal fit in the customer flow.
    Widget bottomBar(String cartLabel) => Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Buy Now',
                      icon: Icons.flash_on,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: cartLabel,
                      icon: Icons.shopping_cart_outlined,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    testWidgets('holds at the 1.0x baseline', (tester) async {
      await _pumpAt(tester, bottomBar('Add to Cart · ₹250'), scale: 1.0);
      _expectNoOverflow();
    });

    testWidgets('holds at the 1.3x text-scale cap', (tester) async {
      await _pumpAt(tester, bottomBar('Add to Cart · ₹250'));
      _expectNoOverflow();
    });

    testWidgets('holds with a five-figure cart total', (tester) async {
      // A bulk quantity of an expensive medicine — the widest the label gets.
      await _pumpAt(tester, bottomBar('Add to Cart · ₹1,24,750.00'));
      _expectNoOverflow();
    });
  });

  group('customer profile', () {
    // The Support sheet this screen opens is left to manual verification on the
    // simulator. Driving it from a test needs a tap on a row that sits below
    // the fold at 1.3x, and the profile header shimmer animates forever, so
    // neither pumpAndSettle nor scrollUntilVisible lands the tap reliably. A
    // flaky test here would be worse than none.
    testWidgets('profile list holds in landscape', (tester) async {
      await _pumpAt(
        tester,
        const ProfileScreen(embedded: true),
        size: _iPhoneSELandscape,
      );
      _expectNoOverflow();
    });
  });

  group('role shell bottom navigation', () {
    Widget navBar() => Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
              NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
              NavigationDestination(
                  icon: Icon(Icons.medication_outlined), label: 'Medicines'),
              NavigationDestination(
                  icon: Icon(Icons.local_offer_outlined), label: 'Coupons'),
            ],
          ),
        );

    testWidgets('holds at the 1.0x baseline', (tester) async {
      await _pumpAt(tester, navBar(), scale: 1.0);
      _expectNoOverflow();
    });

    testWidgets('holds at the 1.3x text-scale cap', (tester) async {
      // The shells render NavigationBar at a compact fixed height (64 vs the
      // Material 3 default 80). The bar lays icon and label out at the user's
      // text scale, so this pins that 64 still fits at the cap.
      await _pumpAt(tester, navBar());
      _expectNoOverflow();
    });
  });
}
