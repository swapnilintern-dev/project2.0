// The cart must total what the server charges. The server prices each line as
// regular price − the buyer tier's % (server/utils/buyerPricing.js); these
// cases mirror the assertions run against that helper.

import 'package:flutter_test/flutter_test.dart';

import 'package:self/customer/customer_models.dart';
import 'package:self/services/buyer_pricing.dart';

void main() {
  const product = Product(
    id: 'p',
    title: 'Mycofit 500 Tablet',
    brand: 'Intas',
    description: '',
    price: 360,
    category: 'medicine',
    doctorDiscountPercent: 4,
    wholesellerDiscountPercent: 5,
  );

  tearDown(BuyerPricing.instance.reset);

  test('tier rules match the server', () {
    BuyerPricingTier t(String v, String s) =>
        BuyerPricing.tierFrom(vendorType: v, shopType: s);
    expect(t('Shop / Pharmacy', 'Wholesale Pharmacy'), BuyerPricingTier.wholeseller);
    expect(t('shop11', 'wholeseller'), BuyerPricingTier.wholeseller);
    expect(t('Shop / Pharmacy', 'Retail Pharmacy'), BuyerPricingTier.retail);
    expect(t('Hospital / Clinic', 'Retail Pharmacy'), BuyerPricingTier.doctor);
  });

  test('wholesaler: cart line and placed order use the discounted price', () {
    BuyerPricing.instance.set(BuyerPricingTier.wholeseller);
    const line = CartItem(product: product, quantity: 3);
    expect(line.unitPrice, 342); // 360 − 5%
    expect(line.lineTotal, 1026);
    expect(OrderItem.fromCartItem(line).price, 342);
  });

  test('doctor gets drDisPercent; retail pays the regular price', () {
    BuyerPricing.instance.set(BuyerPricingTier.doctor);
    expect(const CartItem(product: product, quantity: 1).unitPrice, 345.6);
    BuyerPricing.instance.set(BuyerPricingTier.retail);
    expect(const CartItem(product: product, quantity: 2).lineTotal, 720);
  });

  test('rounded to paise exactly like the server', () {
    const p = Product(
      id: 'q',
      title: 't',
      brand: '',
      description: '',
      price: 99.99,
      category: 'medicine',
      wholesellerDiscountPercent: 5,
    );
    expect(p.priceFor(BuyerPricingTier.wholeseller), 94.99);
  });
}
