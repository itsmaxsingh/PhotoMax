import 'package:intl/intl.dart';

/// Groups photos by date into human-readable sections
String getDateGroup(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final assetDay = DateTime(date.year, date.month, date.day);

  final difference = today.difference(assetDay).inDays;

  if (difference == 0) {
    return 'Today';
  } else if (difference == 1) {
    return 'Yesterday';
  } else if (difference < 7) {
    // Return day name: Monday, Tuesday, etc.
    return DateFormat('EEEE').format(date);
  } else {
    // Return full date: June 15, 2025
    return DateFormat('MMMM d, y').format(date);
  }
}
