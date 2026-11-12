import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/features/contacts/services/device_contacts_service.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';
import 'package:prism_plurality/features/contacts/utils/contact_import.dart';

final contactsProvider = StreamProvider<List<Contact>>((ref) {
  return ref.watch(contactRepositoryProvider).watchAll();
});

final deviceContactsServiceProvider = Provider<DeviceContactsService>(
  (ref) => const DeviceContactsService(),
);

/// An upcoming contact birthday (recurs every year).
class UpcomingBirthday {
  const UpcomingBirthday(this.contact, this.date, this.birthday);
  final Contact contact;
  final DateTime date;
  final BirthdayDate birthday;
  int? get turning => birthday.ageOn(date);
}

/// Contact birthdays in the next [days] days, soonest first.
List<UpcomingBirthday> upcomingContactBirthdays(
  List<Contact> contacts,
  DateTime today, {
  int days = 30,
}) {
  final start = DateTime(today.year, today.month, today.day);
  final end = start.add(Duration(days: days));
  final out = <UpcomingBirthday>[];
  for (final c in contacts) {
    final b = BirthdayDate.fromStorage(c.birthday);
    if (b == null) continue;
    final next = b.nextOccurrence(start);
    if (next.isBefore(end)) out.add(UpcomingBirthday(c, next, b));
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// Summary of an import run.
class ContactImportResult {
  const ContactImportResult({
    this.created = 0,
    this.updated = 0,
    this.skipped = 0,
    this.failed = 0,
  });
  final int created;
  final int updated;
  final int skipped;
  final int failed;
}

class ContactsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Contact?> create({
    required String displayName,
    List<String> phones = const [],
    List<String> emails = const [],
    String? birthday,
    String? notes,
    bool isFavorite = false,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) return null;
    final now = DateTime.now();
    final contact = Contact(
      id: const Uuid().v4(),
      displayName: name,
      phones: phones,
      emails: emails,
      birthday: birthday,
      notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
      isFavorite: isFavorite,
      createdAt: now,
      modifiedAt: now,
    );
    state = await AsyncValue.guard(
      () => ref.read(contactRepositoryProvider).create(contact),
    );
    return state.hasError ? null : contact;
  }

  Future<void> save(Contact contact) async {
    state = await AsyncValue.guard(
      () => ref
          .read(contactRepositoryProvider)
          .update(contact.copyWith(modifiedAt: DateTime.now())),
    );
  }

  Future<void> delete(String id) async {
    state = await AsyncValue.guard(
      () => ref.read(contactRepositoryProvider).delete(id),
    );
  }

  /// Imports the selected [candidates]. Duplicates are resolved with
  /// [actions] (keyed by candidate key; default skip). Each write is
  /// independent, so one bad row can't stop the rest.
  Future<ContactImportResult> importCandidates(
    List<ContactCandidate> candidates,
    List<DuplicateMatch> duplicates,
    Map<String, DuplicateAction> actions,
  ) async {
    final repo = ref.read(contactRepositoryProvider);
    final dupByKey = {for (final d in duplicates) d.candidate.key: d};
    var created = 0, updated = 0, skipped = 0, failed = 0;
    for (final cand in candidates) {
      if (!cand.isValid) {
        skipped++;
        continue;
      }
      final now = DateTime.now();
      final dup = dupByKey[cand.key];
      final action = dup == null
          ? DuplicateAction.importAnyway
          : (actions[cand.key] ?? DuplicateAction.skip);
      try {
        if (action == DuplicateAction.skip) {
          skipped++;
        } else if (action == DuplicateAction.updateExisting &&
            dup?.existing != null) {
          await repo.update(mergeContact(dup!.existing!, cand, now));
          updated++;
        } else {
          await repo.create(
            Contact(
              id: const Uuid().v4(),
              displayName: cand.displayName!.trim(),
              phones: cand.phones,
              emails: cand.emails,
              birthday: cand.birthday?.toStorage(),
              notes: cand.notes,
              source: cand.source,
              externalId: cand.externalId,
              createdAt: now,
              modifiedAt: now,
            ),
          );
          created++;
        }
      } catch (_) {
        failed++;
      }
    }
    return ContactImportResult(
      created: created,
      updated: updated,
      skipped: skipped,
      failed: failed,
    );
  }
}

final contactsNotifierProvider = AsyncNotifierProvider<ContactsNotifier, void>(
  ContactsNotifier.new,
);
