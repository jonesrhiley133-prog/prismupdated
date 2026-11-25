import 'package:prism_plurality/features/flags/flag_model.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// A saved flag with its info page, collection, owners and versions.
class FlagEntry {
  FlagEntry(this.r);
  final TrackerRecord r;
  String get id => r.id;
  String get name => r.title.isEmpty ? 'Untitled flag' : r.title;
  FlagDesign get design => FlagDesign.fromJson(r.fields['design']);
  String get meaning => r.body ?? '';
  Map<String, String> get colorMeanings => {
    for (final e in ((r.fields['colorMeanings'] as Map?) ?? const {}).entries)
      '${e.key}': '${e.value}',
  };
  String get creator => '${r.fields['creator'] ?? ''}';
  String get collection => '${r.fields['collection'] ?? ''}';
  List<String> get assigned => [
    for (final x in (r.fields['assigned'] as List? ?? const [])) '$x',
  ];
  bool get favorite => r.flag('favorite');
  List<(DateTime, FlagDesign, String)> get versions => [
    for (final v in (r.fields['versions'] as List? ?? const []))
      if (v is Map)
        (
          DateTime.tryParse('${v['at']}') ?? r.createdAt,
          FlagDesign.fromJson(v['design']),
          '${v['label'] ?? ''}',
        ),
  ];
}

final flagsProvider = Provider<List<FlagEntry>>(
  (ref) => [
    for (final r
        in ref.watch(trackerKindProvider(TrackerKind.flag)).value ??
            const <TrackerRecord>[])
      FlagEntry(r),
  ]..sort((a, b) => b.r.modifiedAt.compareTo(a.r.modifiedAt)),
);
final flagByIdProvider = Provider.family<FlagEntry?, String>(
  (ref, id) => ref.watch(flagsProvider).where((f) => f.id == id).firstOrNull,
);

/// Flags assigned to a headmate ('system' for the whole system).
final flagsForProvider = Provider.family<List<FlagEntry>, String>(
  (ref, owner) => [
    for (final f in ref.watch(flagsProvider))
      if (f.assigned.contains(owner)) f,
  ],
);

class FlagActions {
  FlagActions(this.ref);
  final Ref ref;
  TrackerNotifier get _t => ref.read(trackerNotifierProvider.notifier);
  TrackerRecord? _rec(String id) =>
      (ref.read(trackerKindProvider(TrackerKind.flag)).value ??
              const <TrackerRecord>[])
          .where((r) => r.id == id)
          .firstOrNull;

  Future<TrackerRecord> create(
    String name,
    FlagDesign d, {
    String collection = '',
  }) => _t.create(
    kind: TrackerKind.flag,
    title: name,
    fields: {
      'v': 1,
      'design': d.toJson(),
      'collection': collection,
      'versions': const [],
    },
  );

  Future<void> saveDesign(String id, FlagDesign d) async {
    final r = _rec(id);
    if (r != null)
      await _t.save(r.withFields({...r.fields, 'design': d.toJson()}));
  }

  Future<void> update(
    String id, {
    String? name,
    String? meaning,
    Map<String, Object?> fields = const {},
  }) async {
    final r = _rec(id);
    if (r != null)
      await _t.save(
        r.copyWith(title: name ?? r.title, body: meaning ?? r.body).withFields({
          ...r.fields,
          ...fields,
        }),
      );
  }

  /// Keeps the last 20 named snapshots.
  Future<void> saveVersion(String id, FlagDesign d, {String label = ''}) async {
    final r = _rec(id);
    if (r == null) return;
    final list = [
      ...(r.fields['versions'] as List? ?? const []),
      {
        'at': DateTime.now().toIso8601String(),
        'design': d.toJson(),
        'label': label,
      },
    ];
    await _t.save(
      r.withFields({
        ...r.fields,
        'versions': list.length > 20 ? list.sublist(list.length - 20) : list,
      }),
    );
  }

  Future<TrackerRecord> duplicate(FlagEntry f) => _t.create(
    kind: TrackerKind.flag,
    title: '${f.name} (copy)',
    body: f.meaning,
    fields: {...f.r.fields, 'versions': const [], 'favorite': false},
  );
  Future<void> delete(FlagEntry f) => _t.delete(f.id, children: false);
}

final flagActionsProvider = Provider<FlagActions>(FlagActions.new);
