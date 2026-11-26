import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/domain/models/calendar_event.dart';
import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/fronting/providers/fronting_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/features/wallets/id_card_designer.dart';
import 'package:prism_plurality/features/wallets/wallet_data.dart';
import 'package:prism_plurality/features/wallets/wallet_screens.dart';
import 'package:prism_plurality/l10n/app_localizations.dart';
import 'package:prism_plurality/shared/theme/app_theme.dart';

TrackerRecord rec(String id, String kind, {String title = '', String? member, Map<String, Object?> fields = const {}}) {
  final now = DateTime(2026, 11, 20);
  return TrackerRecord(id: id, kind: kind, title: title, memberId: member, createdAt: now, modifiedAt: now).withFields(fields);
}

void main() {
  templateSelectionTests();
  final (front, back) = buildTemplate('celestial', 'banner', type: 'guild');
  final seed = [
    rec('k1', TrackerKind.walletCard, title: 'Guild card', fields: {'type': 'guild', 'front': front.toJson(), 'back': back.toJson(), 'number': 'PRM-1234-5678', 'values': {'name': 'Rowan'}}),
    rec('w1', TrackerKind.wallet, title: 'Everyday', fields: {'items': [{'ref': 'card:k1', 'fav': true, 'folder': 'Clubs'}], 'primary': 'k1'}),
  ];

  Widget app(Widget home) => ProviderScope(
    overrides: [
      trackerRecordsProvider.overrideWith((ref) => Stream.value(seed)),
      userVisibleMembersProvider.overrideWithValue(const AsyncData(<Member>[])),
      allMembersProvider.overrideWith((ref) => Stream.value(const <Member>[])),
      activeSessionsProvider.overrideWith((ref) => Stream.value(const <FrontingSession>[])),
      currentFronterProvider.overrideWith((ref) => Stream.value(null)),
      calendarEventsProvider.overrideWith((ref) => Stream.value(const <CalendarEvent>[])),
    ],
    child: MaterialApp(theme: AppTheme.light(), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: home),
  );

  test('every collection and layout builds a two-sided card', () {
    expect(templateCollections.length, greaterThanOrEqualTo(14));
    expect(idCardTypes.length, greaterThanOrEqualTo(16));
    for (final c in templateCollections) {
      for (final l in templateLayouts.keys) {
        final (f, b) = buildTemplate(c.id, l, type: 'member');
        expect(f.layers, isNotEmpty);
        expect(b.layers.any((x) => x.text.contains('not an official document')), isTrue);
        expect(CardFace.fromJson(f.toJson()).layers.length, f.layers.length);
      }
    }
  });

  test('no government-style card types', () {
    final banned = RegExp(r'driver|passport|national|government|social security|visa', caseSensitive: false);
    for (final t in idCardTypes.values) {
      expect(banned.hasMatch(t.$1), isFalse, reason: t.$1);
    }
    expect(fictionalIdNotice, contains('Personal / Fictional ID'));
  });

  test('wallet items and identity round-trip', () {
    const i = WalletItem(ref: 'card:x', folder: 'A', pinned: true, favorite: true, archived: true);
    final b = WalletItem.fromJson(i.toJson());
    expect([b.kind, b.targetId, b.folder, b.pinned, b.favorite, b.archived], ['card', 'x', 'A', true, true, true]);
    final id = SystemIdentity.fromJson(const SystemIdentity(systemName: 'The Grove', prefix: 'GRV', collection: 'neon').toJson());
    expect([id.systemName, id.prefix, id.collection], ['The Grove', 'GRV', 'neon']);
  });

  testWidgets('wallet screens and designer open', (t) async {
    for (final s in const <Widget>[WalletsHomeScreen(), WalletScreen(walletId: 'w1'), IdCardDesigner(cardId: 'k1'), SystemIdentityScreen()]) {
      await t.pumpWidget(app(s));
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(t.takeException(), isNull, reason: '$s');
    }
    await t.pumpWidget(app(const WalletScreen(walletId: 'w1')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Guild card · on profile'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}

void templateSelectionTests() {
  test('every template has a unique id carried on both faces', () {
    final ids = <String>{};
    for (final c in templateCollections) {
      for (final l in templateLayouts.keys) {
        final (f, b) = buildTemplate(c.id, l, type: 'member');
        expect(f.tpl, '${c.id}.$l');
        expect(b.tpl, f.tpl);
        expect(ids.add(f.tpl), isTrue, reason: 'duplicate ${f.tpl}');
      }
    }
  });

  test('template id survives save and reload', () {
    final (f, _) = buildTemplate('holo', 'banner', type: 'member');
    expect(CardFace.fromJson(f.toJson()).tpl, 'holo.banner');
  });

  test('generated layers are tagged so user layers can be told apart', () {
    final (f, b) = buildTemplate('retro', 'centered', type: 'member');
    for (final l in [...f.layers, ...b.layers]) {
      expect(l.id.startsWith('t'), isTrue);
    }
  });
}
