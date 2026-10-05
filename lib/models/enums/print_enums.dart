import 'package:flutter/material.dart';

import 'pulse_enums.dart';

/// Print order lifecycle (§21).
enum PrintOrderStatus {
  submitted,
  received,
  accepted,
  printing,
  readyForPickup,
  collected,
  rejected,
  cancelled;

  static PrintOrderStatus fromName(String? n) =>
      PrintOrderStatus.values.where((s) => s.name == n).firstOrNull ?? PrintOrderStatus.submitted;

  String get label => switch (this) {
        PrintOrderStatus.submitted => 'Submitted',
        PrintOrderStatus.received => 'Received',
        PrintOrderStatus.accepted => 'Accepted',
        PrintOrderStatus.printing => 'Printing',
        PrintOrderStatus.readyForPickup => 'Ready for pickup',
        PrintOrderStatus.collected => 'Collected',
        PrintOrderStatus.rejected => 'Rejected',
        PrintOrderStatus.cancelled => 'Cancelled',
      };

  /// Wording aimed at the student rather than the shop.
  String get studentLabel => switch (this) {
        PrintOrderStatus.submitted => 'Sending…',
        PrintOrderStatus.received => 'With the shop',
        PrintOrderStatus.accepted => 'Accepted',
        PrintOrderStatus.printing => 'Printing now',
        PrintOrderStatus.readyForPickup => 'Ready to collect',
        PrintOrderStatus.collected => 'Collected',
        PrintOrderStatus.rejected => 'Could not be printed',
        PrintOrderStatus.cancelled => 'Cancelled',
      };

  StatusTone get tone => switch (this) {
        PrintOrderStatus.readyForPickup || PrintOrderStatus.collected => StatusTone.good,
        PrintOrderStatus.printing || PrintOrderStatus.accepted => StatusTone.info,
        PrintOrderStatus.rejected => StatusTone.bad,
        PrintOrderStatus.cancelled => StatusTone.neutral,
        _ => StatusTone.caution,
      };

  IconData get icon => switch (this) {
        PrintOrderStatus.submitted => Icons.upload_file_rounded,
        PrintOrderStatus.received => Icons.inbox_rounded,
        PrintOrderStatus.accepted => Icons.thumb_up_outlined,
        PrintOrderStatus.printing => Icons.print_rounded,
        PrintOrderStatus.readyForPickup => Icons.check_circle_rounded,
        PrintOrderStatus.collected => Icons.done_all_rounded,
        PrintOrderStatus.rejected => Icons.cancel_outlined,
        PrintOrderStatus.cancelled => Icons.remove_circle_outline_rounded,
      };

  /// Still moving through the shop — shown under "Current orders".
  bool get isActive => switch (this) {
        PrintOrderStatus.collected || PrintOrderStatus.rejected || PrintOrderStatus.cancelled => false,
        _ => true,
      };

  /// A student may still cancel before the shop commits paper to it.
  bool get isCancellableByStudent => switch (this) {
        PrintOrderStatus.submitted || PrintOrderStatus.received || PrintOrderStatus.accepted => true,
        _ => false,
      };
}

enum PrintColour {
  bw,
  colour;

  static PrintColour fromName(String? n) =>
      PrintColour.values.where((c) => c.name == n).firstOrNull ?? PrintColour.bw;

  String get label => this == PrintColour.bw ? 'Black & white' : 'Colour';
  String get shortLabel => this == PrintColour.bw ? 'B&W' : 'Colour';
}

enum PrintSides {
  single,
  double;

  static PrintSides fromName(String? n) =>
      PrintSides.values.where((s) => s.name == n).firstOrNull ?? PrintSides.single;

  String get label => this == PrintSides.single ? 'Single-sided' : 'Double-sided';
  String get shortLabel => this == PrintSides.single ? '1-sided' : '2-sided';
}
