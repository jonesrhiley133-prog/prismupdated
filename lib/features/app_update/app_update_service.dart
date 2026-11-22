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

/// GitLab host and numeric project id whose package registry carries
/// Android builds (`prism-android/latest/latest.json`), set by GitLab CI.
/// Preferred over [kPrismUpdateRepo] when present.
const String kPrismUpdateGitlabHost = String.fromEnvironment(
  'PRISM_UPDATE_GITLAB_HOST',
);
const String kPrismUpdateGitlabProject = String.fromEnvironment(
  'PRISM_UPDATE_GITLAB_PROJECT',
);

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
  /// `checksum_mismatch`, `install_failed`, `unsupported`, `not_public`
  /// (the GitLab package registry needs signing in), `signature_mismatch`
  /// (signed with another key: Android would refuse to update), and
  /// `older_build` (not newer than the installed app).
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

/// Reads the `latest.json` GitLab CI publishes next to each APK.
@visibleForTesting
AppUpdateInfo? parseGitlabManifest(Map<String, dynamic> json, {String? pageUrl}) {
  final build = json['build'];
  final apk = json['apk'];
  if (build is! int || apk is! String || !apk.startsWith('https://')) return null;
  final sum = json['sha256'];
  return AppUpdateInfo(
    buildNumber: build,
    version: json['version'] is String ? json['version'] as String : '',
    apkUrl: apk,
    apkName: 'Prism-$build.apk',
    sizeBytes: json['size'] is int ? json['size'] as int : 0,
    sha256: sum is String && RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sum)
        ? sum.toLowerCase()
        : null,
    publishedAt: json['published'] is String
        ? DateTime.tryParse(json['published'] as String)
        : null,
    pageUrl: pageUrl,
  );
}

/// Checks GitLab (or GitHub) for newer APKs, downloads them and hands them to the
/// Android installer. Android always asks the user to confirm the install;
/// because every build is signed with the same key, it installs over the
/// current app and keeps all data.
class AppUpdateService {
  AppUpdateService({
    http.Client? client,
    this.repo = kPrismUpdateRepo,
    this.gitlabHost = kPrismUpdateGitlabHost,
    this.gitlabProject = kPrismUpdateGitlabProject,
    MethodChannel? channel,
    Future<int> Function()? currentBuild,
    Future<Directory> Function()? cacheDir,
  }) : _client = client ?? http.Client(),
       _channel =
           channel ?? const MethodChannel('com.prismplural.prism/app_update'),
       _currentBuild = currentBuild ?? _packageBuild,
       _cacheDir = cacheDir ?? getTemporaryDirectory;

  final http.Client _client;
  final String repo;
  final String gitlabHost;
  final String gitlabProject;
  final MethodChannel _channel;

  bool get _usesGitlab => gitlabHost.isNotEmpty && gitlabProject.isNotEmpty;
  final Future<int> Function() _currentBuild;
  final Future<Directory> Function() _cacheDir;

  static Future<int> _packageBuild() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

  /// True on Android builds that were told where updates live.
  bool get isSupported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      (_usesGitlab || repo.contains('/'));

  Future<int> currentBuildNumber() => _currentBuild();

  /// Returns the newest release, or null when this build is current.
  ///
  /// Reads the recent releases and picks the highest build number rather
  /// than trusting GitHub's "latest" flag: builds from different branches
  /// can finish out of order, and the one marked latest is not always the
  /// newest.
  Future<AppUpdateInfo?> checkForUpdate() async {
    if (_usesGitlab) return _checkGitlab();
    if (!repo.contains('/')) throw const AppUpdateException('unsupported');
    final http.Response res;
    try {
      res = await _client
          .get(
            Uri.https('api.github.com', '/repos/$repo/releases', {'per_page': '15'}),
            headers: const {'Accept': 'application/vnd.github+json', 'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 20));
    } on Exception catch (e) {
      throw AppUpdateException('network', '$e');
    }
    if (res.statusCode == 404) return null; // No releases yet.
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
    final candidates = <AppUpdateInfo>[
      if (decoded is List)
        for (final r in decoded)
          if (r is Map<String, dynamic> && r['draft'] != true && r['prerelease'] != true) ?parseReleaseJson(r),
      if (decoded is Map<String, dynamic>) ?parseReleaseJson(decoded),
    ];
    if (candidates.isEmpty) throw const AppUpdateException('no_apk');
    candidates.sort((a, b) => b.buildNumber.compareTo(a.buildNumber));
    final newest = candidates.first;
    final current = await _currentBuild();
    return newest.buildNumber > current ? newest : null;
  }

  Future<AppUpdateInfo?> _checkGitlab() async {
    final url = Uri.https(
      gitlabHost,
      '/api/v4/projects/$gitlabProject/packages/generic/prism-android/latest/latest.json',
    );
    final http.Response res;
    try {
      res = await _client
          .get(url, headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 20));
    } on Exception catch (e) {
      throw AppUpdateException('network', '$e');
    }
    // A private project's registry answers 401/403/404 to visitors.
    if (res.statusCode == 401 || res.statusCode == 403 || res.statusCode == 404) {
      throw AppUpdateException('not_public', 'HTTP ${res.statusCode}');
    }
    if (res.statusCode == 429) {
      throw const AppUpdateException('rate_limited', 'HTTP 429');
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
    final info = decoded is Map<String, dynamic>
        ? parseGitlabManifest(
            decoded,
            pageUrl: 'https://$gitlabHost/projects/$gitlabProject',
          )
        : null;
    if (info == null) throw const AppUpdateException('no_apk');
    return info.buildNumber > await _currentBuild() ? info : null;
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

  /// Opens the Android installer for [path].
  ///
  /// Checks first that the APK can actually replace this app — same signing
  /// key and a higher version — so a mismatch is explained here instead of
  /// Android's vague "App not installed".
  Future<void> install(String path) async {
    try {
      final check = await _channel.invokeMapMethod<String, Object?>(
        'checkApk',
        {'path': path},
      );
      if (check != null) {
        if (check['sameSigner'] == false) {
          throw const AppUpdateException('signature_mismatch');
        }
        final apkCode = check['apkVersionCode'];
        final installed = check['installedVersionCode'];
        if (apkCode is int && installed is int && apkCode <= installed) {
          throw const AppUpdateException('older_build');
        }
      }
    } on MissingPluginException {
      // Older native side without the check: let the installer decide.
    } on PlatformException catch (e) {
      debugPrint('APK pre-install check skipped: ${e.message}');
    }
    try {
      await _channel.invokeMethod<bool>('installApk', {'path': path});
    } on PlatformException catch (e) {
      throw AppUpdateException('install_failed', e.message);
    }
  }
}


