import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';
import 'package:prism_plurality/features/contacts/utils/contact_import.dart';

/// Outcome of asking for read access to the device's contacts.
enum DeviceContactsAccess { granted, limited, denied, unsupported }

/// Reads the phone's address book (Android, iOS, macOS). Read-only:
/// Prism never writes to device contacts.
class DeviceContactsService {
  const DeviceContactsService();

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<DeviceContactsAccess> requestAccess() async {
    if (!isSupported) return DeviceContactsAccess.unsupported;
    final status = await fc.FlutterContacts.permissions.request(
      fc.PermissionType.read,
    );
    return switch (status) {
      fc.PermissionStatus.granted => DeviceContactsAccess.granted,
      fc.PermissionStatus.limited => DeviceContactsAccess.limited,
      _ => DeviceContactsAccess.denied,
    };
  }

  Future<void> openSettings() => fc.FlutterContacts.permissions.openSettings();

  /// All readable contacts as import candidates.
  Future<List<ContactCandidate>> loadCandidates() async {
    final contacts = await fc.FlutterContacts.getAll(
      properties: {
        fc.ContactProperty.name,
        fc.ContactProperty.phone,
        fc.ContactProperty.email,
        fc.ContactProperty.event,
        fc.ContactProperty.note,
      },
    );
    return [
      for (final c in contacts)
        ContactCandidate(
          key: 'device:${c.id}',
          displayName: c.displayName?.trim(),
          phones: [for (final p in c.phones) p.number],
          emails: [for (final e in c.emails) e.address],
          birthday: _birthday(c),
          notes: _notes(c),
          externalId: c.id,
          source: ContactSource.device,
          error: (c.displayName?.trim().isEmpty ?? true)
              ? 'missing_name'
              : null,
        ),
    ];
  }

  String? _notes(fc.Contact c) {
    final text = c.notes
        .map((n) => n.note.trim())
        .where((n) => n.isNotEmpty)
        .join('\n');
    return text.isEmpty ? null : text;
  }

  BirthdayDate? _birthday(fc.Contact c) {
    for (final e in c.events) {
      if (e.label.label != fc.EventLabel.birthday) continue;
      final b = BirthdayDate(
        e.month,
        e.day,
        (e.year == null || e.year == 0) ? null : e.year,
      );
      if (b.isValid) return b;
    }
    return null;
  }
}
