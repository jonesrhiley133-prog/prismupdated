import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/features/dictionary/importer/wiki_providers.dart';
import 'package:prism_plurality/features/dictionary/utils/dictionary_import.dart';
import 'package:prism_plurality/features/dictionary/views/dictionary_import_flow.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Where a wiki import job is.
enum ImportJobStatus { idle, listing, fetching, paused, ready, importing, done, error }

bool isRunningStatus(ImportJobStatus s) => s == ImportJobStatus.listing || s == ImportJobStatus.fetching || s == ImportJobStatus.importing;

/// A fetched article plus whether it will be imported.
class ImportItem {
  ImportItem(this.a, {this.selected = true});
  WikiArticle a;
  bool selected;
  Map<String, Object?> toJson() => {...a.toJson(), 'sel': selected};
  static ImportItem fromJson(Map<String, Object?> j) => ImportItem(WikiArticle.fromJson(j), selected: j['sel'] != false);
}

/// Options chosen before (or while) importing.
class ImportOptions {
  ImportOptions({this.limit = 200, this.fullText = false, this.autoImport = true, this.useCategories = true, this.collection, this.dup = TermDuplicateAction.skip});
  int limit; // wikiNoLimit = all
  bool fullText;
  bool autoImport;
  bool useCategories;
  String? collection;
  TermDuplicateAction dup;

  Map<String, Object?> toJson() => {'limit': limit, 'fullText': fullText, 'autoImport': autoImport, 'useCategories': useCategories, 'collection': collection, 'dup': dup.name};
  static ImportOptions fromJson(Map<String, Object?> j) => ImportOptions(
    limit: (j['limit'] as num?)?.toInt() ?? 200,
    fullText: j['fullText'] == true,
    autoImport: j['autoImport'] != false,
    useCategories: j['useCategories'] != false,
    collection: j['collection'] as String?,
    dup: TermDuplicateAction.values.where((d) => d.name == j['dup']).firstOrNull ?? TermDuplicateAction.skip,
  );
}

/// The one wiki import that can run at a time. It lives outside any screen:
/// leaving Dictionary or putting Prism in the background doesn't stop it,
/// and it's saved to disk so it carries on after Prism restarts.
class ImportJob {
  ImportJobStatus status = ImportJobStatus.idle;
  String? input; // link the person pasted (to rebuild the provider)
  String? providerId;
  String sourceLabel = '';
  WikiScope? scope;
  String? category;
  List<String> titles = [];
  int next = 0;
  final items = <ImportItem>[];
  final failed = <String>[];
  String? errorCode;
  ImportOptions options = ImportOptions();
  Map<String, Object?>? result; // counts after importing
  DateTime? updatedAt;

  int get total => titles.length;
  int get done => next.clamp(0, titles.length);
  bool get hasWork => status != ImportJobStatus.idle;

  Map<String, Object?> toJson() => {
    'v': 1,
    'status': status.name,
    'input': input,
    'providerId': providerId,
    'sourceLabel': sourceLabel,
    'scope': scope?.name,
    'category': category,
    'titles': titles,
    'next': next,
    'items': [for (final i in items) i.toJson()],
    'failed': failed,
    'error': errorCode,
    'options': options.toJson(),
    'result': result,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  static ImportJob fromJson(Map<String, Object?> j) {
    final job = ImportJob()
      ..status = ImportJobStatus.values.where((s) => s.name == j['status']).firstOrNull ?? ImportJobStatus.idle
      ..input = j['input'] as String?
      ..providerId = j['providerId'] as String?
      ..sourceLabel = '${j['sourceLabel'] ?? ''}'
      ..scope = WikiScope.values.where((s) => s.name == j['scope']).firstOrNull
      ..category = j['category'] as String?
      ..titles = [for (final t in (j['titles'] as List?) ?? const []) '$t']
      ..next = (j['next'] as num?)?.toInt() ?? 0
      ..errorCode = j['error'] as String?
      ..options = ImportOptions.fromJson(((j['options'] as Map?) ?? const {}).cast<String, Object?>())
      ..result = (j['result'] as Map?)?.cast<String, Object?>()
      ..updatedAt = DateTime.tryParse('${j['updatedAt'] ?? ''}');
    job.items.addAll([for (final i in (j['items'] as List?) ?? const []) if (i is Map) ImportItem.fromJson(i.cast<String, Object?>())]);
    job.failed.addAll([for (final f in (j['failed'] as List?) ?? const []) '$f']);
    return job;
  }
}

/// Android progress notification + keep-alive while a job runs.
class BackgroundWorkPlatform {
  const BackgroundWorkPlatform();
  static const _ch = MethodChannel('com.prismplural.prism/background_work');
  bool get _supported => !kIsWeb && Platform.isAndroid;

  Future<void> update({required String title, required String text, int progress = 0, int max = 0}) async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod('update', {'title': title, 'text': text, 'progress': progress, 'max': max, 'channelName': 'Imports and background tasks'});
    } catch (_) {}
  }

  Future<void> finish({String? title, String? text}) async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod('finish', {'title': title, 'text': text});
    } catch (_) {}
  }
}

final backgroundWorkPlatformProvider = Provider<BackgroundWorkPlatform>((ref) => const BackgroundWorkPlatform());

/// Overridable for tests.
final wikiHttpProvider = Provider<WikiHttp>((ref) => WikiHttp());

/// Where the job is saved (overridable for tests).
final importJobFileProvider = Provider<Future<File?> Function()>((ref) => () async {
  if (kIsWeb) return null;
  try {
    return File('${(await getApplicationSupportDirectory()).path}/dictionary_import_job.json');
  } catch (_) {
    return null;
  }
});

String _encode(Map<String, Object?> j) => jsonEncode(j);
Map<String, Object?> _decode(String s) => (jsonDecode(s) as Map).cast<String, Object?>();

/// Runs and remembers the wiki import. UI watches [ImportJobState.version].
class ImportJobNotifier extends Notifier<int> {
  ImportJob job = ImportJob();
  WikiProvider? _provider;
  WikiRequest? _request;
  bool _cancel = false;
  bool _loaded = false;
  Timer? _notifyTimer;
  DateTime _lastSave = DateTime(2000);
  Future<void>? _saving;

  WikiProvider? get provider => _provider;
  WikiRequest? get request => _request;

  @override
  int build() {
    ref.onDispose(() => _notifyTimer?.cancel());
    unawaited(_load());
    return 0;
  }

  /// UI updates at most ~4×/s, so long imports never make scrolling janky.
  void _changed({bool now = false}) {
    if (now) {
      _notifyTimer?.cancel();
      _notifyTimer = null;
      if (ref.mounted) state++;
      return;
    }
    _notifyTimer ??= Timer(const Duration(milliseconds: 250), () {
      _notifyTimer = null;
      if (ref.mounted) state++;
    });
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await ref.read(importJobFileProvider)();
      if (f == null || !await f.exists()) return;
      final raw = await f.readAsString();
      job = ImportJob.fromJson(await compute(_decode, raw));
      _changed(now: true);
      // Carry on where the import stopped (app closed or killed).
      if (isRunningStatus(job.status)) unawaited(resume());
    } catch (e) {
      debugPrint('Import job: could not load saved job: $e');
    }
  }

  /// Ensures the saved job has been read (screens call this on open).
  Future<void> ready() => _load();

  Future<void> _save({bool force = false}) async {
    if (!ref.mounted) return;
    if (!force && DateTime.now().difference(_lastSave) < const Duration(seconds: 3)) return;
    _lastSave = DateTime.now();
    final prev = _saving;
    final f = await ref.read(importJobFileProvider)();
    if (f == null) return;
    job.updatedAt = DateTime.now();
    final snapshot = job.toJson();
    _saving = () async {
      await prev;
      try {
        // Encode off the UI thread: big wikis produce megabytes of JSON.
        final text = await compute(_encode, snapshot);
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(text, flush: true);
        await tmp.rename(f.path);
      } catch (e) {
        debugPrint('Import job: could not save: $e');
      }
    }();
    await _saving;
  }

  WikiHttp get _http => ref.read(wikiHttpProvider);

  /// Detects the platform for a pasted link and starts a new job.
  Future<void> detect(String input) async {
    if (isRunningStatus(job.status)) return;
    final keepOptions = job.options;
    job = ImportJob()
      ..input = input.trim()
      ..options = keepOptions
      ..status = ImportJobStatus.listing;
    _changed(now: true);
    try {
      final (p, r) = await detectProvider(_http, job.input!);
      _provider = p;
      _request = r;
      job
        ..providerId = p.id
        ..scope = r.scope
        ..category = r.category
        ..sourceLabel = '${p.name} · ${r.uri.host}';
      if (r.scope == WikiScope.article) {
        job.titles = [r.page!];
        await _fetchLoop();
      } else {
        job.status = ImportJobStatus.idle;
        _changed(now: true);
      }
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object e) {
    if (!ref.mounted) return;
    job
      ..status = ImportJobStatus.error
      ..errorCode = e is WikiImportError ? e.code : 'network';
    _changed(now: true);
    unawaited(_save(force: true));
    unawaited(ref.read(backgroundWorkPlatformProvider).finish());
  }

  Future<void> _ensureProvider() async {
    if (_provider != null && _request != null) return;
    final input = job.input;
    if (input == null) throw const WikiImportError('not_a_url');
    final (p, r) = await detectProvider(_http, input);
    _provider = p;
    _request = r;
  }

  /// Lists the category/wiki pages (all of them, or up to the chosen limit)
  /// and fetches them.
  Future<void> listAndFetch() async {
    if (isRunningStatus(job.status)) return;
    job
      ..status = ImportJobStatus.listing
      ..errorCode = null
      ..result = null;
    _cancel = false;
    _changed(now: true);
    await _notify();
    try {
      await _ensureProvider();
      job.titles = await _provider!.listTitles(_http, _request!, limit: job.options.limit);
      if (!ref.mounted) return;
      job.next = 0;
      await _save(force: true);
      await _fetchLoop();
    } catch (e) {
      _fail(e);
    }
  }

  /// Fetches extra article links (one per line).
  Future<void> fetchLinks(List<String> urls) async {
    if (isRunningStatus(job.status) || urls.isEmpty) return;
    for (final u in urls) {
      try {
        final (p, r) = await detectProvider(_http, u);
        _provider = p;
        _request = r;
        job
          ..input ??= u
          ..providerId = p.id
          ..sourceLabel = job.sourceLabel.isEmpty ? '${p.name} · ${r.uri.host}' : job.sourceLabel
          ..titles = [...job.titles.take(job.next), r.page ?? u, ...job.titles.skip(job.next)];
      } catch (_) {
        job.failed.add(u);
      }
    }
    await _fetchLoop();
  }

  /// Re-fetches specific titles from a wiki (e.g. failed ones from history).
  Future<void> fetchTitlesFrom(String origin, List<String> titles) async {
    if (isRunningStatus(job.status) || titles.isEmpty) return;
    final keep = job.options;
    job = ImportJob()
      ..input = origin
      ..options = keep
      ..titles = [...titles];
    try {
      _provider = null;
      _request = null;
      await _ensureProvider();
      job
        ..providerId = _provider!.id
        ..sourceLabel = '${_provider!.name} · ${_request!.uri.host}';
    } catch (e) {
      _fail(e);
      return;
    }
    await _fetchLoop();
  }

  /// Continues a paused, interrupted or failed job.
  Future<void> resume() async {
    if (job.status == ImportJobStatus.importing) {
      await importNow();
      return;
    }
    if (job.titles.isEmpty && job.scope != null && job.scope != WikiScope.article && job.items.isEmpty) {
      job.status = ImportJobStatus.idle;
      await listAndFetch();
      return;
    }
    try {
      await _ensureProvider();
    } catch (e) {
      _fail(e);
      return;
    }
    await _fetchLoop();
  }

  void pause() {
    if (job.status != ImportJobStatus.fetching && job.status != ImportJobStatus.listing) return;
    _cancel = true;
  }

  /// Retries articles that couldn't be read.
  Future<void> retryFailed() async {
    if (isRunningStatus(job.status) || job.failed.isEmpty) return;
    final again = [...job.failed];
    job.failed.clear();
    job.titles = [...job.titles.take(job.next), ...again];
    try {
      await _ensureProvider();
    } catch (e) {
      _fail(e);
      return;
    }
    await _fetchLoop();
  }

  Future<void> _notify({String? text}) async {
    if (!ref.mounted) return;
    await ref.read(backgroundWorkPlatformProvider).update(
    title: job.status == ImportJobStatus.listing ? 'Finding articles to import…' : 'Importing into Dictionary',
    text: text ?? (job.total == 0 ? job.sourceLabel : '${job.done} of ${job.total} · ${job.sourceLabel}'),
      progress: job.done,
      max: job.total,
    );
  }

  Future<void> _fetchLoop() async {
    final p = _provider, r = _request;
    if (p == null || r == null) return;
    _cancel = false;
    job
      ..status = ImportJobStatus.fetching
      ..errorCode = null;
    _changed(now: true);
    await _notify();
    final have = {for (final i in job.items) i.a.title.toLowerCase()};
    final step = job.options.fullText ? 1 : p.batchSize;
    while (job.next < job.titles.length) {
      if (_cancel) {
        job.status = ImportJobStatus.paused;
        _changed(now: true);
        await _save(force: true);
        await ref.read(backgroundWorkPlatformProvider).finish();
        return;
      }
      final batch = job.titles.sublist(job.next, (job.next + step).clamp(0, job.titles.length));
      try {
        final got = await p.fetchArticles(_http, r, batch, fullText: job.options.fullText);
        // Prism shut down mid-request: the saved job resumes next time.
        if (!ref.mounted) return;
        for (final a in got) {
          if (!a.ok) {
            if (!job.failed.contains(a.title)) job.failed.add(a.title);
            continue;
          }
          job.failed.remove(a.title);
          if (have.add(a.title.toLowerCase())) job.items.add(ImportItem(a));
        }
        job.next += batch.length;
      } on WikiImportError catch (e) {
        if (e.code == 'blocked_by_robots' || e.code == 'auth_required' || e.code == 'rate_limited') {
          _fail(e);
          return;
        }
        for (final t in batch) {
          if (!job.failed.contains(t)) job.failed.add(t);
        }
        job.next += batch.length;
      } catch (_) {
        if (!ref.mounted) return;
        // Offline or a hiccup: pause and keep our place.
        job
          ..status = ImportJobStatus.error
          ..errorCode = 'network';
        _changed(now: true);
        await _save(force: true);
        await ref.read(backgroundWorkPlatformProvider).finish();
        return;
      }
      _changed();
      unawaited(_save());
      unawaited(_notify());
    }
    job.status = ImportJobStatus.ready;
    _changed(now: true);
    await _save(force: true);
    if (job.options.autoImport && job.items.any((i) => i.selected && i.a.ok)) {
      await importNow();
    } else {
      await ref.read(backgroundWorkPlatformProvider).finish(title: 'Ready to import', text: '${job.items.length} terms from ${job.sourceLabel}. Open Dictionary to review them.');
    }
  }

  /// Adds the selected articles to the dictionary.
  Future<DictionaryImportResult?> importNow({String? method}) async {
    final chosen = job.items.where((i) => i.selected && i.a.ok).toList();
    if (chosen.isEmpty) return null;
    job.status = ImportJobStatus.importing;
    _changed(now: true);
    await _save(force: true);
    await ref.read(backgroundWorkPlatformProvider).update(title: 'Adding terms to Dictionary', text: '${chosen.length} terms', max: 0);
    try {
      final all = await ref.read(trackerRecordRepositoryProvider).getAll();
      final terms = [for (final t in all) if (t.kind == TrackerKind.dictTerm) t];
      final cols = [for (final t in all) if (t.kind == TrackerKind.dictCollection) t];
      final notifier = ref.read(trackerNotifierProvider.notifier);
      final cands = [for (final (i, it) in chosen.indexed) it.a.toCandidate(i)];
      final extra = {
        for (final (i, it) in chosen.indexed)
          'a$i': {
            'categories': it.a.categories.isEmpty ? null : it.a.categories,
            'images': it.a.images.isEmpty ? null : it.a.images,
            'flags': it.a.flags.isEmpty ? null : [for (final f in it.a.flags) f.toJson()],
            'references': it.a.references.isEmpty ? null : it.a.references.take(20).toList(),
            'updated': it.a.updated?.toIso8601String(),
            'license': it.a.license,
            'fullText': job.options.fullText && it.a.content.length > it.a.summary.length ? it.a.content : null,
            DictField.description: null,
          },
      };
      final r = await importTerms(
        notifier: notifier,
        chosen: cands,
        existingTerms: terms,
        existingCollections: cols,
        actionFor: (_) => job.options.dup,
        collectionId: job.options.useCategories ? null : job.options.collection,
        useSourceCategories: job.options.useCategories,
        extraFields: extra,
      );
      await notifier.create(
        kind: TrackerKind.dictImport,
        title: job.sourceLabel,
        occurredAt: DateTime.now(),
        fields: {
          'method': method ?? 'url',
          'provider': job.providerId,
          'origin': _request?.origin ?? (job.input == null ? null : Uri.tryParse(job.input!)?.origin),
          'found': job.items.length + job.failed.length,
          'imported': r.created,
          'replaced': r.replaced,
          'skipped': r.skipped + job.items.where((i) => !i.selected).length,
          'failed': job.failed.length,
          'failedTitles': job.failed.isEmpty ? null : job.failed.take(200).toList(),
          'status': job.failed.isEmpty ? 'done' : 'partial',
          'termIds': r.ids,
        },
      );
      job
        ..status = ImportJobStatus.done
        ..result = {'created': r.created, 'replaced': r.replaced, 'skipped': r.skipped, 'failed': job.failed.length}
        ..items.clear();
      _changed(now: true);
      await _save(force: true);
      await ref.read(backgroundWorkPlatformProvider).finish(title: 'Dictionary import finished', text: 'Added ${r.created} · updated ${r.replaced} · skipped ${r.skipped}');
      return r;
    } catch (e) {
      job
        ..status = ImportJobStatus.ready
        ..errorCode = 'import_failed';
      _changed(now: true);
      await _save(force: true);
      await ref.read(backgroundWorkPlatformProvider).finish();
      rethrow;
    }
  }

  /// Adds articles parsed from a file, API or pasted text to the review list.
  void addArticles(List<WikiArticle> list, {required String label}) {
    if (isRunningStatus(job.status)) return;
    if (job.status == ImportJobStatus.done || job.status == ImportJobStatus.error) {
      final keep = job.options;
      job = ImportJob()..options = keep;
    }
    job
      ..sourceLabel = job.sourceLabel.isEmpty ? label : job.sourceLabel
      ..status = ImportJobStatus.ready;
    job.items.addAll([for (final a in list) ImportItem(a, selected: a.ok)]);
    _changed(now: true);
    unawaited(_save(force: true));
  }

  /// Toggles one item (or all) without rebuilding everything at once.
  void select(ImportItem it, bool v) {
    it.selected = v;
    _changed();
    unawaited(_save());
  }

  void selectAll(bool v) {
    for (final i in job.items) {
      if (i.a.ok) i.selected = v;
    }
    _changed(now: true);
    unawaited(_save());
  }

  void edited() {
    _changed(now: true);
    unawaited(_save(force: true));
  }

  void setOptions(void Function(ImportOptions o) f) {
    f(job.options);
    _changed(now: true);
    unawaited(_save(force: true));
  }

  /// Stops and forgets the job.
  Future<void> discard() async {
    _cancel = true;
    final keep = job.options;
    job = ImportJob()..options = keep;
    _provider = null;
    _request = null;
    _changed(now: true);
    await _save(force: true);
    await ref.read(backgroundWorkPlatformProvider).finish();
  }
}

final importJobProvider = NotifierProvider<ImportJobNotifier, int>(ImportJobNotifier.new);
