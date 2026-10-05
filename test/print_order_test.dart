import 'package:campus360/models/enums/print_enums.dart';
import 'package:campus360/models/print_order.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 8, 13, 10, 0);

PrintOrder _order({
  required String id,
  DateTime? neededBy,
  DateTime? createdAt,
  PrintOrderStatus status = PrintOrderStatus.received,
  int orderNumber = 1,
}) =>
    PrintOrder(
      id: id,
      orderNumber: orderNumber,
      studentId: 'u1',
      studentName: 'Ragav',
      shopId: 'printshop-central',
      shopName: 'Central Print Shop',
      document: const PrintDocument(
        fileName: 'notes.pdf',
        storagePath: 'printDocs/u1/order/notes.pdf',
        downloadUrl: 'https://example.invalid/notes.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 100000,
        pageCount: 10,
      ),
      settings: const PrintSettings(),
      status: status,
      createdAt: createdAt ?? _now.subtract(const Duration(hours: 1)),
      neededBy: neededBy,
    );

void main() {
  group('queue ordering', () {
    test('sorts by deadline, soonest first — not by when it was placed', () {
      // The whole point of scheduling: a job placed later but needed sooner
      // must be printed first.
      final placedEarlyNeededLate = _order(
        id: 'early',
        createdAt: _now.subtract(const Duration(hours: 3)),
        neededBy: _now.add(const Duration(hours: 5)),
      );
      final placedLateNeededSoon = _order(
        id: 'late',
        createdAt: _now,
        neededBy: _now.add(const Duration(minutes: 20)),
      );

      final queue = [placedEarlyNeededLate, placedLateNeededSoon]
        ..sort((a, b) => a.queueSortKey.compareTo(b.queueSortKey));

      expect(queue.first.id, 'late');
    });

    test('orders with no deadline sort after every dated order', () {
      final noDeadline = _order(id: 'whenever', createdAt: _now.subtract(const Duration(days: 1)));
      final dated = _order(id: 'dated', neededBy: _now.add(const Duration(days: 30)));

      final queue = [noDeadline, dated]..sort((a, b) => a.queueSortKey.compareTo(b.queueSortKey));

      expect(queue.first.id, 'dated', reason: 'even a distant deadline beats no deadline');
    });

    test('among undated orders, the oldest goes first', () {
      final older = _order(id: 'older', createdAt: _now.subtract(const Duration(hours: 5)));
      final newer = _order(id: 'newer', createdAt: _now.subtract(const Duration(hours: 1)));

      final queue = [newer, older]..sort((a, b) => a.queueSortKey.compareTo(b.queueSortKey));

      expect(queue.first.id, 'older');
    });

    test('an overdue order sorts ahead of everything still in the future', () {
      final overdue = _order(id: 'overdue', neededBy: _now.subtract(const Duration(minutes: 30)));
      final soon = _order(id: 'soon', neededBy: _now.add(const Duration(minutes: 5)));

      final queue = [soon, overdue]..sort((a, b) => a.queueSortKey.compareTo(b.queueSortKey));

      expect(queue.first.id, 'overdue');
    });
  });

  group('deadline state', () {
    test('is overdue once the deadline passes and it is not ready', () {
      final order = _order(id: 'a', neededBy: _now.subtract(const Duration(minutes: 1)));
      expect(order.isOverdue(_now), isTrue);
    });

    test('is not overdue once it is ready or collected', () {
      final past = _now.subtract(const Duration(hours: 1));
      expect(
        _order(id: 'a', neededBy: past, status: PrintOrderStatus.readyForPickup).isOverdue(_now),
        isFalse,
        reason: 'the student can collect it; the shop has done its part',
      );
      expect(
        _order(id: 'b', neededBy: past, status: PrintOrderStatus.collected).isOverdue(_now),
        isFalse,
      );
    });

    test('is urgent within half an hour but not once overdue', () {
      expect(_order(id: 'a', neededBy: _now.add(const Duration(minutes: 20))).isUrgent(_now), isTrue);
      expect(_order(id: 'b', neededBy: _now.add(const Duration(hours: 2))).isUrgent(_now), isFalse);
      expect(_order(id: 'c', neededBy: _now.subtract(const Duration(minutes: 5))).isUrgent(_now), isFalse);
    });

    test('an order with no deadline is neither urgent nor overdue', () {
      final order = _order(id: 'a');
      expect(order.isOverdue(_now), isFalse);
      expect(order.isUrgent(_now), isFalse);
      expect(order.remainingTime(_now), isNull);
    });
  });

  group('status', () {
    test('active statuses are the ones still moving through the shop', () {
      expect(PrintOrderStatus.printing.isActive, isTrue);
      expect(PrintOrderStatus.readyForPickup.isActive, isTrue);
      expect(PrintOrderStatus.collected.isActive, isFalse);
      expect(PrintOrderStatus.rejected.isActive, isFalse);
      expect(PrintOrderStatus.cancelled.isActive, isFalse);
    });

    test('a student can cancel only before paper is committed', () {
      expect(PrintOrderStatus.received.isCancellableByStudent, isTrue);
      expect(PrintOrderStatus.accepted.isCancellableByStudent, isTrue);
      expect(PrintOrderStatus.printing.isCancellableByStudent, isFalse,
          reason: 'the shop has already spent paper and ink');
      expect(PrintOrderStatus.readyForPickup.isCancellableByStudent, isFalse);
    });
  });

  group('settings', () {
    test('summarises itself for review screens', () {
      const settings = PrintSettings(copies: 2, colour: PrintColour.colour, sides: PrintSides.double);
      expect(settings.summary, contains('2 copies'));
      expect(settings.summary, contains('Colour'));
      expect(settings.summary, contains('2-sided'));
    });

    test('says "1 copy", not "1 copies"', () {
      expect(const PrintSettings().summary, contains('1 copy'));
    });

    test('a blank page range counts as all pages', () {
      expect(const PrintSettings(pageRange: '   ').isAllPages, isTrue);
      expect(const PrintSettings(pageRange: '2-7').isAllPages, isFalse);
    });
  });

  group('estimateCost', () {
    test('multiplies pages by copies by rate', () {
      final cost = estimateCost(
        settings: const PrintSettings(copies: 2),
        pageCount: 10,
        bwPerPage: 1.0,
        colourPerPage: 5.0,
      );
      expect(cost, 20.0);
    });

    test('uses the colour rate for colour jobs', () {
      final cost = estimateCost(
        settings: const PrintSettings(colour: PrintColour.colour),
        pageCount: 4,
        bwPerPage: 1.0,
        colourPerPage: 5.0,
      );
      expect(cost, 20.0);
    });

    test('returns null rather than guessing when the page count is unknown', () {
      // An unreadable PDF must not produce a confident price.
      expect(
        estimateCost(settings: const PrintSettings(), pageCount: null, bwPerPage: 1, colourPerPage: 5),
        isNull,
      );
    });

    test('returns null when the shop has published no prices', () {
      expect(
        estimateCost(settings: const PrintSettings(), pageCount: 10, bwPerPage: null, colourPerPage: null),
        isNull,
      );
    });
  });
}
