import 'package:intl/intl.dart';

abstract final class Fmt {
  /// "just now" · "12 min ago" · "3 h ago" · "Yesterday" · "10 Aug"
  static String relative(DateTime time, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(time);

    if (diff.isNegative) return 'just now'; // clock skew / server timestamp
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('d MMM').format(time);
  }

  /// Countdown for an expiry: "expires in 25 min" · "expires in 2 h".
  static String expiresIn(Duration left) {
    if (left <= Duration.zero) return 'expired';
    if (left.inMinutes < 60) return 'expires in ${left.inMinutes} min';
    if (left.inHours < 24) return 'expires in ${left.inHours} h';
    return 'expires in ${left.inDays} d';
  }

  static String dateTime(DateTime t) => DateFormat('d MMM y, h:mm a').format(t);
  static String date(DateTime t) => DateFormat('d MMMM y').format(t);
  static String time(DateTime t) => DateFormat('h:mm a').format(t);

  /// "Good morning" / "Good afternoon" / "Good evening" for the home greeting.
  static String greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// First name only, for a greeting that doesn't shout the full legal name.
  static String firstName(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
