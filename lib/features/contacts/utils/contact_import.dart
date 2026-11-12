import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';

/// A contact about to be imported.
class ContactCandidate {
  const ContactCandidate({
    required this.key,
    required this.displayName,
    this.phones = const [],
    this.emails = const [],
    this.birthday,
    this.notes,
    this.externalId,
    required this.source,
    this.error,
    this.warning,
  });

  /// Stable id within this import (for selection state).
  final String key;
  final String? displayName;
  final List<String> phones;
  final List<String> emails;
  final BirthdayDate? birthday;
  final String? notes;
  final String? externalId;
  final String source;

  /// Why this can't be imported (null when valid).
  final String? error;

  /// Something to double-check, e.g. an ambiguous date.
  final String? warning;

  bool get isValid =>
      error == null && (displayName?.trim().isNotEmpty ?? false);
}

/// How a duplicate is handled.
enum DuplicateAction { skip, importAnyway, updateExisting }

/// A candidate that matches a contact already in Prism, or an earlier row
/// in the same import.
class DuplicateMatch {
  const DuplicateMatch({
    required this.candidate,
    this.existing,
    this.sameFileAs,
    required this.conflictingBirthday,
  });

  final ContactCandidate candidate;
  final Contact? existing;

  /// Key of an earlier candidate in the same import.
  final String? sameFileAs;

  /// Same person but a different birthday on record.
  final bool conflictingBirthday;
}

String normalizeContactName(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9À-ɏ]+'), ' ').trim();

String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

/// Finds duplicates by external id, then by phone/email, then by name.
List<DuplicateMatch> findContactDuplicates(
  List<ContactCandidate> candidates,
  List<Contact> existing,
) {
  final out = <DuplicateMatch>[];
  final byExternal = {
    for (final c in existing)
      if (c.externalId != null) '${c.source}|${c.externalId}': c,
  };
  final byName = <String, Contact>{
    for (final c in existing) normalizeContactName(c.displayName): c,
  };
  final byPhone = <String, Contact>{
    for (final c in existing)
      for (final p in c.phones)
        if (_digits(p).length >= 6) _digits(p): c,
  };
  final byEmail = <String, Contact>{
    for (final c in existing)
      for (final e in c.emails) e.toLowerCase().trim(): c,
  };
  final seenInFile = <String, ContactCandidate>{};

  for (final cand in candidates.where((c) => c.isValid)) {
    final name = normalizeContactName(cand.displayName!);
    Contact? match = cand.externalId == null
        ? null
        : byExternal['${cand.source}|${cand.externalId}'];
    match ??= cand.phones
        .map((p) => byPhone[_digits(p)])
        .whereType<Contact>()
        .firstOrNull;
    match ??= cand.emails
        .map((e) => byEmail[e.toLowerCase().trim()])
        .whereType<Contact>()
        .firstOrNull;
    match ??= byName[name];
    if (match != null) {
      final existingBday = BirthdayDate.fromStorage(match.birthday);
      out.add(
        DuplicateMatch(
          candidate: cand,
          existing: match,
          conflictingBirthday:
              existingBday != null &&
              cand.birthday != null &&
              (existingBday.month != cand.birthday!.month ||
                  existingBday.day != cand.birthday!.day),
        ),
      );
      continue;
    }
    final earlier = seenInFile[name];
    if (earlier != null) {
      out.add(
        DuplicateMatch(
          candidate: cand,
          sameFileAs: earlier.key,
          conflictingBirthday:
              earlier.birthday != null &&
              cand.birthday != null &&
              earlier.birthday != cand.birthday,
        ),
      );
    } else {
      seenInFile[name] = cand;
    }
  }
  return out;
}

/// Merges [cand] into [existing]: fills in missing fields, adds new phone
/// numbers and emails, and takes the imported birthday.
Contact mergeContact(Contact existing, ContactCandidate cand, DateTime now) {
  return existing.copyWith(
    phones: {...existing.phones, ...cand.phones}.toList(),
    emails: {...existing.emails, ...cand.emails}.toList(),
    birthday: cand.birthday?.toStorage() ?? existing.birthday,
    notes: existing.notes ?? cand.notes,
    externalId: existing.externalId ?? cand.externalId,
    modifiedAt: now,
  );
}
