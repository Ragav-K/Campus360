import 'package:campus360/core/services/document_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentStorage.pathFor', () {
    test('places the document under the owner and order', () {
      final path = DocumentStorage.pathFor('uid123', 'order456', 'notes.pdf');
      expect(path, startsWith('printDocs/uid123/order456/'));
      expect(path, endsWith('/notes.pdf'));
    });

    test('is unguessable — the same inputs never repeat a path', () {
      // The random segment is the whole privacy boundary here, so a collision
      // or a deterministic path would expose one student's work to another.
      final paths = List.generate(
        500,
        (_) => DocumentStorage.pathFor('uid', 'order', 'a.pdf'),
      ).toSet();
      expect(paths.length, 500);
    });

    test('uses a 128-bit random segment', () {
      final segment = DocumentStorage.pathFor('u', 'o', 'a.pdf').split('/')[3];
      expect(segment.length, 32); // 16 bytes, hex encoded
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(segment), isTrue);
    });

    test('a traversing filename cannot climb out of its folder', () {
      final path = DocumentStorage.pathFor('uid', 'order', '../../etc/passwd');
      expect(path, isNot(contains('..')));
      expect(path.split('/').length, 5);
    });

    test('strips characters that would break the URL', () {
      final path = DocumentStorage.pathFor('uid', 'order', 'my notes #1 (final).pdf');
      final name = path.split('/').last;
      expect(name, 'my_notes__1__final_.pdf');
    });

    test('an unnamed file still gets a name', () {
      expect(DocumentStorage.pathFor('u', 'o', '???').split('/').last, 'document');
    });
  });

  group('publicUrlFor', () {
    test('builds the public object URL for a path', () {
      final storage = DocumentStorage();
      expect(
        storage.publicUrlFor('printDocs/u/o/abc/notes.pdf'),
        '${DocumentStorage.projectUrl}/storage/v1/object/public/'
        '${DocumentStorage.bucket}/printDocs/u/o/abc/notes.pdf',
      );
    });
  });
}
