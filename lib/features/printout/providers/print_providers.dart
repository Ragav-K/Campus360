import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../models/enums/print_enums.dart';
import '../../../models/print_order.dart';
import '../../../models/print_shop.dart';
import '../../../repositories/print_repository.dart';
import '../../auth/providers/auth_providers.dart';

final printRepositoryProvider = Provider<PrintRepository>(
  (ref) => PrintRepository(ref.watch(firestoreProvider)),
);

final printShopsProvider = StreamProvider<List<PrintShop>>(
  (ref) => ref.watch(printRepositoryProvider).watchShops(),
);

final myOrdersProvider = StreamProvider<List<PrintOrder>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(printRepositoryProvider).watchMyOrders(uid);
});

/// Orders still moving through a shop.
final activeOrdersProvider = Provider<List<PrintOrder>>(
  (ref) => (ref.watch(myOrdersProvider).valueOrNull ?? const []).where((o) => o.isActive).toList(),
);

/// Finished, rejected or cancelled orders.
final pastOrdersProvider = Provider<List<PrintOrder>>(
  (ref) => (ref.watch(myOrdersProvider).valueOrNull ?? const []).where((o) => !o.isActive).toList(),
);

final orderDetailProvider = StreamProvider.autoDispose.family<PrintOrder?, String>(
  (ref, id) => ref.watch(printRepositoryProvider).watchOrder(id),
);

/// The order being composed, held across the four wizard steps.
class OrderDraft {
  const OrderDraft({
    this.file,
    this.fileName,
    this.sizeBytes,
    this.pageCount,
    this.shop,
    this.settings = const PrintSettings(),
    this.neededBy,
  });

  final File? file;
  final String? fileName;
  final int? sizeBytes;
  final int? pageCount;
  final PrintShop? shop;
  final PrintSettings settings;

  /// When the student needs it ready. Null means no particular time.
  final DateTime? neededBy;

  bool get hasFile => file != null && fileName != null;
  bool get isReadyToPlace => hasFile && shop != null;

  double? get estimatedCost => estimateCost(
        settings: settings,
        pageCount: pageCount,
        bwPerPage: shop?.bwPerPage,
        colourPerPage: shop?.colourPerPage,
      );

  OrderDraft copyWith({
    File? file,
    String? fileName,
    int? sizeBytes,
    int? pageCount,
    PrintShop? shop,
    PrintSettings? settings,
    DateTime? neededBy,
    bool clearNeededBy = false,
  }) =>
      OrderDraft(
        file: file ?? this.file,
        fileName: fileName ?? this.fileName,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        pageCount: pageCount ?? this.pageCount,
        shop: shop ?? this.shop,
        settings: settings ?? this.settings,
        neededBy: clearNeededBy ? null : (neededBy ?? this.neededBy),
      );
}

class OrderDraftController extends Notifier<OrderDraft> {
  @override
  OrderDraft build() => const OrderDraft();

  void setFile({required File file, required String name, required int sizeBytes, int? pageCount}) {
    state = state.copyWith(file: file, fileName: name, sizeBytes: sizeBytes, pageCount: pageCount);
  }

  void setShop(PrintShop shop) {
    var settings = state.settings;

    // A shop that can't do colour or duplex must not be sent an order asking
    // for it — silently fall back rather than letting the order be rejected.
    if (!shop.supportsColour && settings.colour == PrintColour.colour) {
      settings = settings.copyWith(colour: PrintColour.bw);
    }
    if (!shop.supportsDuplex && settings.sides == PrintSides.double) {
      settings = settings.copyWith(sides: PrintSides.single);
    }
    if (!shop.paperSizes.contains(settings.paper) && shop.paperSizes.isNotEmpty) {
      settings = settings.copyWith(paper: shop.paperSizes.first);
    }

    state = state.copyWith(shop: shop, settings: settings);
  }

  void setSettings(PrintSettings settings) => state = state.copyWith(settings: settings);

  void setNeededBy(DateTime? when) => state = when == null
      ? state.copyWith(clearNeededBy: true)
      : state.copyWith(neededBy: when);

  void reset() => state = const OrderDraft();
}

final orderDraftProvider = NotifierProvider<OrderDraftController, OrderDraft>(OrderDraftController.new);

/// Upload progress, 0–1, while an order is being placed.
final uploadProgressProvider = StateProvider<double?>((_) => null);
