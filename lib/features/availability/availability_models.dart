import 'package:prism_plurality/shared/icon_choices.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

class AvailCategory {
  const AvailCategory({required this.id, required this.title, required this.color, required this.icon, this.record});
  final String id;
  final String title;
  final int color;
  final String icon;
  final TrackerRecord? record;
  IconData get iconData => iconFor(icon);
}

const builtInAvailability = [
  ('available', 'Available', 'Disponible', 0xFF3BA55C, 'check'),
  ('interested', 'Interested in fronting', 'Quiere estar al frente', 0xFF5865F2, 'sparkle'),
  ('resting', 'Resting', 'Descansando', 0xFF9B59B6, 'bed'),
  ('unavailable', 'Unavailable', 'No disponible', 0xFFED4245, 'minus'),
  ('inactive', 'Inactive', 'Inactivo', 0xFF747F8D, 'moon'),
];

/// A weekly recurring block.
class AvailRule {
  AvailRule(this.record);
  final TrackerRecord record;
  String get memberId => record.memberId ?? '';
  List<int> get weekdays => [for (final s in record.strings('days')) ?int.tryParse(s)];
  int get startMin => record.integer('start') ?? 9 * 60;
  int get endMin => record.integer('end') ?? 17 * 60;
  String get category => record.str('cat') ?? 'available';
  bool get notify => record.flag('notify');
  String? get note => record.body;
  DateTime? get validFrom => record.occurredAt;
  DateTime? get validUntil => record.endedAt;

  bool covers(DateTime t) {
    if (!weekdays.contains(t.weekday)) {
      // Overnight blocks spill into the next day.
      if (endMin <= startMin && weekdays.contains(t.weekday == 1 ? 7 : t.weekday - 1)) {
        final m = t.hour * 60 + t.minute;
        return m < endMin && _valid(t);
      }
      return false;
    }
    final m = t.hour * 60 + t.minute;
    final inside = endMin > startMin ? m >= startMin && m < endMin : m >= startMin;
    return inside && _valid(t);
  }

  bool _valid(DateTime t) =>
      (validFrom == null || !t.isBefore(DateTime(validFrom!.year, validFrom!.month, validFrom!.day))) &&
      (validUntil == null || t.isBefore(DateTime(validUntil!.year, validUntil!.month, validUntil!.day + 1)));
}

/// A one-off change for a date range.
class AvailOverride {
  AvailOverride(this.record);
  final TrackerRecord record;
  String get memberId => record.memberId ?? '';
  DateTime get start => record.occurredAt ?? record.createdAt;
  DateTime get end => record.endedAt ?? start.add(const Duration(hours: 1));
  String get category => record.str('cat') ?? 'unavailable';
  String? get note => record.body;
  bool covers(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

/// A resolved block on a timeline.
class AvailBlock {
  const AvailBlock(this.memberId, this.start, this.end, this.category, {this.note, this.isOverride = false, this.record});
  final String memberId;
  final DateTime start;
  final DateTime end;
  final String category;
  final String? note;
  final bool isOverride;
  final TrackerRecord? record;
}

String fmtMinutes(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
