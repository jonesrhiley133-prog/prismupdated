import 'records.dart';
import 'rules.dart';
import 'wrappers.dart';

/// What an account may download: everything its own profiles may see, with
/// private fields removed. The server sends this snapshot to the app, which
/// mirrors it locally (screens then work exactly as on-device).
Future<List<SocRecord>> visibleTo(SocialStore store, Set<String> mine) async {
  final rules = SocialRules(store);
  final kinds = {for (final k in SocKind.all) k: await store.all(k)};
  final out = <SocRecord>[];

  // Blocks hide people completely (in both directions). A block placed by
  // someone else is never revealed; their content simply disappears.
  final blocksByMe = [for (final b in kinds[SocKind.block]!) if (mine.contains(b.str('by'))) b];
  final hidden = <String>{
    for (final b in kinds[SocKind.block]!)
      if (mine.contains(b.str('by'))) b.str('who')! else if (mine.contains(b.str('who'))) b.str('by')!,
  }..removeAll(mine);
  out.addAll(blocksByMe);

  final friendships = kinds[SocKind.friendship]!;
  Set<String> friendsOf(String p) => {
    for (final f in friendships)
      if (f.str('a') == p) f.str('b')! else if (f.str('b') == p) f.str('a')!,
  };
  final myFriends = {for (final m in mine) ...friendsOf(m)}..removeAll(hidden);

  // Friendships: mine and my friends' (needed for mutuals and
  // friends-of-friends audiences).
  final circleOfTrust = {...mine, ...myFriends};
  for (final f in friendships) {
    final a = f.str('a'), b = f.str('b');
    if (hidden.contains(a) || hidden.contains(b)) continue;
    if (circleOfTrust.contains(a) || circleOfTrust.contains(b)) out.add(f);
  }

  // Requests and follows that involve me.
  for (final r in kinds[SocKind.request]!) {
    if ((mine.contains(r.str('from')) && !hidden.contains(r.str('to'))) || (mine.contains(r.str('to')) && !hidden.contains(r.str('from')))) out.add(r);
  }
  for (final r in kinds[SocKind.follow]!) {
    if ((mine.contains(r.str('by')) && !hidden.contains(r.str('who'))) || (mine.contains(r.str('who')) && !hidden.contains(r.str('by')))) out.add(r);
  }

  // Conversations and their messages.
  final convIds = <String>{};
  for (final c in kinds[SocKind.conversation]!) {
    final parts = SConv(c).participants;
    if (parts.any((p) => mine.contains(p.profileId))) {
      convIds.add(c.id);
      out.add(c);
    }
  }
  for (final m in kinds[SocKind.message]!) {
    if (convIds.contains(m.parentId)) out.add(m);
  }
  final talkingTo = {for (final c in kinds[SocKind.conversation]!) if (convIds.contains(c.id)) for (final p in SConv(c).participants) p.profileId};

  // Posts any of my profiles may see, plus their comments and reactions.
  final postIds = <String>{};
  final authors = <String>{};
  for (final p in kinds[SocKind.post]!) {
    final post = SPost(p);
    if (hidden.contains(post.author.profileId)) continue;
    var ok = false;
    for (final me in mine) {
      if (await rules.canSee(post, me)) {
        ok = true;
        break;
      }
    }
    if (!ok) continue;
    postIds.add(p.id);
    authors.add(post.author.profileId);
    out.add(p);
    // Circle posts: send a stripped circle so the app's own check passes,
    // without revealing the circle's name or other members.
    final circle = post.circleId;
    if (circle != null && !mine.contains(post.author.profileId)) {
      final c = kinds[SocKind.circle]!.where((x) => x.id == circle).firstOrNull;
      if (c != null) out.add(SocRecord(id: c.id, kind: c.kind, createdAt: c.createdAt, modifiedAt: c.modifiedAt, fields: {'owner': c.str('owner'), 'members': [for (final m in c.strings('members')) if (mine.contains(m)) m]}));
    }
  }
  for (final c in kinds[SocKind.comment]!) {
    if (postIds.contains(c.parentId) && !hidden.contains(SComment(c).author.profileId)) out.add(c);
  }
  for (final r in kinds[SocKind.react]!) {
    if (!postIds.contains(r.parentId) || hidden.contains(r.str('by'))) continue;
    // Bookmarks are private.
    if (r.str('type') == 'bookmark' && !mine.contains(r.str('by'))) continue;
    out.add(r);
  }
  for (final c in kinds[SocKind.circle]!) {
    if (mine.contains(c.str('owner'))) out.add(c);
  }

  // Profiles: mine, everyone I'm connected to, and discoverable ones.
  final related = <String>{...mine, ...myFriends, ...talkingTo, ...authors};
  for (final r in out.toList()) {
    for (final k in const ['from', 'to', 'by', 'who', 'a', 'b']) {
      final v = r.str(k);
      if (v != null) related.add(v);
    }
    final actor = SocialActor.fromJson(r.fields['author'] ?? r.fields['sender'] ?? r.fields['actor']);
    if (actor != null) related.add(actor.profileId);
  }
  final shownProfiles = <String>{};
  for (final p in kinds[SocKind.profile]!) {
    if (hidden.contains(p.id)) continue;
    final prof = SProfile(p);
    final isMine = mine.contains(p.id);
    if (!isMine && !related.contains(p.id) && !prof.discoverable) continue;
    shownProfiles.add(p.id);
    if (isMine) {
      out.add(p.withFields({'owner': null}));
      continue;
    }
    var canView = false;
    for (final me in mine) {
      if (await rules.allows(prof.whoCanSeeProfile, p.id, me)) {
        canView = true;
        break;
      }
    }
    final follows = kinds[SocKind.follow]!.where((f) => f.str('who') == p.id).length;
    // Others never see notification settings, owner or (if hidden) details.
    out.add(
      canView
          ? p.withFields({'owner': null, 'notify': null, 'followers': follows, 'lastActive': prof.onlineVisible ? p.fields['lastActive'] : null})
          : SocRecord(id: p.id, kind: p.kind, title: p.title, createdAt: p.createdAt, modifiedAt: p.modifiedAt, fields: {'username': prof.username, 'avatar': p.fields['avatar'], 'privacy': p.fields['privacy'], 'followers': follows}),
    );
  }

  // Alters: mine, and others' when both the system and alter allow it.
  for (final a in kinds[SocKind.alter]!) {
    final pid = a.parentId;
    if (pid == null || !shownProfiles.contains(pid)) continue;
    if (mine.contains(pid)) {
      out.add(a);
      continue;
    }
    final prof = SProfile(kinds[SocKind.profile]!.firstWhere((p) => p.id == pid));
    var ok = false;
    for (final me in mine) {
      if (await rules.allows(prof.whoCanSeeAlters, pid, me) && await rules.allows(SAlter(a).visibility, pid, me)) {
        ok = true;
        break;
      }
    }
    // Alters someone is talking to or posting as stay visible by name.
    final involved = [...kinds[SocKind.message]!.where((m) => convIds.contains(m.parentId)).map((m) => SocialActor.fromJson(m.fields['sender'])), ...kinds[SocKind.conversation]!.where((c) => convIds.contains(c.id)).expand((c) => SConv(c).participants), ...out.where((r) => r.kind == SocKind.post || r.kind == SocKind.comment).map((r) => SocialActor.fromJson(r.fields['author']))].any((x) => x?.alterId == a.id);
    if (ok || involved) out.add(a.withFields({'memberId': null}).copyWith(memberId: null));
  }

  // Notifications and reports for my profiles.
  for (final n in kinds[SocKind.notif]!) {
    if (mine.contains(n.parentId) && !hidden.contains(SocialActor.fromJson(n.fields['actor'])?.profileId)) out.add(n);
  }
  for (final r in kinds[SocKind.report]!) {
    if (mine.contains(r.str('by'))) out.add(r);
  }
  return out;
}
