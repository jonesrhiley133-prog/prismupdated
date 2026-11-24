import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// GitHub repository ("owner/name") whose releases carry Android builds.
///
/// Set at build time by the APK workflow
/// (`--dart-define=PRISM_UPDATE_REPO=owner/name`). Builds made without it
/// (local, store, web, desktop) never check for updates.
const String kPrismUpdateRepo = String.fromEnvironment('PRISM_UPDATE_REPO');

/// Codeberg repository ("owner/name") with the same releases, used when
/// GitHub can't be reached (`--dart-define=PRISM_UPDATE_CODEBERG=owner/name`).
const String kPrismUpdateCodebergRepo = String.fromEnvironment('PRISM_UPDATE_CODEBERG');

/// Compares "a.b.c" versions; null when either can't be read.
@visibleForTesting
int? compareVersions(String a, String b) {
  List<int>? parts(String v) {
    final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(v);
    return m == null ? null : [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
  }

  final x = parts(a), y = parts(b);
  if (x == null || y == null) return null;
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}

/// A newer build published as a GitHub release.
@immutable
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.buildNumber,
    required this.version,
    required this.apkUrl,
    required this.apkName,
    required this.sizeBytes,
    this.sha256,
    this.publishedAt,
    this.pageUrl,
  });

  final int buildNumber;
  final String version;
  final String apkUrl;
  final String apkName;
  final int sizeBytes;

  /// Lowercase hex digest of the APK, when the release lists one.
  final String? sha256;
  final DateTime? publishedAt;
  final String? pageUrl;
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.code, [this.detail]);

  /// One of: `network`, `bad_response`, `no_apk`, `download_failed`,
  /// `checksum_mismatch`, `install_failed`, `unsupported`.
  final String code;
  final String? detail;

  @override
  String toString() =>
      'AppUpdateException($code${detail == null ? '' : ': $detail'})';
}

final _tagPattern = RegExp(r'^android-build-(\d+)$');
final _shaPattern = RegExp(r'sha256:\s*([0-9a-fA-F]{64})');

/// Reads a GitHub "latest release" response. Returns null when the release
/// isn't an Android build this updater understands.
@visibleForTesting
AppUpdateInfo? parseReleaseJson(Map<String, dynamic> json) {
  final tag = json['tag_name'];
  if (tag is! String) return null;
  final m = _tagPattern.firstMatch(tag);
  if (m == null) return null;
  final assets = json['assets'];
  if (assets is! List) return null;
  Map<String, dynamic>? apk;
  for (final a in assets) {
    if (a is Map<String, dynamic> &&
        a['name'] is String &&
        (a['name'] as String).toLowerCase().endsWith('.apk') &&
        a['browser_download_url'] is String) {
      apk = a;
      break;
    }
  }
  if (apk == null) return null;
  final body = json['body'] is String ? json['body'] as String : '';
  final name = json['name'] is String ? json['name'] as String : '';
  final version = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(name)?.group(1) ?? '';
  return AppUpdateInfo(
    buildNumber: int.parse(m.group(1)!),
    version: version,
    apkUrl: apk['browser_download_url'] as String,
    apkName: apk['name'] as String,
    sizeBytes: apk['size'] is int ? apk['size'] as int : 0,
    sha256: _shaPattern.firstMatch(body)?.group(1)?.toLowerCase(),
    publishedAt: json['published_at'] is String
        ? DateTime.tryParse(json['published_at'] as String)
        : null,
    pageUrl: json['html_url'] is String ? json['html_url'] as String : null,
  );
}

/// Checks GitHub for newer APKs, downloads them and hands them to the
/// Android installer. Android always asks the user to confirm the install;
/// because every build is signed with the same key, it installs over the
/// current app and keeps all data.
class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    this.repo = kPrismUpdateRepo,
    this.codebergRepo = kPrismUpdateCodebergRepo,
    MethodChannel? channel,
    Future<int> Function()? currentBuild,
    Future<String> Function()? currentVersion,
    Future<Directory> Function()? cacheDir,
  }) : _client = client ?? http.Client(),
       _channel =
           channel ?? const MethodChannel('com.prismplural.prism/app_update'),
       _currentBuild = currentBuild ?? _packageBuild,
       _currentVersion = currentVersion ?? _packageVersion,
       _cacheDir = cacheDir ?? getTemporaryDirectory;

  final http.Client _client;
  final String repo;
  final String codebergRepo;
  final MethodChannel _channel;
  final Future<int> Function() _currentBuild;
  final Future<String> Function() _currentVersion;
  final Future<Directory> Function() _cacheDir;

  static Future<int> _packageBuild() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

  static Future<String> _packageVersion() async => (await PackageInfo.fromPlatform()).version;

  bool get _hasSource => repo.contains('/') || codebergRepo.contains('/');

  /// True on Android builds that were told where updates live.
  bool get isSupported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _hasSource;

  Future<int> currentBuildNumber() => _currentBuild();

  /// Returns the newest release, or null when this build is current.
  ///
  /// Reads the recent releases and picks the highest build number rather
  /// than trusting GitHub's "latest" flag: builds from different branches
  /// can finish out of order, and the one marked latest is not always the
  /// newest.
  Future<AppUpdateInfo?> checkForUpdate() async {
    if (!_hasSource) throw const AppUpdateException('unsupported');
    List<AppUpdateInfo>? candidates;
    AppUpdateException? firstError;
    // GitHub first, then Codeberg if GitHub is unreachable, rate-limited or
    // has nothing for us.
    for (final source in [
      if (repo.contains('/')) Uri.https('api.github.com', '/repos/$repo/releases', {'per_page': '15'}),
      if (codebergRepo.contains('/')) Uri.https('codeberg.org', '/api/v1/repos/$codebergRepo/releases', {'limit': '15'}),
    ]) {
      try {
        final found = await _readReleases(source);
        if (found.isNotEmpty) {
          candidates = found;
          break;
        }
        candidates ??= found;
      } on AppUpdateException catch (e) {
        firstError ??= e;
      }
    }
    if (candidates == null) throw firstError ?? const AppUpdateException('network');
    if (candidates.isEmpty) return null;
    final current = await _currentBuild();
    String currentVersion;
    try {
      currentVersion = await _currentVersion();
    } catch (_) {
      currentVersion = '';
    }
    // Newest build first, but never offer an older app version: builds
    // from different branches share one build counter.
    candidates.sort((a, b) => b.buildNumber.compareTo(a.buildNumber));
    for (final c in candidates) {
      if (c.buildNumber <= current) return null;
      final cmp = compareVersions(c.version, currentVersion);
      if (cmp == null || cmp >= 0) return c;
    }
    return null;
  }

  /// Reads one releases list (GitHub and Codeberg/Gitea return the same
  /// shape). Returns an empty list when the repository has no releases.
  Future<List<AppUpdateInfo>> _readReleases(Uri url) async {
    final http.Response res;
    try {
      res = await _client
          .get(url, headers: const {'Accept': 'application/json', 'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 20));
    } on Exception catch (e) {
      throw AppUpdateException('network', '$e');
    }
    if (res.statusCode == 404) return const []; // No releases (or not public).
    if (res.statusCode == 403 || res.statusCode == 429) {
      throw AppUpdateException('rate_limited', 'HTTP ${res.statusCode}');
    }
    if (res.statusCode != 200) {
      throw AppUpdateException('bad_response', 'HTTP ${res.statusCode}');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } on FormatException catch (e) {
      throw AppUpdateException('bad_response', e.message);
    }
    return <AppUpdateInfo>[
      if (decoded is List)
        for (final r in decoded)
          if (r is Map<String, dynamic> && r['draft'] != true && r['prerelease'] != true) ?parseReleaseJson(r),
      if (decoded is Map<String, dynamic>) ?parseReleaseJson(decoded),
    ];
  }

  /// Downloads the APK into the cache, reporting progress from 0 to 1, and
  /// verifies its checksum. Returns the file path.
  ///
  /// Interrupted downloads resume where they stopped (HTTP range requests),
  /// both automatically on a dropped connection and on the next attempt,
  /// so a large update never has to start over.
  Future<String> download(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
    int maxAttempts = 4,
  }) async {
    final dir = Directory('${(await _cacheDir()).path}/updates');
    dir.createSync(recursive: true);
    final name = 'prism-update-${info.buildNumber}.apk';
    final file = File('${dir.path}/$name');
    final partial = File('${file.path}.part');
    // Clear files from other (older) updates, keep this one's partial.
    for (final f in dir.listSync()) {
      final base = f.uri.pathSegments.isEmpty ? '' : f.uri.pathSegments.last;
      if (base != name && base != '$name.part') {
        try {
          f.deleteSync(recursive: true);
        } on FileSystemException {
          // In use; leave it.
        }
      }
    }
    if (file.existsSync() && await _verify(file, info)) {
      onProgress?.call(1);
      return file.path;
    }
    if (file.existsSync()) file.deleteSync();

    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) await Future<void>.delayed(Duration(seconds: 2 * attempt));
      try {
        final done = await _downloadOnce(info, partial, onProgress);
        if (done) break;
      } on AppUpdateException catch (e) {
        lastError = e;
        // A server that rejects the range (or a corrupt partial): start over.
        if (e.code == 'restart') {
          if (partial.existsSync()) partial.deleteSync();
          continue;
        }
        if (e.code != 'network' && e.code != 'download_failed') rethrow;
      }
      if (attempt == maxAttempts - 1) {
        throw lastError is AppUpdateException ? lastError : const AppUpdateException('download_failed');
      }
    }
    partial.renameSync(file.path);
    if (!await _verify(file, info)) {
      file.deleteSync();
      throw const AppUpdateException('checksum_mismatch');
    }
    onProgress?.call(1);
    return file.path;
  }

  /// One request; returns true when the file is complete.
  Future<bool> _downloadOnce(AppUpdateInfo info, File partial, void Function(double)? onProgress) async {
    final have = partial.existsSync() ? partial.lengthSync() : 0;
    if (info.sizeBytes > 0 && have == info.sizeBytes) return true;
    if (info.sizeBytes > 0 && have > info.sizeBytes) throw const AppUpdateException('restart');
    final req = http.Request('GET', Uri.parse(info.apkUrl));
    if (have > 0) req.headers['Range'] = 'bytes=$have-';
    final http.StreamedResponse res;
    try {
      res = await _client.send(req).timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      throw AppUpdateException('network', '$e');
    }
    final resumed = res.statusCode == 206;
    if (have > 0 && res.statusCode == 200) {
      // Server ignored the range: drain and restart from the beginning.
      await res.stream.drain<void>();
      throw const AppUpdateException('restart');
    }
    if (res.statusCode == 416) throw const AppUpdateException('restart');
    if (res.statusCode != 200 && !resumed) {
      throw AppUpdateException('download_failed', 'HTTP ${res.statusCode}');
    }
    final total = info.sizeBytes > 0 ? info.sizeBytes : (resumed ? have + (res.contentLength ?? 0) : (res.contentLength ?? 0));
    final sink = partial.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    var received = resumed ? have : 0;
    try {
      await for (final chunk in res.stream.timeout(const Duration(seconds: 45))) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call((received / total).clamp(0, 1).toDouble());
      }
      await sink.flush();
    } on Exception catch (e) {
      await sink.close();
      throw AppUpdateException('network', '$e');
    }
    await sink.close();
    if (total > 0 && received < total) throw const AppUpdateException('network', 'incomplete');
    return true;
  }

  Future<bool> _verify(File file, AppUpdateInfo info) async {
    if (info.sizeBytes > 0 && file.lengthSync() != info.sizeBytes) return false;
    final expected = info.sha256;
    if (expected == null) return true;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expected;
  }

  /// Whether Android lets Prism open the installer ("Install unknown apps").
  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstallPackages') ?? false;

  Future<void> openInstallPermissionSettings() =>
      _channel.invokeMethod<bool>('openInstallPermissionSettings');

  Future<void> install(String path) async {
    try {
      await _channel.invokeMethod<bool>('installApk', {'path': path});
    } on PlatformException catch (e) {
      throw AppUpdateException('install_failed', e.message);
    }
  }
}


