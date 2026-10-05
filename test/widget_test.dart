import 'package:campus360/core/errors/app_failure.dart';
import 'package:campus360/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

// Widget tests that render the app need Firebase initialised, so those arrive
// in Phase 5 with a fake-Firebase harness. These cover the pure logic that
// already ships and has real branching.

void main() {
  group('Validators.email', () {
    test('rejects malformed addresses', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('missing@tld'), isNotNull);
      expect(Validators.email('ok@college.edu'), isNull);
    });

    test('enforces allowed domains, including subdomains', () {
      const allowed = ['college.edu'];
      expect(Validators.email('me@college.edu', allowedDomains: allowed), isNull);
      expect(Validators.email('me@cs.college.edu', allowedDomains: allowed), isNull);
      expect(Validators.email('me@gmail.com', allowedDomains: allowed), isNotNull);
    });

    test('accepts any domain when none are configured', () {
      expect(Validators.email('me@gmail.com'), isNull);
    });

    group('kpriet.ac.in lock', () {
      const allowed = ['kpriet.ac.in'];

      test('accepts college addresses', () {
        expect(Validators.email('24cs157@kpriet.ac.in', allowedDomains: allowed), isNull);
        expect(Validators.email('kpriet@kpriet.ac.in', allowedDomains: allowed), isNull);
      });

      test('accepts departmental subdomains', () {
        expect(Validators.email('me@cs.kpriet.ac.in', allowedDomains: allowed), isNull);
      });

      test('rejects outside addresses', () {
        expect(Validators.email('me@gmail.com', allowedDomains: allowed), isNotNull);
        expect(Validators.email('me@kpriet.com', allowedDomains: allowed), isNotNull);
      });

      test('rejects lookalike domains that merely contain the college domain', () {
        // The dangerous case: a naive `endsWith` or `contains` check would let
        // these through and hand an outsider a college account.
        expect(Validators.email('me@kpriet.ac.in.evil.com', allowedDomains: allowed), isNotNull);
        expect(Validators.email('me@notkpriet.ac.in', allowedDomains: allowed), isNotNull);
        expect(Validators.email('me@xkpriet.ac.in', allowedDomains: allowed), isNotNull);
      });

      test('is case-insensitive, as email domains are', () {
        expect(Validators.email('Me@KPRIET.AC.IN', allowedDomains: allowed), isNull);
      });

      test('names the required domain so the user knows what to do', () {
        final message = Validators.email('me@gmail.com', allowedDomains: allowed);
        expect(message, contains('kpriet.ac.in'));
      });
    });
  });

  group('Validators.password', () {
    test('requires length plus a letter and a digit', () {
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('alphabetsonly'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('campus360'), isNull);
    });
  });

  group('Validators.pageRange', () {
    test('accepts single pages, ranges and lists', () {
      expect(Validators.pageRange('3'), isNull);
      expect(Validators.pageRange('2-7'), isNull);
      expect(Validators.pageRange('1,3,5-9'), isNull);
    });

    test('rejects reversed, zero and out-of-bounds ranges', () {
      expect(Validators.pageRange('7-2'), isNotNull);
      expect(Validators.pageRange('0-3'), isNotNull);
      expect(Validators.pageRange('1-99', maxPage: 12), isNotNull);
      expect(Validators.pageRange('abc'), isNotNull);
    });
  });

  group('Validators.otp', () {
    test('requires exactly six digits', () {
      expect(Validators.otp('482731'), isNull);
      expect(Validators.otp('48273'), isNotNull);
      expect(Validators.otp('4827311'), isNotNull);
      expect(Validators.otp('48a731'), isNotNull);
    });
  });

  group('AppFailure', () {
    test('non-retryable failures are marked so the UI hides "Try again"', () {
      expect(AppFailure.permission.isRetryable, isFalse);
      expect(AppFailure.notFound.isRetryable, isFalse);
      expect(AppFailure.offline.isRetryable, isTrue);
    });
  });
}
