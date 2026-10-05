import 'package:flutter/material.dart';

/// Campus location categories (§8). Each carries its own icon so map markers,
/// list rows and detail headers stay visually consistent.
enum LocationCategory {
  academicBlock,
  department,
  classroom,
  lab,
  library,
  canteen,
  printShop,
  parking,
  sports,
  medical,
  admin,
  other;

  static LocationCategory fromName(String? n) =>
      LocationCategory.values.where((c) => c.name == n).firstOrNull ?? LocationCategory.other;

  String get label => switch (this) {
        LocationCategory.academicBlock => 'Academic block',
        LocationCategory.department => 'Department',
        LocationCategory.classroom => 'Classroom',
        LocationCategory.lab => 'Lab',
        LocationCategory.library => 'Library',
        LocationCategory.canteen => 'Canteen',
        LocationCategory.printShop => 'Print shop',
        LocationCategory.parking => 'Parking',
        LocationCategory.sports => 'Sports',
        LocationCategory.medical => 'Medical',
        LocationCategory.admin => 'Administration',
        LocationCategory.other => 'Other',
      };

  /// Short label for filter chips, where horizontal space is tight.
  String get chipLabel => switch (this) {
        LocationCategory.academicBlock => 'Academic',
        LocationCategory.department => 'Depts',
        LocationCategory.classroom => 'Classes',
        LocationCategory.admin => 'Admin',
        _ => label,
      };

  IconData get icon => switch (this) {
        LocationCategory.academicBlock => Icons.apartment_rounded,
        LocationCategory.department => Icons.account_tree_outlined,
        LocationCategory.classroom => Icons.co_present_rounded,
        LocationCategory.lab => Icons.science_outlined,
        LocationCategory.library => Icons.local_library_outlined,
        LocationCategory.canteen => Icons.restaurant_rounded,
        LocationCategory.printShop => Icons.print_rounded,
        LocationCategory.parking => Icons.local_parking_rounded,
        LocationCategory.sports => Icons.sports_basketball_outlined,
        LocationCategory.medical => Icons.medical_services_outlined,
        LocationCategory.admin => Icons.badge_outlined,
        LocationCategory.other => Icons.place_outlined,
      };

  /// Categories worth surfacing as quick filters, in display order.
  static const List<LocationCategory> filterOrder = [
    LocationCategory.library,
    LocationCategory.canteen,
    LocationCategory.printShop,
    LocationCategory.lab,
    LocationCategory.academicBlock,
    LocationCategory.sports,
    LocationCategory.medical,
    LocationCategory.parking,
    LocationCategory.admin,
    LocationCategory.department,
    LocationCategory.classroom,
    LocationCategory.other,
  ];
}
