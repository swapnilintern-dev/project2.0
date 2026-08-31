// Pins the short-id contract. Five screens across three roles render ids
// through this, and the overflow bugs it fixes come back the moment it starts
// returning something long — so the length bound is the point of the test.

import 'package:flutter_test/flutter_test.dart';
import 'package:self/shared/short_id.dart';

void main() {
  test('renders the last six characters, uppercased', () {
    expect(shortId('6a7d57c7fd2912e52c42286e'), '42286E');
  });

  test('never exceeds six characters, whatever the backend sends', () {
    // The bound is what keeps the id beside a status pill instead of pushing
    // it off the row.
    for (final id in [
      '6a7d61bdec861601b02f6bf7',
      'a' * 64,
      '0123456789abcdef01234567',
    ]) {
      expect(shortId(id).length, 6);
    }
  });

  test('distinguishes ids that share a leading timestamp', () {
    // The real-world case: a Mongo ObjectId opens with a timestamp, so orders
    // placed in the same window share a prefix. Truncating from the front
    // would render these three identically — the tail is what tells them apart.
    final sameWindow = [
      '6a7d61bdec861601b02f6bf7',
      '6a7d5968fd2912e52c42ff83',
      '6a7d57c7fd2912e52c42286e',
    ].map(shortId).toSet();
    expect(sameWindow.length, 3);
  });

  test('returns short ids whole rather than padding or cropping', () {
    expect(shortId('abc'), 'ABC');
    expect(shortId('abcdef'), 'ABCDEF');
    expect(shortId(''), '');
  });
}
