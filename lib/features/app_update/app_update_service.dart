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
  final MethodChannel _channel;
  final Future<int> Function() _currentBuild;
  final Future<Directory> Function() _cacheDir;

  static Future<int> _packageBuild() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

  /// True on Android builds that were told where updates live.
  bool get isSupported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      repo.contains('/');

  Future<int> currentBuildNumber() => _currentBuild();

  /// Returns the newer release, or null when this build is current.
  Future<AppUpdateInfo?> checkForUpdate() async {
    if (!repo.contains('/')) throw const AppUpdateException('unsupported');
    final http.Response res;
    try {
      res = await _client
          .get(
            Uri.https('api.github.com', '/repos/$repo/releases/latest'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 20));
    } on Exception catch (e) {
      throw AppUpdateException('network', '$e');
    }
    if (res.statusCode == 404) return null; // No releases yet.
    if (res.statusCode != 200) {
      throw AppUpdateException('bad_response', 'HTTP ${res.statusCode}');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } on FormatException catch (e) {
      throw AppUpdateException('bad_response', e.message);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AppUpdateException('bad_response');
    }
    final info = parseReleaseJson(decoded);
    if (info == null) throw const AppUpdateException('no_apk');
    final current = await _currentBuild();
    return info.buildNumber > current ? info : null;
  }

  /// Downloads the APK into the cache, reporting progress from 0 to 1, and
  /// verifies its checksum. Returns the file path.
  Future<String> download(
    AppUpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = Directory('${(await _cacheDir()).path}/updates');
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        try {
          f.deleteSync(recursive: true);
        } on FileSystemException {
          // An old update file in use; leave it.
        }
      }
    } else {
      dir.createSync(recursive: true);
    }
    final file = File('${dir.path}/prism-update-${info.buildNumber}.apk');
    final http.StreamedResponse res;
    try {
      res = await _client
          .send(http.Request('GET', Uri.parse(info.apkUrl)))
          .timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      throw AppUpdateException('network', '$e');
    }
    if (res.statusCode != 200) {
      throw AppUpdateException('download_failed', 'HTTP ${res.statusCode}');
    }
    final total = res.contentLength ?? info.sizeBytes;
    final sink = file.openWrite();
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    var received = 0;
    try {
      await for (final chunk in res.stream.timeout(
        const Duration(seconds: 60),
      )) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call((received / total).clamp(0, 1).toDouble());
        }
      }
      await sink.flush();
    } on Exception catch (e) {
      await sink.close();
      if (file.existsSync()) file.deleteSync();
      throw AppUpdateException('download_failed', '$e');
    }
    await sink.close();
    hasher.close();
    if (total > 0 && received != total) {
      file.deleteSync();
      throw const AppUpdateException('download_failed', 'incomplete');
    }
    final expected = info.sha256;
    if (expected != null && digestSink.value.toString() != expected) {
      file.deleteSync();
      throw const AppUpdateException('checksum_mismatch');
    }
    onProgress?.call(1);
    return file.path;
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

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
