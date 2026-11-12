import 'package:prism_plurality/features/contacts/utils/birthday_date.dart';
import 'package:prism_plurality/features/contacts/utils/birthday_json_parser.dart';

/// One contact read from a vCard (.vcf) file.
class ParsedVCard {
  const ParsedVCard({
    required this.name,
    required this.phones,
    required this.emails,
    this.birthday,
    this.uid,
    this.note,
  });

  final String? name;
  final List<String> phones;
  final List<String> emails;
  final BirthdayDate? birthday;
  final String? uid;
  final String? note;
}

/// Parses vCard 2.1/3.0/4.0 text: FN (or N), TEL, EMAIL, BDAY, UID, NOTE.
/// Handles folded lines, property groups (`item1.TEL`) and parameters.
List<ParsedVCard> parseVCards(String source) {
  // Unfold: a line starting with space/tab continues the previous one.
  final unfolded = source
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'\n[ \t]'), '');
  final cards = <ParsedVCard>[];
  List<String>? lines;
  for (final line in unfolded.split('\n')) {
    final upper = line.trim().toUpperCase();
    if (upper == 'BEGIN:VCARD') {
      lines = [];
    } else if (upper == 'END:VCARD') {
      if (lines != null) cards.add(_card(lines));
      lines = null;
    } else {
      lines?.add(line);
    }
  }
  return cards;
}

ParsedVCard _card(List<String> lines) {
  String? fn;
  String? n;
  String? uid;
  String? note;
  BirthdayDate? bday;
  final phones = <String>[];
  final emails = <String>[];
  for (final line in lines) {
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    var prop = line.substring(0, colon).toUpperCase();
    final value = _unescape(line.substring(colon + 1).trim());
    if (value.isEmpty) continue;
    final dot = prop.indexOf('.');
    if (dot >= 0 && dot < prop.indexOf(';').clamp(0, prop.length)) {
      prop = prop.substring(dot + 1);
    } else if (dot >= 0 && !prop.contains(';')) {
      prop = prop.substring(dot + 1);
    }
    final name = prop.split(';').first;
    switch (name) {
      case 'FN':
        fn = value;
      case 'N':
        final parts = value.split(';');
        final given = parts.length > 1 ? parts[1] : '';
        n = [given, parts[0]].where((p) => p.trim().isNotEmpty).join(' ');
      case 'TEL':
        phones.add(
          value.replaceFirst(RegExp(r'^tel:', caseSensitive: false), ''),
        );
      case 'EMAIL':
        emails.add(
          value.replaceFirst(RegExp(r'^mailto:', caseSensitive: false), ''),
        );
      case 'BDAY':
        final (d, _) = parseLooseDate(value.split('T').first);
        if (d != null && d.isValid) bday = d;
      case 'UID':
        uid = value;
      case 'NOTE':
        note = value;
    }
  }
  return ParsedVCard(
    name: (fn != null && fn.trim().isNotEmpty)
        ? fn.trim()
        : (n?.trim().isEmpty ?? true ? null : n!.trim()),
    phones: phones,
    emails: emails,
    birthday: bday,
    uid: uid,
    note: note,
  );
}

String _unescape(String v) => v
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\N', '\n')
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';')
    .replaceAll(r'\\', r'\');
