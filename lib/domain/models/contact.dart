import 'package:freezed_annotation/freezed_annotation.dart';

part 'contact.freezed.dart';
part 'contact.g.dart';

/// Where a contact came from.
abstract final class ContactSource {
  static const manual = 'manual';
  static const device = 'device';
  static const vcard = 'vcard';
  static const birthdayImport = 'birthday_import';
}

@freezed
abstract class Contact with _$Contact {
  const factory Contact({
    required String id,
    required String displayName,
    @Default(<String>[]) List<String> phones,
    @Default(<String>[]) List<String> emails,

    /// `yyyy-MM-dd`, or `0004-MM-dd` when the year is unknown.
    String? birthday,
    String? notes,
    @Default(ContactSource.manual) String source,
    String? externalId,
    @Default(false) bool isFavorite,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) = _Contact;

  factory Contact.fromJson(Map<String, dynamic> json) =>
      _$ContactFromJson(json);
}
