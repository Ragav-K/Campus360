import 'package:campus360/features/campus_pulse/providers/pulse_providers.dart';
import 'package:campus360/models/enums/pulse_enums.dart';
import 'package:campus360/models/pulse_update.dart';
import 'package:flutter_test/flutter_test.dart';

PulseUpdate update(String id, {String? locationName}) => PulseUpdate(
      id: id,
      title: 'Update $id',
      description: 'Description',
      category: PulseCategory.event,
      status: PulseStatus.information,
      createdAt: DateTime(2026),
      locationName: locationName,
    );

void main() {
  group('selectHomePulseHighlights', () {
    test('includes campus-wide dashboard alerts without a location', () {
      final campusWide = update('campus-wide');
      final located = update('located', locationName: 'Central Library');

      expect(selectHomePulseHighlights([campusWide, located]),
          [campusWide, located]);
    });

    test('preserves repository order and limits the deck to six cards', () {
      final updates = List.generate(8, (index) => update('$index'));

      expect(selectHomePulseHighlights(updates), updates.take(6));
    });
  });
}
