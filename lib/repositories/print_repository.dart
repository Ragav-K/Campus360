import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_config.dart';
import '../core/constants/firestore_paths.dart';
import '../core/errors/app_failure.dart';
import '../core/errors/failure_mapper.dart';
import '../core/services/document_storage.dart';
import '../models/enums/print_enums.dart';
import '../models/print_order.dart';
import '../models/print_shop.dart';

/// Print shops and print orders.
class PrintRepository {
  PrintRepository(this._db, {DocumentStorage? documents})
      : _documents = documents ?? DocumentStorage();

  final FirebaseFirestore _db;
  final DocumentStorage _documents;

  CollectionReference<Map<String, dynamic>> get _orders => _db.collection(Paths.printOrders);
  CollectionReference<Map<String, dynamic>> get _shops => _db.collection(Paths.printShops);

  static DateTime? _toDate(Object? value) => value is Timestamp ? value.toDate() : null;

  // ---- shops ---------------------------------------------------------------

  Stream<List<PrintShop>> watchShops() => _shops
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map((d) => PrintShop.fromMap(d.id, d.data())).toList())
      .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));

  Stream<PrintShop?> watchShop(String id) => _shops.doc(id).snapshots().map(
        (snap) => snap.exists ? PrintShop.fromMap(snap.id, snap.data()!) : null,
      );

  // ---- orders --------------------------------------------------------------

  /// One student's orders, newest first.
  Stream<List<PrintOrder>> watchMyOrders(String studentId) => _orders
      .where('studentId', isEqualTo: studentId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map(_fromDoc).toList())
      .handleError((Object e, StackTrace s) => throw FailureMapper.map(e, s));

  Stream<PrintOrder?> watchOrder(String id) => _orders.doc(id).snapshots().map(
        (snap) => snap.exists ? _fromDoc(snap) : null,
      );

  PrintOrder _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      PrintOrder.fromMap(d.id, d.data() ?? const {}, toDate: _toDate);

  /// Uploads the document, then creates the order.
  ///
  /// Upload first, deliberately: an order whose file failed to upload would be
  /// unprintable, and the shop would have no way to tell. Better to fail before
  /// anything appears in their queue.
  Future<String> placeOrder({
    required String studentId,
    required String studentName,
    String? studentPhone,
    required PrintShop shop,
    required File file,
    required String fileName,
    required String mimeType,
    int? pageCount,
    required PrintSettings settings,
    DateTime? neededBy,
    void Function(double progress)? onUploadProgress,
  }) =>
      FailureMapper.guard(() async {
        final orderRef = _orders.doc();

        final path = DocumentStorage.pathFor(studentId, orderRef.id, fileName);
        final url = await _documents.upload(
          file: file,
          path: path,
          mimeType: mimeType,
          onProgress: onUploadProgress,
        );

        final cost = estimateCost(
          settings: settings,
          pageCount: pageCount,
          bwPerPage: shop.bwPerPage,
          colourPerPage: shop.colourPerPage,
        );

        await orderRef.set({
          // Human-facing number. Derived from the clock rather than a counter
          // document because a client cannot safely increment a shared counter;
          // a Cloud Function will replace this with a proper sequence.
          'orderNumber': DateTime.now().millisecondsSinceEpoch % 100000,
          'studentId': studentId,
          'studentName': studentName,
          'studentPhone': studentPhone,
          'shopId': shop.id,
          'shopName': shop.name,
          'document': PrintDocument(
            fileName: fileName,
            storagePath: path,
            downloadUrl: url,
            mimeType: mimeType,
            sizeBytes: await file.length(),
            pageCount: pageCount,
          ).toMap(),
          'settings': settings.toMap(),
          // Students may only ever create an order as `received`; every later
          // transition belongs to the shop. Enforced in firestore.rules.
          'status': PrintOrderStatus.received.name,
          'neededBy': neededBy == null ? null : Timestamp.fromDate(neededBy),
          'estimatedCost': cost,
          'createdAt': FieldValue.serverTimestamp(),
          'statusChangedAt': FieldValue.serverTimestamp(),
        });

        return orderRef.id;
      });

  /// A student withdrawing their own order before it is printed.
  Future<void> cancelOrder(String orderId) => FailureMapper.guard(
        () => _orders.doc(orderId).update({
          'status': PrintOrderStatus.cancelled.name,
          'statusChangedAt': FieldValue.serverTimestamp(),
        }),
      );

  /// Validates a picked file before anything is uploaded.
  ///
  /// Returns null when acceptable, otherwise a failure explaining precisely
  /// what is wrong — the two cases §31 calls out by name.
  static AppFailure? validateDocument({
    required String fileName,
    required int sizeBytes,
    required int maxBytes,
  }) {
    final extension = fileName.split('.').last.toLowerCase();
    if (!AppConfig.allowedDocumentExtensions.contains(extension)) {
      return AppFailure(
        kind: FailureKind.unsupportedFile,
        message: 'Only PDF, JPG and PNG files can be printed. '
            '"$fileName" is a .$extension file.',
        isRetryable: false,
      );
    }

    if (sizeBytes > maxBytes) {
      final limitMb = (maxBytes / (1024 * 1024)).round();
      return AppFailure(
        kind: FailureKind.fileTooLarge,
        message: 'That file is too large. The limit is $limitMb MB.',
        isRetryable: false,
      );
    }

    if (sizeBytes == 0) {
      return const AppFailure(
        kind: FailureKind.unsupportedFile,
        message: 'That file is empty.',
        isRetryable: false,
      );
    }

    return null;
  }

  static String mimeTypeFor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      _ => 'image/jpeg',
    };
  }
}
