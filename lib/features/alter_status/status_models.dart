import 'package:prism_plurality/shared/icon_choices.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// One of the eight built-in status types.
class BuiltInStatus {
  const BuiltInStatus(this.id, this.en, this.es, this.icon, this.color);
  final String id;
  final String en;
  final String es;
  final String icon;
  final int color;
}

const builtInStatuses = [
  BuiltInStatus('online', 'Online', 'En línea', 'circle', 0xFF3BA55C),
  BuiltInStatus('idle', 'Idle', 'Inactivo', 'moon', 0xFFFAA61A),
  BuiltInStatus('dnd', 'Do Not Disturb', 'No molestar', 'minus', 0xFFED4245),
  BuiltInStatus('invisible', 'Invisible', 'Invisible', 'eyeSlash', 0xFF747F8D),
  BuiltInStatus('busy', 'Busy', 'Ocupado', 'briefcase', 0xFFE67E22),
  BuiltInStatus('away', 'Away', 'Ausente', 'clock', 0xFF95A5A6),
  BuiltInStatus('resting', 'Resting', 'Descansando', 'bed', 0xFF5865F2),
  BuiltInStatus('available', 'Available', 'Disponible', 'hand', 0xFF1ABC9C),
];

/// A resolved status ready to display.
class AlterStatus {
  const AlterStatus({
    required this.memberId,
    required this.typeKey,
    required this.title,
    required this.iconKey,
    required this.color,
    this.message,
    this.activity,
    this.expiresAt,
    this.setAt,
    this.isPrivate = false,
    this.record,
  });

  final String memberId;

  /// `builtin:<id>` or `custom:<recordId>`.
  final String typeKey;
  final String title;
  final String iconKey;
  final int color;
  final String? message;
  final String? activity;
  final DateTime? expiresAt;
  final DateTime? setAt;
  final bool isPrivate;
  final TrackerRecord? record;

  IconData get icon => iconFor(iconKey);
  bool isExpired(DateTime now) => expiresAt != null && !expiresAt!.isAfter(now);
}

/// A selectable status type (built-in or custom).
class StatusType {
  const StatusType({required this.key, required this.title, required this.iconKey, required this.color, this.description, this.record});
  final String key;
  final String title;
  final String iconKey;
  final int color;
  final String? description;
  final TrackerRecord? record;
}
