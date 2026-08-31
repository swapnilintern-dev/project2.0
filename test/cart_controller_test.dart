// CartController smoke test — the server-backed cart must keep working
// perfectly OFFLINE (flutter_test's HttpClient answers 400 to everything):
// local mutations stay instant and correct, the mirror queue settles without
// errors, and hydrateFromServer never wipes local items on failure.
import 'package:flutter_test/flutter_test.dart';

import 'package:self/customer/customer_controllers.dart';
import 'package:self/customer/customer_models.dart';

Product _product(String id, {double price = 10}) => Product(
      id: id,
      title: 'Med $id',
      brand: 'Brand',
      description: '',
      price: price,
      category: 'medicine',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cart mutations mirror safely and hydrate never clobbers local items',
      () async {
    final cart = CartController.instance;
    cart.clear();

    // add / merge
    cart.add(_product('a'), quantity: 2);
    cart.add(_product('a'));
    cart.add(_product('b'));
    expect(cart.quantityOf('a'), 3);
    expect(cart.quantityOf('b'), 1);

    // increment / decrement / remove
    cart.increment('b');
    cart.decrement('a');
    cart.remove('b');
    expect(cart.quantityOf('a'), 2);
    expect(cart.quantityOf('b'), 0);

    // decrement to zero removes the line
    cart.decrement('a');
    cart.decrement('a');
    expect(cart.isEmpty, isTrue);

    // hydrate with unreachable server: must not throw, must not add items
    cart.add(_product('c'));
    await cart.hydrateFromServer();
    expect(cart.quantityOf('c'), 1, reason: 'failed hydrate must keep local');

    // every queued mirror call settles without throwing; with the server
    // unreachable the verified sync must report FAILURE (checkout aborts
    // instead of placing an order from an unknown server cart)
    expect(await cart.pushToServer(), isFalse);

    cart.clear();
    expect(cart.isEmpty, isTrue);
  });
}
