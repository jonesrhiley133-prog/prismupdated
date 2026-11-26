import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prism_social_server/prism_social_server.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/domain/repositories/entity_repository.dart';
import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/prism_social/social_remote.dart';
import 'package:prism_plurality/features/social/models/social.dart'
    show SocialKind;
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';

class _Repo implements EntityRepository<TrackerRecord> {
  final rows = <TrackerRecord>[];
  @override
  Stream<List<TrackerRecord>> watchAll() async* {
    yield [...rows];
  }

  @override
  Future<List<TrackerRecord>> getAll() async => [...rows];
  @override
  Future<TrackerRecord?> getById(String id) async =>
      rows.where((r) => r.id == id).firstOrNull;
  @override
  Future<void> create(TrackerRecord item) async {
    if (rows.any((r) => r.id == item.id))
      throw StateError('UNIQUE constraint failed: ${item.id}');
    rows.add(item);
  }

  @override
  Future<void> update(TrackerRecord item) async {
    final i = rows.indexWhere((r) => r.id == item.id);
    if (i >= 0) rows[i] = item;
  }

  @override
  Future<void> delete(String id) async => rows.removeWhere((r) => r.id == id);
}

const _server = 'http://social.test';

/// One person's phone: its own database, talking to the shared server.
class Phone {
  Phone(shelf.Handler server) {
    c = ProviderContainer(
      overrides: [
        trackerRecordRepositoryProvider.overrideWithValue(repo),
        socialHttpClientProvider.overrideWithValue(
          MockClient((req) async {
            final res = await server(
              shelf.Request(
                req.method,
                req.url,
                headers: req.headers,
                body: req.bodyBytes,
              ),
            );
            return http.Response.bytes(
              await res.read().expand((x) => x).toList(),
              res.statusCode,
              headers: res.headers,
            );
          }),
        ),
      ],
    );
    c.listen(trackerRecordsProvider, (_, _) {});
  }
  final repo = _Repo();
  late final ProviderContainer c;

  SocialBackend get b => c.read(socialBackendProvider);
  T read<T>(ProviderListenable<T> p) => c.read(p);

  Future<void> refresh() async {
    c.invalidate(trackerRecordsProvider);
    await c.read(trackerRecordsProvider.future);
  }

  /// Pulls the latest snapshot from the server.
  Future<void> sync() async {
    await refresh();
    c.read(socialSyncProvider.notifier).invalidate();
    await c.read(socialSyncProvider.notifier).syncNow();
    await refresh();
  }

  Future<void> connect({bool bring = true}) async {
    await connectToSocialServer(c.read, url: _server, bringProfiles: bring);
    await refresh();
    expect(c.read(socialBackendProvider).reachesOtherDevices, isTrue);
    await sync();
  }
}

void main() {
  late MemoryStorage storage;
  late shelf.Handler server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = MemoryStorage();
    server = PrismSocialServer(
      storage,
      config: const ServerConfig(writesPerMinute: 10000),
    ).handler;
  });

  test(
    'two people on separate phones: friends, messages, alters, posts, images, blocks',
    () async {
      final alice = Phone(server), bob = Phone(server);
      addTearDown(alice.c.dispose);
      addTearDown(bob.c.dispose);
      await alice.connect();
      await bob.connect();
      // Each phone registered its own server account.
      expect(storage.accounts.values.toSet(), hasLength(2));

      final a = await alice.b.createProfile(
        username: 'aurora',
        systemName: 'Aurora',
        primary: true,
      );
      final b = await bob.b.createProfile(
        username: 'birch',
        systemName: 'Birch',
        primary: true,
      );
      await alice.sync();
      await bob.sync();
      expect(
        alice.read(socialProfilesProvider).map((p) => p.username).toSet(),
        {'aurora', 'birch'},
        reason: 'Discover reaches the other person',
      );
      expect(alice.read(actingProvider), SocialActor(a));

      // Alice can't act as Bob's system from her phone.
      await expectLater(
        alice.b.createPost(SocialActor(b), type: 'text', body: 'x'),
        throwsA(
          isA<SocialDenied>().having((e) => e.code, 'code', 'not_managed'),
        ),
      );

      await alice.b.sendRequest(SocialActor(a), b, note: 'Hi from Aurora');
      await bob.sync();
      final incoming = bob.read(pendingRequestsProvider(b)).incoming;
      expect(incoming.single.body, 'Hi from Aurora');
      expect(bob.read(notificationsProvider(b)).first.type, 'request');
      await bob.b.acceptRequest(SocialActor(b), incoming.single.id);
      await alice.sync();
      expect(alice.read(friendIdsProvider(a)), {b});

      // Alter to alter.
      final sol = await alice.b.saveAlter(a, name: 'Sol');
      final mira = await bob.b.saveAlter(b, name: 'Mira');
      await alice.sync();
      expect(alice.read(socialAltersProvider).map((x) => x.name).toSet(), {
        'Sol',
        'Mira',
      });
      final conv = await alice.b.openConversation(
        SocialActor(a, sol),
        SocialActor(b, mira),
      );
      await alice.b.sendMessage(
        SocialActor(a, sol),
        conv,
        body: 'Hi Mira, it’s Sol',
      );
      await bob.sync();
      expect(bob.read(messagesProvider(conv)).single.body, 'Hi Mira, it’s Sol');
      expect(bob.read(unreadMessagesProvider(b)), 1);
      final convOnBob = bob.read(conversationsProvider(b)).single;
      expect(convOnBob.me(b), SocialActor(b, mira));
      await bob.b.sendMessage(SocialActor(b, mira), conv, body: 'Hi Sol!');
      await bob.b.markRead(SocialActor(b, mira), conv);
      await alice.sync();
      expect(alice.read(messagesProvider(conv)).map((m) => m.body), [
        'Hi Mira, it’s Sol',
        'Hi Sol!',
      ]);
      expect(
        alice.read(messagesProvider(conv)).first.readBy.containsKey(b),
        isTrue,
      );

      // A post with a photo from Alice's phone reaches Bob as a server image.
      final pixel = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      );
      final photo = await alice
          .read(trackerNotifierProvider.notifier)
          .create(
            kind: SocialKind.media,
            fields: {'mime': 'image/png', 'data': base64Encode(pixel)},
          );
      final post = await alice.b.createPost(
        SocialActor(a, sol),
        type: 'image',
        body: 'Sunset',
        media: [photo.id],
        audience: Audience.friends,
      );
      await bob.sync();
      final seen = bob.read(feedProvider((b, FeedMode.recent))).single;
      expect(seen.id, post);
      expect(seen.author, SocialActor(a, sol));
      expect(seen.media.single, startsWith(serverMediaPrefix));
      expect(
        await bob.c.read(remoteSocialImageProvider(seen.media.single).future),
        pixel,
      );

      await bob.b.toggleReact(SocialActor(b), post, 'like');
      await bob.b.comment(SocialActor(b, mira), post, 'Beautiful');
      await alice.sync();
      expect(
        alice.read(reactsProvider(post)).where((r) => r.str('type') == 'like'),
        hasLength(1),
      );
      expect(alice.read(commentsProvider(post)).single.body, 'Beautiful');
      expect(
        alice.read(notificationsProvider(a)).map((n) => n.type),
        containsAll(['accepted', 'alterMessage', 'like', 'comment']),
      );

      // Blocking hides Alice from Bob and Bob from Alice (without telling her).
      await bob.b.block(SocialActor(b), a);
      await alice.sync();
      expect(alice.read(socialProfilesProvider).any((p) => p.id == b), isFalse);
      expect(alice.read(friendIdsProvider(a)), isEmpty);
      expect(
        alice.read(blockedIdsProvider(a)),
        isEmpty,
        reason: 'the block itself is not revealed',
      );
      // …and Bob coming back after an unblock works (rows are revived).
      await bob.b.unblock(SocialActor(b), a);
      await alice.sync();
      expect(alice.read(socialProfilesProvider).any((p) => p.id == b), isTrue);
    },
  );

  test(
    'connecting brings existing on-device profiles; disconnect and account deletion',
    () async {
      final phone = Phone(server);
      addTearDown(phone.c.dispose);
      // Start on-device.
      final local = await phone.b.createProfile(
        username: 'cedar',
        systemName: 'Cedar',
        primary: true,
      );
      await phone.refresh();
      await phone.b.updateProfile(local, {'pronouns': 'they/them'});
      await phone.b.saveAlter(local, name: 'Ivy');
      await phone.refresh();
      expect(phone.b.reachesOtherDevices, isFalse);

      await phone.connect();
      final profiles = phone.read(socialProfilesProvider);
      expect(profiles.single.username, 'cedar');
      expect(
        profiles.single.id,
        isNot(local),
        reason: 'recreated on the server',
      );
      expect(profiles.single.pronouns, 'they/them');
      expect(phone.read(socialAltersProvider).single.name, 'Ivy');
      expect(phone.read(actingProvider)?.profileId, profiles.single.id);

      // A second person can find the migrated profile.
      final other = Phone(server);
      addTearDown(other.c.dispose);
      await other.connect();
      expect(
        other.read(socialProfilesProvider).any((p) => p.username == 'cedar'),
        isTrue,
      );

      await disconnectSocialServer(phone.c.read, deleteAccount: true);
      await phone.refresh();
      expect(phone.read(socialConnectionProvider), isNull);
      expect(phone.read(socialProfilesProvider), isEmpty);
      expect(phone.b.reachesOtherDevices, isFalse);
      await other.sync();
      expect(
        other.read(socialProfilesProvider).any((p) => p.username == 'cedar'),
        isFalse,
        reason: 'deleted from the server',
      );
    },
  );

  test('server URL normalisation and friendly refusal codes', () async {
    expect(
      normalizeServerUrl('prism.up.railway.app/'),
      'https://prism.up.railway.app',
    );
    expect(
      normalizeServerUrl('http://localhost:8080'),
      'http://localhost:8080',
    );
    final phone = Phone(server);
    addTearDown(phone.c.dispose);
    await phone.connect();
    await phone.b.createProfile(username: 'dune', systemName: 'Dune');
    await expectLater(
      phone.b.createProfile(username: 'dune', systemName: 'Again'),
      throwsA(
        isA<SocialDenied>().having((e) => e.code, 'code', 'username_taken'),
      ),
    );
  });
}
