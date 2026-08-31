import 'package:flutter_test/flutter_test.dart';
import 'package:self/customer/customer_models.dart';
import 'package:self/customer/invoice_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('InvoicePdf.build produces a valid PDF from an order', () async {
    final order = Order(
      id: '665f1a2b3c4d5e6f7a8b9c0d',
      placedAt: DateTime(2026, 7, 4, 14, 30),
      status: OrderStatus.placed,
      items: const [
        OrderItem(title: 'razorpay', brand: '', price: 900, quantity: 1),
        OrderItem(title: 'TRIAL', brand: '', price: 100, quantity: 1),
      ],
      address: const Address(
        id: '',
        label: 'Delivery',
        fullName: '',
        phone: '8965475359',
        line1: 'ranchi',
        city: 'rnc',
        state: 'JH',
        pincode: '833102',
      ),
      paymentMethod: PaymentMethod.cod,
      subtotal: 1000,
      deliveryFee: 0,
      gst: 0,
      discount: 0,
    );

    final bytes = await InvoicePdf.build(order);

    // Real, non-trivial PDF with the correct magic header.
    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(InvoicePdf.invoiceNo(order.id), 'INV-7A8B9C0D');
  });
}
