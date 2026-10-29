import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

const eventTimezones = <String>[
  'Asia/Jakarta',
  'Asia/Singapore',
  'Asia/Tokyo',
  'Asia/Dubai',
  'Europe/London',
  'America/New_York',
  'UTC',
];

tz.Location _location(String name) {
  try {
    return tz.getLocation(name);
  } catch (_) {
    return tz.getLocation('Asia/Jakarta');
  }
}

/// Converts an instant to wall-clock components in an event timezone.
DateTime wallTimeFromUtc(DateTime utc, String timezone) {
  final zoned = tz.TZDateTime.from(utc.toUtc(), _location(timezone));
  return DateTime(
    zoned.year,
    zoned.month,
    zoned.day,
    zoned.hour,
    zoned.minute,
  );
}

/// Interprets wall-clock components as an event timezone and returns UTC.
DateTime wallTimeToUtc(DateTime wall, String timezone) {
  final location = _location(timezone);
  return tz.TZDateTime(
    location,
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
  ).toUtc();
}

String formatWallTime(DateTime wall, String pattern) =>
    DateFormat(pattern).format(wall);

String formatEventTime(DateTime utc, String timezone, String pattern) =>
    DateFormat(pattern).format(tz.TZDateTime.from(utc, _location(timezone)));
