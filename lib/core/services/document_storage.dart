import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../errors/app_failure.dart';

/// Where print documents live.
///
/// Not Firebase Storage: that requires the Blaze plan, which this project does
/// not have. Supabase Storage gives an equivalent bucket on its free tier, so
/// the print module works without billing. Everything else — auth, the order
/// documents, the queue — is still Firebase.
///
/// ## What is and isn't protected
///
/// The bucket is public-read and the app carries the `anon` key, because with
/// no server there is nowhere else to put a credential. Privacy therefore rests
/// on the object path being unguessable, not on an access check: each document
/// gets a 128-bit random segment. Two things make that hold up in practice —
/// the anon key can only *insert* (no update, no delete), and listing the
/// bucket returns nothing, so filenames cannot be enumerated. Both are enforced
/// by the Supabase policy, and both are verified in SETUP.md.
///
/// This is the same shape as the Firebase design it replaces: `getDownloadURL()`
/// also returns a public, token-bearing URL that bypasses security rules.
class DocumentStorage {
  DocumentStorage({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const projectUrl = 'https://hbiydchrsbhekqwzcwcs.supabase.co';
  static const bucket = 'print-docs';

  /// Publishable key. Safe to ship — it is in every copy of the APK already,
  /// and the storage policy is what actually constrains it.
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhiaXlkY2hyc2JoZWtxd3pjd2NzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2MjczNzIsImV4cCI6MjEwMjIwMzM3Mn0.JsI5vcSYuOeqjnzPKMSSoffTDWkK4GqmGrnwQFZUJR8';

  static const maxBytes = 20 * 1024 * 1024;

  static final _rng = Random.secure();

  /// A path no one can guess: `printDocs/<uid>/<orderId>/<random>/<file>`.
  ///
  /// The random segment is the privacy boundary, so it uses [Random.secure] —
  /// a predictable PRNG here would make every document enumerable.
  ///
  /// [prefix] separates print documents from Lost & Found photos. Both live in
  /// the one bucket because the Supabase policy grants insert per *bucket*, and
  /// a second bucket would need a second policy for no real gain.
  static String pathFor(
    String uid,
    String orderId,
    String fileName, {
    String prefix = 'printDocs',
  }) {
    final token = List.generate(16, (_) => _rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '$prefix/$uid/$orderId/$token/${_safeName(fileName)}';
  }

  /// Strips anything that would change the meaning of the path. A file called
  /// `../../secret.pdf` must not be able to climb out of its folder.
  static String _safeName(String fileName) {
    var cleaned = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    // A run of dots is the traversal idiom, and a leading dot makes a hidden
    // file; neither is anything a student meant to type.
    cleaned = cleaned.replaceAll(RegExp(r'\.{2,}'), '.').replaceAll(RegExp(r'^[._-]+'), '');
    // "???" sanitises to "___" — non-empty, but it names nothing, so fall back
    // rather than storing a file called three underscores.
    return RegExp(r'[A-Za-z0-9]').hasMatch(cleaned) ? cleaned : 'document';
  }

  String publicUrlFor(String path) => '$projectUrl/storage/v1/object/public/$bucket/$path';

  /// Uploads [file] and returns its public URL.
  ///
  /// Reports progress because a print document on campus Wi-Fi can take a
  /// while, and a frozen button reads as a broken app.
  Future<String> upload({
    required File file,
    required String path,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final length = await file.length();
    if (length > maxBytes) {
      throw const AppFailure(
        kind: FailureKind.upload,
        message: 'That file is larger than 20 MB. Try a smaller PDF.',
        isRetryable: false,
      );
    }

    final uri = Uri.parse('$projectUrl/storage/v1/object/$bucket/$path');
    final request = http.StreamedRequest('POST', uri)
      ..headers.addAll({
        'apikey': anonKey,
        'authorization': 'Bearer $anonKey',
        'content-type': mimeType,
        'x-upsert': 'false',
      })
      ..contentLength = length;

    var sent = 0;
    file.openRead().listen(
      (chunk) {
        sent += chunk.length;
        request.sink.add(chunk);
        onProgress?.call((sent / length).clamp(0.0, 1.0));
      },
      onDone: request.sink.close,
      onError: (Object e, StackTrace s) => request.sink.addError(e, s),
      cancelOnError: true,
    );

    final http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } on SocketException {
      throw AppFailure.offline;
    } on http.ClientException catch (e) {
      throw AppFailure(
        kind: FailureKind.upload,
        message: "The document couldn't be uploaded. Check your connection and try again.",
        debug: e.message,
      );
    }

    final body = await response.stream.bytesToString();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return publicUrlFor(path);
    }

    // 4xx here is a misconfiguration (policy, bucket, key) rather than anything
    // the student did, so say so plainly instead of blaming their file.
    throw AppFailure(
      kind: FailureKind.upload,
      message: response.statusCode == 403 || response.statusCode == 400
          ? 'The print service is not accepting uploads right now. Tell the campus office.'
          : "The document couldn't be uploaded. Please try again.",
      debug: 'HTTP ${response.statusCode}: $body',
    );
  }
}
