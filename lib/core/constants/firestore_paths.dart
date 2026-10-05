/// Single source of truth for collection names. Never type a collection
/// string literal anywhere else — a typo becomes a silent empty stream.
abstract final class Paths {
  static const users = 'users';
  static const campusLocations = 'campusLocations';
  static const pulseUpdates = 'pulseUpdates';
  static const lostItems = 'lostItems';
  static const foundItems = 'foundItems';
  static const matches = 'matches';
  static const claims = 'claims';
  static const printShops = 'printShops';
  static const printOrders = 'printOrders';
  static const notifications = 'notifications';
  static const config = 'config';
  static const counters = 'counters';

  // Sub-collections
  static const privateSub = 'private';
  static const reportsSub = 'reports';

  // Well-known documents
  static const appConfigDoc = 'app';
  static const otpDoc = 'otp';
  static const secretDoc = 'secret';
}

/// Storage prefixes (§29 / doc §5).
abstract final class StoragePaths {
  static String lostItemPhoto(String uid, String itemId) => 'lostItems/$uid/$itemId/photo.jpg';
  static String foundItemPhoto(String uid, String itemId) => 'foundItems/$uid/$itemId/photo.jpg';
  static String pulseImage(String pulseId) => 'pulse/$pulseId/image.jpg';
  static String printDoc(String uid, String orderId, String fileName) => 'printDocs/$uid/$orderId/$fileName';
  static String avatar(String uid) => 'avatars/$uid/avatar.jpg';
}
