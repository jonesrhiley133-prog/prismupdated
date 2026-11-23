import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/astro/content/horoscope.dart';
import 'package:prism_plurality/features/astro/content/tarot.dart';
import 'package:prism_plurality/features/astro/engine/chart.dart';
import 'package:prism_plurality/features/astro/engine/ephemeris.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/members/utils/birthday.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Who can see an alter's astrology. Private by default: entering birth
/// details never makes them visible to other alters on its own.
enum AstroVisibility {
  private('🔒', ('Private to this alter', 'Privado para este alter'), ('Only shows while this alter is fronting.', 'Solo se muestra mientras este alter está al frente.')),
  system('👥', ('System-visible', 'Visible en el sistema'), ('Every alter in the system can see it.', 'Todos los alters del sistema pueden verlo.')),
  shareable('🌐', ('Shareable', 'Compartible'), ('System-visible, and can be shared outside Prism.', 'Visible en el sistema y se puede compartir fuera de Prism.')),
  hidden('🚫', ('Hide astrology', 'Ocultar astrología'), ('Hidden everywhere, including profiles, Home and the calendar.', 'Oculto en todas partes, también en perfiles, Inicio y el calendario.'));

  const AstroVisibility(this.emoji, this.label, this.description);
  final String emoji;
  final (String, String) label;
  final (String, String) description;

  static AstroVisibility parse(Object? v) =>
      AstroVisibility.values.where((x) => x.name == v).firstOrNull ?? AstroVisibility.private;
}

/// One alter's astrology settings (one `astro.profile` record each). The
/// birth month and day come from the member's birthday so they stay in one
/// place; the year can live here when the profile hides it.
class AstroProfile {
  const AstroProfile({
    required this.memberId,
    this.record,
    this.year,
    this.hour,
    this.minute,
    this.place,
    this.visibility = AstroVisibility.private,
    this.houseSystem = HouseSystem.placidus,
  });

  final String memberId;
  final TrackerRecord? record;

  /// Birth year kept privately for astrology when the profile hides it.
  final int? year;
  final int? hour;
  final int? minute;
  final BirthPlace? place;
  final AstroVisibility visibility;
  final HouseSystem houseSystem;

  static AstroProfile of(TrackerRecord r) {
    final f = r.fields;
    return AstroProfile(
      memberId: r.memberId ?? '',
      record: r,
      year: (f['year'] as num?)?.toInt(),
      hour: (f['hour'] as num?)?.toInt(),
      minute: (f['minute'] as num?)?.toInt(),
      place: BirthPlace.fromJson(f['place']),
      visibility: AstroVisibility.parse(f['visibility']),
      houseSystem: HouseSystem.values.where((h) => h.name == f['houses']).firstOrNull ?? HouseSystem.placidus,
    );
  }

  Map<String, Object?> toFields() => {
    'year': year,
    'hour': hour,
    'minute': minute,
    'place': place?.toJson(),
    'visibility': visibility.name,
    'houses': houseSystem.name,
  };

  AstroProfile copyWith({
    int? year,
    bool clearYear = false,
    int? hour,
    int? minute,
    bool clearTime = false,
    BirthPlace? place,
    bool clearPlace = false,
    AstroVisibility? visibility,
    HouseSystem? houseSystem,
  }) => AstroProfile(
    memberId: memberId,
    record: record,
    year: clearYear ? null : (year ?? this.year),
    hour: clearTime ? null : (hour ?? this.hour),
    minute: clearTime ? null : (minute ?? this.minute),
    place: clearPlace ? null : (place ?? this.place),
    visibility: visibility ?? this.visibility,
    houseSystem: houseSystem ?? this.houseSystem,
  );

  /// Birth data from the member's birthday plus this profile; null without
  /// a birthday.
  BirthData? birthData(Member member) {
    final b = parseBirthday(member.birthday);
    if (b == null) return null;
    final yearHidden = isBirthdayYearHidden(b);
    return BirthData(
      month: b.month,
      day: b.day,
      year: yearHidden ? year : b.year,
      hour: hour,
      minute: hour == null ? null : (minute ?? 0),
      place: place,
    );
  }
}

/// System-wide Astro preferences (`astro.settings`, no member).
class AstroSettings {
  const AstroSettings({this.record, this.homeCard = true, this.insights = true, this.calendar = true});
  final TrackerRecord? record;

  /// Show the fronting alter's astrology card on Home.
  final bool homeCard;

  /// Include an astrology line in Daily Insights.
  final bool insights;

  /// Add moon phases, sign changes and birthdays to the Calendar.
  final bool calendar;

  static AstroSettings of(TrackerRecord? r) {
    final f = r?.fields ?? const {};
    return AstroSettings(record: r, homeCard: f['homeCard'] != false, insights: f['insights'] != false, calendar: f['calendar'] != false);
  }

  Map<String, Object?> toFields() => {'homeCard': homeCard, 'insights': insights, 'calendar': calendar};
}

final astroProfilesProvider = Provider<Map<String, AstroProfile>>((ref) {
  final list = ref.watch(trackerKindProvider(TrackerKind.astroProfile)).value ?? const <TrackerRecord>[];
  return {
    for (final r in list.reversed)
      if (r.memberId != null) r.memberId!: AstroProfile.of(r),
  };
});

final astroSettingsProvider = Provider<AstroSettings>((ref) {
  final list = ref.watch(trackerKindProvider(TrackerKind.astroSettings)).value ?? const <TrackerRecord>[];
  return AstroSettings.of(list.firstOrNull);
});

/// The alters fronting right now: they can see their own private astrology.
final astroViewersProvider = Provider<Set<String>>((ref) {
  final sessions = ref.watch(activeSessionsProvider).value ?? const [];
  return {
    for (final s in sessions)
      if (s.memberId != null) s.memberId!,
  };
});

/// What the current viewer may see of one alter's astrology.
class AstroAccess {
  AstroAccess({required this.member, required this.profile, required this.birth, required this.viewers, required this.preferDisplay});

  final Member member;
  final AstroProfile profile;
  final BirthData? birth;
  final Set<String> viewers;
  final bool preferDisplay;

  String get name => member.effectiveName(preferDisplayName: preferDisplay);
  AstroVisibility get visibility => profile.visibility;

  /// This alter is fronting (it's their own view).
  bool get isOwner => viewers.contains(member.id);

  /// Nothing has been entered yet, so there's nothing private to protect.
  bool get isEmpty => birth == null && profile.record == null;

  bool get canView => isOwner || isEmpty || visibility == AstroVisibility.system || visibility == AstroVisibility.shareable;

  /// May appear in profiles, Home, the calendar and system views.
  bool get listed => canView && visibility != AstroVisibility.hidden && birth != null;

  bool get hasBirthday => birth != null;

  late final NatalChart? chart = birth != null && birth!.hasYear ? NatalChart.of(birth!, houses: profile.houseSystem) : null;

  /// The Sun sign: exact from the chart, else from the date (with a cusp
  /// note handled by the UI).
  late final int? sunSign = chart?.sunSign ?? (birth == null ? null : sunSignForDate(birth!.month, birth!.day).$1);

  int? get cuspWith => chart != null ? chart!.uncertainSigns[Body.sun] : (birth == null ? null : sunSignForDate(birth!.month, birth!.day).$2);

  late final AstroSubject? subject = sunSign == null
      ? null
      : AstroSubject(name: name, sunSign: sunSign!, chart: chart, seed: member.id.hashCode);
}

final astroAccessProvider = Provider.family<AstroAccess?, String>((ref, memberId) {
  final members = ref.watch(userVisibleMembersProvider).value ?? const <Member>[];
  final member = members.where((m) => m.id == memberId).firstOrNull;
  if (member == null) return null;
  final profile = ref.watch(astroProfilesProvider)[memberId] ?? AstroProfile(memberId: memberId);
  return AstroAccess(
    member: member,
    profile: profile,
    birth: profile.birthData(member),
    viewers: ref.watch(astroViewersProvider),
    preferDisplay: ref.watch(memberNamePreferDisplayProvider),
  );
});

/// Every alter in display order, with access info.
final astroAllProvider = Provider<List<AstroAccess>>((ref) {
  final members = ref.watch(userVisibleMembersProvider).value ?? const <Member>[];
  return [
    for (final m in members)
      if (ref.watch(astroAccessProvider(m.id)) case final a?) a,
  ];
});

/// Alters whose astrology the current viewer may see in shared views.
final astroListedProvider = Provider<List<AstroAccess>>((ref) => [
  for (final a in ref.watch(astroAllProvider))
    if (a.listed) a,
]);

/// "How did today actually feel?" entries.
class AstroJournalEntry {
  AstroJournalEntry(this.record);
  final TrackerRecord record;

  DateTime get day => record.occurredAt ?? record.createdAt;
  String? get memberId => record.memberId;
  Map<String, dynamic> get f => record.fields;
  String get theme => '${f['theme'] ?? ''}';
  int? get predicted => (f['predicted'] as num?)?.toInt();

  /// 1–5.
  int? get mood => (f['mood'] as num?)?.toInt();

  /// 'low' | 'medium' | 'high'.
  String? get energy => f['energy'] as String?;
  Map<EnergyKind, int> get felt => {
    for (final k in EnergyKind.values)
      if ((f['felt'] as Map?)?[k.name] case final num v) k: v.toInt(),
  };
  String get reflection => record.body ?? '';
}

final astroJournalProvider = Provider.family<List<AstroJournalEntry>, String>((ref, memberId) {
  final list = ref.watch(trackerKindProvider(TrackerKind.astroJournal)).value ?? const <TrackerRecord>[];
  return [
    for (final r in list)
      if (r.memberId == memberId) AstroJournalEntry(r),
  ];
});

class TarotReading {
  TarotReading(this.record);
  final TrackerRecord record;
  String get spreadId => '${record.fields['spread'] ?? 'one'}';
  Spread get spread => spreads.where((s) => s.id == spreadId).firstOrNull ?? spreads.first;
  List<DrawnCard> get cards => [
    for (final c in (record.fields['cards'] as List?) ?? const [])
      if (DrawnCard.fromJson(c) case final d?) d,
  ];
  String get question => record.title;
  String get notes => record.body ?? '';
  DateTime get when => record.occurredAt ?? record.createdAt;
}

final tarotReadingsProvider = Provider.family<List<TarotReading>, String>((ref, memberId) {
  final list = ref.watch(trackerKindProvider(TrackerKind.astroTarot)).value ?? const <TrackerRecord>[];
  return [
    for (final r in list)
      if (r.memberId == memberId) TarotReading(r),
  ];
});

class AstroActions {
  AstroActions(this.ref);
  final Ref ref;

  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);

  Future<void> saveProfile(AstroProfile p) async {
    final r = p.record;
    if (r == null) {
      await _t.create(kind: TrackerKind.astroProfile, memberId: p.memberId, fields: p.toFields(), isPrivate: p.visibility == AstroVisibility.private || p.visibility == AstroVisibility.hidden);
    } else {
      await _t.save(r.copyWith(isPrivate: p.visibility == AstroVisibility.private || p.visibility == AstroVisibility.hidden).withFields(p.toFields()));
    }
  }

  /// Sets the member's birthday (month/day, and the year unless hidden).
  Future<void> saveBirthday(Member member, DateTime date, {required bool hideYear}) async {
    await ref.read(membersNotifierProvider.notifier).updateMember(member.copyWith(birthday: formatBirthdayWire(date, hideYear: hideYear)));
  }

  Future<void> saveSettings(AstroSettings s) async {
    final r = s.record;
    if (r == null) {
      await _t.create(kind: TrackerKind.astroSettings, fields: s.toFields());
    } else {
      await _t.save(r.withFields(s.toFields()));
    }
  }

  Future<void> saveJournal({
    required String memberId,
    required DateTime day,
    required String theme,
    required int predicted,
    int? mood,
    String? energy,
    Map<EnergyKind, int> felt = const {},
    String reflection = '',
    bool private = true,
    TrackerRecord? existing,
  }) async {
    final fields = {
      'theme': theme,
      'predicted': predicted,
      'mood': mood,
      'energy': energy,
      'felt': {for (final e in felt.entries) e.key.name: e.value},
    };
    if (existing != null) {
      await _t.save(existing.copyWith(body: reflection.trim().isEmpty ? null : reflection.trim(), isPrivate: private).withFields(fields));
      return;
    }
    await _t.create(kind: TrackerKind.astroJournal, memberId: memberId, occurredAt: DateTime(day.year, day.month, day.day, 12), body: reflection, fields: fields, isPrivate: private);
  }

  Future<void> saveTarot({required String memberId, required Spread spread, required List<DrawnCard> cards, String question = '', String notes = '', bool private = true}) =>
      _t.create(
        kind: TrackerKind.astroTarot,
        memberId: memberId,
        title: question,
        body: notes,
        occurredAt: DateTime.now(),
        fields: {'spread': spread.id, 'cards': [for (final c in cards) c.toJson()]},
        isPrivate: private,
      );

  Future<void> delete(TrackerRecord r) => _t.delete(r.id);
}

final astroActionsProvider = Provider<AstroActions>(AstroActions.new);
