import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';

/// Everything a contact profile holds beyond the basic contact record
/// (name, phones, emails, birthday, notes). Stored as one synced record per
/// contact, so existing contacts are never altered and a contact with no
/// extras simply has none.
///
/// [privateNotes] and [safety] are private to the person: nothing in Prism
/// shares, exports or syncs them to anyone else.
class ContactExtras {
  const ContactExtras({
    this.contactId = '',
    this.nickname = '',
    this.pronouns = '',
    this.relationship = '',
    this.status = '',
    this.avatar,
    this.banner,
    this.accent,
    this.phoneLabels = const {},
    this.emailLabels = const {},
    this.socials = const [],
    this.addresses = const [],
    this.dates = const [],
    this.commPrefs = '',
    this.boundaries = '',
    this.reminders = const [],
    this.custom = const [],
    this.privateNotes = '',
    this.safety = const [],
    this.giftIdeas = const [],
    this.alters = const [],
    this.alterNotes = const {},
    this.conversation,
    this.links = const [],
    this.interactions = const [],
    this.sharedMemories = const [],
  });

  final String contactId;
  final String nickname, pronouns, relationship, status;
  final String? avatar, banner;
  final int? accent;

  /// Label ("Mobile", "Work"…) for a phone number / email, keyed by the value.
  final Map<String, String> phoneLabels, emailLabels;

  /// `{label, url}`
  final List<Map<String, String>> socials;

  /// `{label, text}`
  final List<Map<String, String>> addresses;

  /// Anniversaries and other important dates: `{label, date: yyyy-MM-dd}`.
  final List<Map<String, String>> dates;
  final String commPrefs, boundaries;

  /// `{text, date?}`
  final List<Map<String, String>> reminders;

  /// `{label, value}`
  final List<Map<String, String>> custom;
  final String privateNotes;
  final List<String> safety;
  final List<String> giftIdeas;

  /// Member ids this contact is connected to, with a note about each.
  final List<String> alters;
  final Map<String, String> alterNotes;

  /// An existing Prism conversation to jump to.
  final String? conversation;

  /// Linked records: `journal:<id>`, `scrap:<id>`, `cal:<id>`.
  final List<String> links;

  /// `{at: iso, note}` newest first.
  final List<Map<String, String>> interactions;

  /// Free-text shared memories.
  final List<String> sharedMemories;

  bool get isEmpty => toJson().length <= 1;

  ContactExtras copyWith({
    String? nickname,
    String? pronouns,
    String? relationship,
    String? status,
    Object? avatar = _k,
    Object? banner = _k,
    Object? accent = _k,
    Map<String, String>? phoneLabels,
    Map<String, String>? emailLabels,
    List<Map<String, String>>? socials,
    List<Map<String, String>>? addresses,
    List<Map<String, String>>? dates,
    String? commPrefs,
    String? boundaries,
    List<Map<String, String>>? reminders,
    List<Map<String, String>>? custom,
    String? privateNotes,
    List<String>? safety,
    List<String>? giftIdeas,
    List<String>? alters,
    Map<String, String>? alterNotes,
    Object? conversation = _k,
    List<String>? links,
    List<Map<String, String>>? interactions,
    List<String>? sharedMemories,
  }) => ContactExtras(
    contactId: contactId,
    nickname: nickname ?? this.nickname,
    pronouns: pronouns ?? this.pronouns,
    relationship: relationship ?? this.relationship,
    status: status ?? this.status,
    avatar: identical(avatar, _k) ? this.avatar : avatar as String?,
    banner: identical(banner, _k) ? this.banner : banner as String?,
    accent: identical(accent, _k) ? this.accent : accent as int?,
    phoneLabels: phoneLabels ?? this.phoneLabels,
    emailLabels: emailLabels ?? this.emailLabels,
    socials: socials ?? this.socials,
    addresses: addresses ?? this.addresses,
    dates: dates ?? this.dates,
    commPrefs: commPrefs ?? this.commPrefs,
    boundaries: boundaries ?? this.boundaries,
    reminders: reminders ?? this.reminders,
    custom: custom ?? this.custom,
    privateNotes: privateNotes ?? this.privateNotes,
    safety: safety ?? this.safety,
    giftIdeas: giftIdeas ?? this.giftIdeas,
    alters: alters ?? this.alters,
    alterNotes: alterNotes ?? this.alterNotes,
    conversation: identical(conversation, _k)
        ? this.conversation
        : conversation as String?,
    links: links ?? this.links,
    interactions: interactions ?? this.interactions,
    sharedMemories: sharedMemories ?? this.sharedMemories,
  );

  static const _k = Object();

  Map<String, Object?> toJson() => {
    'cid': contactId,
    if (nickname.isNotEmpty) 'nick': nickname,
    if (pronouns.isNotEmpty) 'pro': pronouns,
    if (relationship.isNotEmpty) 'rel': relationship,
    if (status.isNotEmpty) 'st': status,
    'av': ?avatar,
    'bn': ?banner,
    'ac': ?accent,
    if (phoneLabels.isNotEmpty) 'pl': phoneLabels,
    if (emailLabels.isNotEmpty) 'el': emailLabels,
    if (socials.isNotEmpty) 'soc': socials,
    if (addresses.isNotEmpty) 'adr': addresses,
    if (dates.isNotEmpty) 'dt': dates,
    if (commPrefs.isNotEmpty) 'cp': commPrefs,
    if (boundaries.isNotEmpty) 'bd': boundaries,
    if (reminders.isNotEmpty) 'rm': reminders,
    if (custom.isNotEmpty) 'cu': custom,
    if (privateNotes.isNotEmpty) 'pn': privateNotes,
    if (safety.isNotEmpty) 'sf': safety,
    if (giftIdeas.isNotEmpty) 'gf': giftIdeas,
    if (alters.isNotEmpty) 'al': alters,
    if (alterNotes.isNotEmpty) 'an': alterNotes,
    'cv': ?conversation,
    if (links.isNotEmpty) 'ln': links,
    if (interactions.isNotEmpty) 'ix': interactions,
    if (sharedMemories.isNotEmpty) 'sm': sharedMemories,
  };

  static Map<String, String> _strMap(Object? o) => {
    if (o is Map)
      for (final e in o.entries)
        if (e.key is String && e.value != null) e.key as String: '${e.value}',
  };

  static List<Map<String, String>> _maps(Object? o) => [
    if (o is List)
      for (final x in o)
        if (x is Map) _strMap(x),
  ];

  static List<String> _strs(Object? o) => [
    if (o is List)
      for (final x in o)
        if (x is String) x,
  ];

  static ContactExtras fromJson(Map<String, Object?> j) => ContactExtras(
    contactId: '${j['cid'] ?? ''}',
    nickname: '${j['nick'] ?? ''}',
    pronouns: '${j['pro'] ?? ''}',
    relationship: '${j['rel'] ?? ''}',
    status: '${j['st'] ?? ''}',
    avatar: j['av'] as String?,
    banner: j['bn'] as String?,
    accent: (j['ac'] as num?)?.toInt(),
    phoneLabels: _strMap(j['pl']),
    emailLabels: _strMap(j['el']),
    socials: _maps(j['soc']),
    addresses: _maps(j['adr']),
    dates: _maps(j['dt']),
    commPrefs: '${j['cp'] ?? ''}',
    boundaries: '${j['bd'] ?? ''}',
    reminders: _maps(j['rm']),
    custom: _maps(j['cu']),
    privateNotes: '${j['pn'] ?? ''}',
    safety: _strs(j['sf']),
    giftIdeas: _strs(j['gf']),
    alters: _strs(j['al']),
    alterNotes: _strMap(j['an']),
    conversation: j['cv'] as String?,
    links: _strs(j['ln']),
    interactions: _maps(j['ix']),
    sharedMemories: _strs(j['sm']),
  );
}

/// The saved record behind a contact's extras (null until first edited).
final contactExtrasRecordProvider = Provider.family<TrackerRecord?, String>((
  ref,
  contactId,
) {
  final all =
      ref.watch(trackerKindProvider(TrackerKind.contactProfile)).value ??
      const <TrackerRecord>[];
  for (final r in all) {
    if (r.fields['cid'] == contactId) return r;
  }
  return null;
});

final contactExtrasProvider = Provider.family<ContactExtras, String>((
  ref,
  contactId,
) {
  final r = ref.watch(contactExtrasRecordProvider(contactId));
  if (r == null) return ContactExtras(contactId: contactId);
  return ContactExtras.fromJson({...r.fields, 'cid': contactId});
});

class ContactExtrasActions {
  ContactExtrasActions(this.ref);
  final Ref ref;

  Future<void> save(ContactExtras e) async {
    final t = ref.read(trackerNotifierProvider.notifier);
    final existing = ref.read(contactExtrasRecordProvider(e.contactId));
    if (existing == null) {
      if (e.isEmpty) return;
      await t.create(
        kind: TrackerKind.contactProfile,
        title: 'Contact profile',
        fields: e.toJson(),
      );
    } else {
      await t.save(existing.withFields(e.toJson()));
    }
  }

  /// Removes a contact's extras (used when the contact is deleted).
  Future<void> remove(String contactId) async {
    final existing = ref.read(contactExtrasRecordProvider(contactId));
    if (existing != null)
      await ref.read(trackerNotifierProvider.notifier).delete(existing.id);
  }
}

final contactExtrasActionsProvider = Provider<ContactExtrasActions>(
  ContactExtrasActions.new,
);
