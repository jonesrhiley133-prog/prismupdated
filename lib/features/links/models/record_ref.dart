import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/shared/l10n/tr.dart';

/// Points at any linkable record in Prism.
///
/// [type] is `member`, `front`, `mood`, `location`, `event`, or `rec` for a
/// generic tracker record (journal, dream, meal, scrapbook page, …).
@immutable
class RecordRef {
  const RecordRef(this.type, this.id);

  final String type;
  final String id;

  static const member = 'member';
  static const front = 'front';
  static const mood = 'mood';
  static const location = 'location';
  static const event = 'event';
  static const rec = 'rec';

  String get key => '$type:$id';

  static RecordRef? parse(String? key) {
    if (key == null) return null;
    final i = key.indexOf(':');
    if (i <= 0) return null;
    return RecordRef(key.substring(0, i), key.substring(i + 1));
  }

  @override
  bool operator ==(Object other) =>
      other is RecordRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => key;
}

/// What the explorer and pickers show for a record.
@immutable
class RecordInfo {
  const RecordInfo({
    required this.ref,
    required this.module,
    required this.title,
    this.subtitle,
    this.date,
    this.kind,
    this.isPrivate = false,
    this.memberId,
  });

  final RecordRef ref;

  /// Module key, see [recordModules].
  final String module;
  final String title;
  final String? subtitle;
  final DateTime? date;

  /// Tracker kind for `rec` records.
  final String? kind;
  final bool isPrivate;
  final String? memberId;
}

/// A module that records can belong to.
class RecordModule {
  const RecordModule(this.key, this.en, this.es, this.icon, this.color);
  final String key;
  final String en;
  final String es;
  final IconData icon;
  final Color color;

  String label(BuildContext context) => tr(context, en, es);
}

final List<RecordModule> recordModules = [
  RecordModule('member', 'Alters', 'Alters', PhosphorIcons.user(), const Color(0xFF8E7CC3)),
  RecordModule('subsystem', 'Subsystems', 'Subsistemas', PhosphorIcons.treeStructure(), const Color(0xFF6C8EBF)),
  RecordModule('front', 'Fronting', 'Al frente', PhosphorIcons.arrowsLeftRight(), const Color(0xFF4FA3A5)),
  RecordModule('sleep', 'Sleep', 'Sueño', PhosphorIcons.moon(), const Color(0xFF5B6BB5)),
  RecordModule('mood', 'Mood', 'Ánimo', PhosphorIcons.smiley(), const Color(0xFFE6A23C)),
  RecordModule('journal', 'Journal', 'Diario', PhosphorIcons.notebook(), const Color(0xFFB07AA1)),
  RecordModule('dream', 'Dreams', 'Sueños', PhosphorIcons.cloudMoon(), const Color(0xFF7E6BD6)),
  RecordModule('location', 'Locations', 'Lugares', PhosphorIcons.mapPin(), const Color(0xFF59A14F)),
  RecordModule('event', 'Calendar', 'Calendario', PhosphorIcons.calendarBlank(), const Color(0xFFE15759)),
  RecordModule('nutri', 'Nutrition', 'Nutrición', PhosphorIcons.forkKnife(), const Color(0xFFF28E2B)),
  RecordModule('drink', 'Hydration', 'Hidratación', PhosphorIcons.drop(), const Color(0xFF4E9BD6)),
  RecordModule('fitness', 'Activity', 'Actividad', PhosphorIcons.personSimpleRun(), const Color(0xFF76B7B2)),
  RecordModule('scrap', 'Scrapbook', 'Álbum', PhosphorIcons.images(), const Color(0xFFFF9DA7)),
  RecordModule('conn', 'Connections', 'Conexiones', PhosphorIcons.graph(), const Color(0xFF9C755F)),
  RecordModule('rel', 'Relationships', 'Relaciones', PhosphorIcons.heart(), const Color(0xFFD37295)),
  RecordModule('other', 'Other', 'Otros', PhosphorIcons.dotsThreeCircle(), const Color(0xFF8C8C8C)),
];

RecordModule moduleFor(String key) =>
    recordModules.firstWhere((m) => m.key == key, orElse: () => recordModules.last);

/// Module key for a tracker record kind; null when the kind should not be
/// offered for linking (settings, categories, internal bookkeeping).
String? moduleForKind(String kind) => switch (kind) {
  TrackerKind.journalEntry => 'journal',
  TrackerKind.dreamEntry => 'dream',
  TrackerKind.sleepLog => 'sleep',
  TrackerKind.subsystem => 'subsystem',
  TrackerKind.nutriMeal => 'nutri',
  TrackerKind.nutriDrink => 'drink',
  TrackerKind.fitnessWorkout => 'fitness',
  TrackerKind.scrapPage || TrackerKind.scrapBook => 'scrap',
  TrackerKind.connNode || TrackerKind.connMap => 'conn',
  TrackerKind.relationship || TrackerKind.relationshipEvent => 'rel',
  TrackerKind.cycleWellness ||
  TrackerKind.schoolAssignment ||
  TrackerKind.schoolStudy ||
  TrackerKind.dictTerm ||
  TrackerKind.headspaceArea ||
  TrackerKind.financeTxn => 'other',
  _ => null,
};

/// Built-in relationship categories. Wording deliberately avoids implying
/// cause and effect.
class LinkCategoryDef {
  const LinkCategoryDef(this.id, this.en, this.es, this.color);
  final String id;
  final String en;
  final String es;
  final int color;
}

const builtInLinkCategories = [
  LinkCategoryDef('related', 'Related', 'Relacionado', 0xFF8E7CC3),
  LinkCategoryDef('during', 'Happened during', 'Ocurrió durante', 0xFF4FA3A5),
  LinkCategoryDef('mentions', 'Mentions', 'Menciona', 0xFFE6A23C),
  LinkCategoryDef('partOf', 'Part of', 'Parte de', 0xFF6C8EBF),
  LinkCategoryDef('inspired', 'Inspired by', 'Inspirado por', 0xFFFF9DA7),
  LinkCategoryDef('followUp', 'Follow-up', 'Seguimiento', 0xFF59A14F),
];
