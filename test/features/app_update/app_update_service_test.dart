import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:prism_plurality/features/app_update/app_update_provider.dart';
import 'package:prism_plurality/features/app_update/app_update_service.dart';

final _apkBytes = List<int>.generate(4096, (i) => i % 251);

Map<String, dynamic> _release({
  int build = 42,
  String? sha,
  bool apk = true,
}) => {
  'tag_name': 'android-build-$build',
  'name': 'Prism 0.15.3 (build $build)',
  'html_url': 'https://github.com/o/r/releases/tag/android-build-$build',
  'published_at': '2026-11-12T10:00:00Z',
  'body': 'Automated build.\n\nsha256: ${sha ?? sha256.convert(_apkBytes)}\n',
  'assets': [
    {
      'name': 'SHA256SUMS',
      'browser_download_url': 'https://x/sums',
      'size': 10,
    },
    if (apk)
      {
        'name': 'Prism-0.15.3-abc.apk',
        'browser_download_url': 'https://x/app.apk',
        'size': _apkBytes.length,
      },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('prism_update'));
  tearDown(() => tmp.deleteSync(recursive: true));

  AppUpdateService service(
    MockClient client, {
    int current = 10,
    MethodChannel? channel,
  }) => AppUpdateService(
    client: client,
    repo: 'o/r',
    currentBuild: () async => current,
    cacheDir: () async => tmp,
    channel: channel,
  );

  test('parses tag, version, apk asset and checksum', () {
    final info = parseReleaseJson(_release())!;
    expect(info.buildNumber, 42);
    expect(info.version, '0.15.3');
    expect(info.apkUrl, 'https://x/app.apk');
    expect(info.sha256, sha256.convert(_apkBytes).toString());
    expect(info.publishedAt, DateTime.utc(2026, 11, 12, 10));
    expect(parseReleaseJson({'tag_name': 'v1.0', 'assets': []}), isNull);
    expect(parseReleaseJson(_release(apk: false)), isNull);
  });

  test('reports an update only when the release build is newer', () async {
    final client = MockClient((req) async {
      expect(req.url.path, '/repos/o/r/releases');
      // Out of order on purpose: the newest build wins, not the first.
      return http.Response(jsonEncode([_release(build: 30), _release(), _release(build: 35)]), 200);
    });
    expect((await service(client).checkForUpdate())!.buildNumber, 42);
    expect(await service(client, current: 42).checkForUpdate(), isNull);
    expect(await service(client, current: 50).checkForUpdate(), isNull);
  });

  test('no releases yet is not an error; bad responses are', () async {
    expect(
      await service(
        MockClient((_) async => http.Response('', 404)),
      ).checkForUpdate(),
      isNull,
    );
    expect(
      () => service(
        MockClient((_) async => http.Response('oops', 500)),
      ).checkForUpdate(),
      throwsA(
        isA<AppUpdateException>().having((e) => e.code, 'code', 'bad_response'),
      ),
    );
    expect(
      () => service(
        MockClient((_) async => throw const SocketException('down')),
      ).checkForUpdate(),
      throwsA(
        isA<AppUpdateException>().having((e) => e.code, 'code', 'network'),
      ),
    );
  });

  test('downloads with progress and verifies the checksum', () async {
    final client = MockClient(
      (req) async => http.Response.bytes(_apkBytes, 200),
    );
    final progress = <double>[];
    final path = await service(
      client,
    ).download(parseReleaseJson(_release())!, onProgress: progress.add);
    expect(File(path).readAsBytesSync(), _apkBytes);
    expect(progress.last, 1);

    final bad = parseReleaseJson(_release(sha: 'a' * 64))!;
    await expectLater(
      service(client).download(bad),
      throwsA(
        isA<AppUpdateException>().having(
          (e) => e.code,
          'code',
          'checksum_mismatch',
        ),
      ),
    );
    expect(Directory('${tmp.path}/updates').listSync(), isEmpty);
  });

  test('drafts, prereleases and non-APK releases are ignored', () async {
    final client = MockClient(
      (req) async => http.Response(
        jsonEncode([
          {..._release(build: 99), 'draft': true},
          {..._release(build: 98), 'prerelease': true},
          _release(build: 97, apk: false),
          _release(build: 20),
        ]),
        200,
      ),
    );
    expect((await service(client).checkForUpdate())!.buildNumber, 20);
  });

  test('an interrupted download resumes where it stopped', () async {
    var calls = 0;
    final ranges = <String?>[];
    final client = MockClient.streaming((req, _) async {
      calls++;
      ranges.add(req.headers['Range']);
      if (calls == 1) {
        // Half the file, then the connection drops.
        final half = _apkBytes.sublist(0, 2000);
        final stream = Stream<List<int>>.fromIterable([half]).followedBy(Stream.error(const SocketException('dropped')));
        return http.StreamedResponse(stream, 200, contentLength: _apkBytes.length);
      }
      final from = int.parse(req.headers['Range']!.substring(6, req.headers['Range']!.length - 1));
      return http.StreamedResponse(Stream.value(_apkBytes.sublist(from)), 206, contentLength: _apkBytes.length - from);
    });
    final path = await service(client).download(parseReleaseJson(_release())!);
    expect(File(path).readAsBytesSync(), _apkBytes);
    expect(ranges, [null, 'bytes=2000-']);
  });

  test('notifier: check, download, permission prompt, install', () async {
    const channel = MethodChannel('test/app_update');
    var allowed = false;
    String? installed;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'canInstallPackages':
              return allowed;
            case 'installApk':
              installed = (call.arguments as Map)['path'] as String;
              return true;
          }
          return null;
        });
    final client = MockClient(
      (req) async => req.url.host == 'api.github.com'
          ? http.Response(jsonEncode(_release()), 200)
          : http.Response.bytes(_apkBytes, 200),
    );
    final c = ProviderContainer(
      overrides: [
        appUpdateServiceProvider.overrideWithValue(
          service(client, channel: channel),
        ),
      ],
    );
    addTearDown(c.dispose);
    final n = c.read(appUpdateNotifierProvider.notifier);

    await n.check();
    expect(c.read(appUpdateNotifierProvider).phase, AppUpdatePhase.available);

    await n.downloadAndInstall();
    expect(
      c.read(appUpdateNotifierProvider).phase,
      AppUpdatePhase.needsPermission,
    );
    expect(installed, isNull);

    allowed = true;
    await n.downloadAndInstall();
    expect(installed, isNotNull);
    expect(File(installed!).existsSync(), isTrue);
    expect(c.read(appUpdateNotifierProvider).phase, AppUpdatePhase.available);

    n.dismiss();
    expect(c.read(appUpdateNotifierProvider).dismissedBuild, 42);
  });
}

extension<T> on Stream<T> {
  Stream<T> followedBy(Stream<T> other) async* {
    yield* this;
    yield* other;
  }
}
