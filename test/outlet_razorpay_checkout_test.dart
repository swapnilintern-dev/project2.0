// Pins the guards OutletRazorpayCheckout applies BEFORE the Razorpay sheet is
// opened — the paths a phone can't be in the loop for:
//
//   • an order with no id is never sent to /outlet/orders/:id/razorpay,
//   • the server's own refusal ("This order is already paid") reaches the user
//     verbatim instead of a generic line,
//   • an unusable payment session (missing key / order id / amount) is refused
//     rather than opened,
//   • a second tap while an attempt is in flight is refused (no double charge).
//
// The sheet itself is a native plugin, so anything past the guards belongs to an
// integration run on a device.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:self/outlet/outlet_enums.dart';
import 'package:self/outlet/outlet_live_datasource.dart' show OutletApiException;
import 'package:self/outlet/outlet_models.dart';
import 'package:self/outlet/outlet_razorpay_checkout.dart';
import 'package:self/outlet/outlet_repository.dart';

OutletOrder _order({String id = 'ord1'}) => OutletOrder(
      id: id,
      type: OutletOrderType.counter,
      status: OutletOrderStatus.awaitingPayment,
      paymentMethod: OutletPaymentMethod.qr,
      lines: const [
        OutletOrderLine(name: 'Paracetamol 500', packSize: '10 tabs', qty: 2, price: 25),
      ],
      customer: const OutletCustomerInfo(name: 'Mandal Clinic', phone: '6201234562'),
      total: 50,
      createdAt: DateTime(2026, 8, 3),
    );

void main() {
  test('an order with no id never reaches the server', () async {
    final ds = _FakeDataSource();
    final checkout =
        OutletRazorpayCheckout(repository: OutletRepository(dataSource: ds));

    final result = await checkout.collect(_order(id: ''));

    expect(result.outcome, OutletCheckoutOutcome.failed);
    expect(result.isPaid, isFalse);
    expect(ds.createCalls, 0);
  });

  test("the server's own refusal is what the user sees", () async {
    final ds = _FakeDataSource(
      onCreate: () => throw const OutletApiException('This order is already paid'),
    );
    final checkout =
        OutletRazorpayCheckout(repository: OutletRepository(dataSource: ds));

    final result = await checkout.collect(_order());

    expect(result.outcome, OutletCheckoutOutcome.failed);
    expect(result.message, 'This order is already paid');
  });

  test('an unusable payment session is refused, not opened', () async {
    final ds = _FakeDataSource(
      // No publishable key → the sheet could never verify against the order.
      session: const OutletOnlinePayment(
        razorpayOrderId: 'order_live_1',
        amount: 5000,
        currency: 'INR',
        keyId: '',
      ),
    );
    final checkout =
        OutletRazorpayCheckout(repository: OutletRepository(dataSource: ds));

    final result = await checkout.collect(_order());

    expect(result.outcome, OutletCheckoutOutcome.failed);
    expect(result.canRetry, isTrue);
    expect(ds.createCalls, 1);
  });

  test('a second tap while an attempt is in flight is refused', () async {
    final gate = Completer<void>();
    final ds = _FakeDataSource(hold: gate.future);
    final checkout =
        OutletRazorpayCheckout(repository: OutletRepository(dataSource: ds));

    final first = checkout.collect(_order());
    await Future<void>.delayed(Duration.zero);
    expect(checkout.isBusy, isTrue);

    final second = await checkout.collect(_order());
    expect(second.outcome, OutletCheckoutOutcome.failed);
    expect(second.message, 'A payment is already in progress.');

    gate.complete();
    final result = await first;
    expect(ds.createCalls, 1, reason: 'only the first tap creates a payment');
    expect(checkout.isBusy, isFalse);

    // The sheet can't open in a test binding, which also pins the no-hang rule:
    // razorpay_flutter reports such a failure as an UNCAUGHT async error and
    // emits no event, so without the guarded zone this future never completes.
    expect(result.outcome, OutletCheckoutOutcome.failed);
    expect(result.message, startsWith('Could not open Razorpay'));
  });
}

/// Stands in for the whole datasource; only the payment calls are exercised.
class _FakeDataSource implements OutletDataSource {
  _FakeDataSource({this.session, this.onCreate, this.hold});

  final OutletOnlinePayment? session;
  final OutletOnlinePayment Function()? onCreate;

  /// Lets a test keep the create call in flight to probe the busy guard.
  final Future<void>? hold;

  int createCalls = 0;

  @override
  Future<OutletOnlinePayment> createRazorpayOrder(String orderId) async {
    createCalls++;
    if (hold != null) await hold;
    if (onCreate != null) return onCreate!();
    return session ??
        const OutletOnlinePayment(
          razorpayOrderId: 'order_live_1',
          amount: 5000,
          currency: 'INR',
          keyId: 'rzp_live_key',
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}
