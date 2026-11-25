import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'package:prism_plurality/core/services/files/prism_file_dialog_service.dart';
import 'package:prism_plurality/features/companions/companion_data.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart'
    show memberNamesProvider;
import 'package:prism_plurality/features/experiences/export_kit.dart';
import 'package:prism_plurality/features/passport/passport_data.dart';
import 'package:prism_plurality/features/passport/passport_widgets.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Export a passport. A privacy review comes first; nothing is uploaded or
/// shared automatically — files are only saved where you choose.
class PassportExportScreen extends ConsumerStatefulWidget {
  const PassportExportScreen({super.key, required this.passportId});
  final String passportId;
  @override
  ConsumerState<PassportExportScreen> createState() =>
      _PassportExportScreenState();
}

class _PassportExportScreenState extends ConsumerState<PassportExportScreen> {
  PassportPrivacy _privacy = const PassportPrivacy();
  final _coverKey = GlobalKey();
  final _introKey = GlobalKey();
  final _sheetKey = GlobalKey();
  final _cardKey = GlobalKey();
  final Map<String, GlobalKey> _pageKeys = {};
  final Set<String> _skip = {};
  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await f();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<Uint8List>> _pageImages(
    List<PassportPage> pages, {
    bool withCover = true,
  }) async {
    final out = <Uint8List>[];
    if (withCover) {
      for (final k in [_coverKey, _introKey]) {
        final b = await captureBoundary(k, pixelRatio: 2.5);
        if (b != null) out.add(b);
      }
    }
    for (final pg in pages.where((p) => !_skip.contains(p.id))) {
      final b = await captureBoundary(_pageKeys[pg.id]!, pixelRatio: 2.5);
      if (b != null) out.add(b);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(passportByIdProvider(widget.passportId));
    if (p == null) return const SizedBox.shrink();
    final pages = ref.watch(passportPagesProvider(p.id));
    final stamps = ref.watch(passportStampsProvider(p.id));
    final names = [
      ...ref.watch(memberNamesProvider).values,
      for (final c in ref.watch(companionsProvider)) c.name,
    ];
    final privacy = _privacy.copyWith(nameList: names);
    final theme = Theme.of(context);
    for (final pg in pages) {
      _pageKeys.putIfAbsent(pg.id, GlobalKey.new);
    }
    final slug = p.name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');

    return PrismPageScaffold(
      topBar: const PrismTopBar(title: 'Export passport', showBackButton: true),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: PrivacyScope(
          privacy: privacy,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              32 + NavBarInset.of(context),
            ),
            children: [
              PrismSectionHeader(title: 'PRIVACY REVIEW'),
              PrismSurface(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    PrismSwitchRow(
                      title: 'Hide names',
                      subtitle: 'Headmate and companion names become •••',
                      value: _privacy.names,
                      onChanged: (v) => setState(
                        () => _privacy = _privacy.copyWith(names: v),
                      ),
                    ),
                    PrismSwitchRow(
                      title: 'Hide dates',
                      value: _privacy.dates,
                      onChanged: (v) => setState(
                        () => _privacy = _privacy.copyWith(dates: v),
                      ),
                    ),
                    PrismSwitchRow(
                      title: 'Hide places',
                      value: _privacy.locations,
                      onChanged: (v) => setState(
                        () => _privacy = _privacy.copyWith(locations: v),
                      ),
                    ),
                    PrismSwitchRow(
                      title: 'Hide photographs',
                      value: _privacy.photos,
                      onChanged: (v) => setState(
                        () => _privacy = _privacy.copyWith(photos: v),
                      ),
                    ),
                    PrismSwitchRow(
                      title: 'Hide notes, text and attachments',
                      value: _privacy.notes,
                      onChanged: (v) => setState(
                        () => _privacy = _privacy.copyWith(notes: v),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text(
                  'The preview below shows exactly what will be exported.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              PrismSectionHeader(title: 'EXPORT'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PrismButton(
                    label: 'Full PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    isLoading: _busy,
                    onPressed: () => _run(() async {
                      final imgs = await _pageImages(pages);
                      final ok = await savePdfBytes(
                        ref,
                        await imagesToPdf(imgs, title: p.name),
                        'passport-$slug',
                      );
                      if (context.mounted)
                        PrismToast.show(
                          context,
                          message: ok ? 'PDF saved' : 'Not saved',
                        );
                    }),
                  ),
                  PrismButton(
                    label: 'Page images',
                    icon: Icons.image_outlined,
                    isLoading: _busy,
                    onPressed: () => _run(() async {
                      final imgs = await _pageImages(pages);
                      var saved = 0;
                      for (final (i, b) in imgs.indexed) {
                        if (await saveImageBytes(
                          ref,
                          b,
                          'passport-$slug-${i + 1}',
                        ))
                          saved++;
                      }
                      if (context.mounted)
                        PrismToast.show(
                          context,
                          message: '$saved image${saved == 1 ? '' : 's'} saved',
                        );
                    }),
                  ),
                  PrismButton(
                    label: 'Printable stamp sheet',
                    icon: Icons.print_outlined,
                    isLoading: _busy,
                    onPressed: () => _run(() async {
                      final b = await captureBoundary(_sheetKey, pixelRatio: 3);
                      if (b == null) return;
                      final ok = await savePdfBytes(
                        ref,
                        await imagesToPdf([b], title: '${p.name} stamps'),
                        'stamps-$slug',
                      );
                      if (context.mounted)
                        PrismToast.show(
                          context,
                          message: ok ? 'Stamp sheet saved' : 'Not saved',
                        );
                    }),
                  ),
                  PrismButton(
                    label: 'Scrapbook image',
                    icon: Icons.collections_outlined,
                    isLoading: _busy,
                    onPressed: () => _run(() async {
                      final b = await captureBoundary(_sheetKey, pixelRatio: 2);
                      if (b == null) return;
                      final ok = await saveImageBytes(
                        ref,
                        b,
                        'scrapbook-$slug',
                      );
                      if (context.mounted)
                        PrismToast.show(
                          context,
                          message: ok ? 'Image saved' : 'Not saved',
                        );
                    }),
                  ),
                  PrismButton(
                    label: 'Memory card',
                    icon: Icons.style_outlined,
                    isLoading: _busy,
                    onPressed: () => _run(() async {
                      final b = await captureBoundary(_cardKey, pixelRatio: 3);
                      if (b == null) return;
                      final ok = await saveImageBytes(
                        ref,
                        b,
                        'memory-card-$slug',
                      );
                      if (context.mounted)
                        PrismToast.show(
                          context,
                          message: ok ? 'Card saved' : 'Not saved',
                        );
                    }),
                  ),
                  PrismButton(
                    label: 'Prism passport file',
                    icon: Icons.save_alt_outlined,
                    isLoading: _busy,
                    onPressed: () => _run(() async {
                      final json = await exportPassportJson(
                        ref,
                        p.id,
                        privacy: privacy,
                      );
                      final out = await ref
                          .read(prismFileDialogServiceProvider)
                          .saveBytes(
                            bytes: Uint8List.fromList(utf8.encode(json)),
                            suggestedName: '$slug.prismpassport',
                            allowedExtensions: const ['prismpassport', 'json'],
                            mimeType: 'application/json',
                          );
                      if (context.mounted)
                        PrismToast.show(
                          context,
                          message:
                              out.pathOrUri != null ||
                                  out.savedDisplayName != null
                              ? 'Passport file saved'
                              : 'Not saved',
                        );
                    }),
                  ),
                ],
              ),
              PrismSectionHeader(title: 'PREVIEW'),
              Center(
                child: RepaintBoundary(
                  key: _coverKey,
                  child: Container(
                    color: theme.colorScheme.surface,
                    padding: const EdgeInsets.all(16),
                    child: PassportCoverView(
                      cover: p.cover,
                      name: p.name,
                      subtitle: p.subtitle,
                      width: 220,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RepaintBoundary(
                key: _introKey,
                child: _IntroSnapshot(passport: p),
              ),
              for (final pg in pages) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: !_skip.contains(pg.id),
                      onChanged: (v) => setState(
                        () =>
                            v == true ? _skip.remove(pg.id) : _skip.add(pg.id),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Include “${pg.title}”',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                RepaintBoundary(
                  key: _pageKeys[pg.id],
                  child: IgnorePointer(
                    child: PassportPageView(passport: p, page: pg),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Stamp sheet', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              RepaintBoundary(
                key: _sheetKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: stamps.isEmpty
                      ? const Text('No stamps yet.')
                      : Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final s in stamps)
                              StampInstanceView(stamp: s, size: 96),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Memory card', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Center(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Color(p.paper),
                      borderRadius: prismCorners(context, 18),
                    ),
                    child: Column(
                      children: [
                        PassportCoverView(
                          cover: p.cover,
                          name: p.name,
                          width: 110,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${stamps.length} memories collected',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color.lerp(
                              Color(p.paper),
                              Colors.black,
                              0.8,
                            ),
                            fontFamily: fontFamilyFor(p.cover.font),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final s in stamps.reversed.take(6))
                              StampInstanceView(stamp: s, size: 70),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroSnapshot extends ConsumerWidget {
  const _IntroSnapshot({required this.passport});
  final Passport passport;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = PrivacyScope.of(context);
    final ink = Color.lerp(Color(passport.paper), Colors.black, 0.78)!;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: PaperBackground(
        color: passport.paper,
        texture: passport.texture,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                privacy.text(passport.name),
                style: TextStyle(
                  color: ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: fontFamilyFor(passport.cover.font),
                ),
              ),
              if (passport.subtitle.isNotEmpty)
                Text(
                  privacy.text(passport.subtitle),
                  style: TextStyle(color: ink.withValues(alpha: 0.8)),
                ),
              const SizedBox(height: 12),
              if (passport.intro.isNotEmpty && !privacy.notes)
                Text(
                  privacy.text(passport.intro),
                  style: TextStyle(color: ink, height: 1.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A passport, its pages, elements and stamps as JSON. Uploaded pictures
/// are referenced by id (they come along with a full Prism backup).
Future<String> exportPassportJson(
  WidgetRef ref,
  String passportId, {
  PassportPrivacy privacy = PassportPrivacy.none,
}) async {
  final p = ref.read(passportByIdProvider(passportId))!;
  final pages = ref.read(passportPagesProvider(passportId));
  Map<String, Object?> rec(TrackerRecord r) => {
    'id': r.id,
    'kind': r.kind,
    'parentId': r.parentId,
    'title': privacy.text(r.title),
    'body': privacy.notes ? '' : privacy.text(r.body ?? ''),
    'occurredAt': privacy.dates ? null : r.occurredAt?.toIso8601String(),
    'sortOrder': r.sortOrder,
    'fields': r.fields,
  };
  return const JsonEncoder.withIndent(' ').convert({
    'format': 'prism.passport',
    'version': passportSchemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'passport': rec(p.r),
    'pages': [for (final pg in pages) rec(pg.r)],
    'elements': [
      for (final pg in pages)
        for (final e in ref.read(pageElementsProvider(pg.id))) rec(e.r),
    ],
    'stamps': [
      for (final s in ref.read(passportStampsProvider(passportId))) rec(s.r),
    ],
  });
}

/// Imports a .prismpassport file as a new passport (fresh ids, so it never
/// overwrites anything).
Future<void> importPassportFile(BuildContext context, WidgetRef ref) async {
  final res = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['prismpassport', 'json'],
    withData: true,
  );
  final bytes = res?.files.firstOrNull?.bytes;
  if (bytes == null) return;
  try {
    final j = jsonDecode(utf8.decode(bytes)) as Map;
    if (j['format'] != 'prism.passport')
      throw const FormatException('not a passport');
    final t = ref.read(trackerNotifierProvider.notifier);
    final idMap = <String, String>{};
    Future<String> make(Map r, String kind, {String? parent}) async {
      final created = await t.create(
        kind: kind,
        parentId: parent,
        title: '${r['title'] ?? ''}',
        body: '${r['body'] ?? ''}',
        occurredAt: DateTime.tryParse('${r['occurredAt'] ?? ''}'),
        sortOrder: (r['sortOrder'] as num?)?.toInt() ?? 0,
        fields: ((r['fields'] as Map?) ?? const {}).cast<String, Object?>(),
      );
      idMap['${r['id']}'] = created.id;
      return created.id;
    }

    final pid = await make(j['passport'] as Map, TrackerKind.passport);
    for (final s in (j['stamps'] as List? ?? const [])) {
      await make(s as Map, TrackerKind.passportStamp, parent: pid);
    }
    for (final pg in (j['pages'] as List? ?? const [])) {
      await make(pg as Map, TrackerKind.passportPage, parent: pid);
    }
    for (final e in (j['elements'] as List? ?? const [])) {
      final m = e as Map;
      final fields = ((m['fields'] as Map?) ?? const {})
          .cast<String, Object?>();
      final stamp = fields['stamp'];
      await t.create(
        kind: TrackerKind.passportElement,
        parentId: idMap['${m['parentId']}'],
        body: '${m['body'] ?? ''}',
        sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
        fields: {...fields, if (stamp != null) 'stamp': idMap['$stamp']},
      );
    }
    if (context.mounted) PrismToast.show(context, message: 'Passport imported');
  } catch (_) {
    if (context.mounted)
      PrismToast.show(context, message: 'That file isn\'t a Prism passport.');
  }
}
