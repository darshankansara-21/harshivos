import 'package:flutter_test/flutter_test.dart';

import 'package:harshivos/features/experiences/experience_catalog.dart';

void main() {
  test('experience catalog is transparent and scalable', () {
    final rows = ExperienceCatalog.build();
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(row.current, greaterThan(0));
      expect(row.capacity, greaterThanOrEqualTo(row.current));
      expect(row.notes.trim(), isNotEmpty);
    }
    expect(ExperienceCatalog.projectedCapacity, greaterThanOrEqualTo(96));
  });
}
