/// A birthday: month and day always, year only when known.
class BirthdayDate {
  const BirthdayDate(this.month, this.day, [this.year]);

  final int month;
  final int day;
  final int? year;

  /// Sentinel year meaning "unknown" (shared with member birthdays).
  static const noYear = 4;

  /// Whether month/day (and year, if any) form a real calendar date.
  /// Feb 29 is valid without a year.
  bool get isValid {
    if (month < 1 || month > 12 || day < 1) return false;
    final y = year ?? 2024; // leap year so Feb 29 is allowed
    if (year != null && (year! < 1800 || year! > DateTime.now().year)) {
      return false;
    }
    final d = DateTime.utc(y, month, day);
    return d.month == month && d.day == day;
  }

  /// `yyyy-MM-dd`, using [noYear] when the year is unknown.
  String toStorage() =>
      '${(year ?? noYear).toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  static BirthdayDate? fromStorage(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final b = BirthdayDate(
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      (y == noYear || y == 1) ? null : y,
    );
    return b.isValid ? b : null;
  }

  /// Next occurrence on or after [from] (Feb 29 falls on Feb 28 in
  /// non-leap years). Birthdays recur every year automatically.
  DateTime nextOccurrence(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    DateTime on(int y) {
      if (month == 2 && day == 29 && DateTime(y, 2, 29).month != 2) {
        return DateTime(y, 2, 28);
      }
      return DateTime(y, month, day);
    }

    final thisYear = on(today.year);
    return thisYear.isBefore(today) ? on(today.year + 1) : thisYear;
  }

  /// Age turned on [occurrence], when the year is known.
  int? ageOn(DateTime occurrence) =>
      year == null ? null : occurrence.year - year!;

  @override
  bool operator ==(Object other) =>
      other is BirthdayDate &&
      other.month == month &&
      other.day == day &&
      other.year == year;

  @override
  int get hashCode => Object.hash(month, day, year);
}
