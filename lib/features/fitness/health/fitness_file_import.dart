import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/enums.dart';
import 'package:prism_plurality/core/database/database_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import '../utils/fitness.dart';

/// Deliberately narrow CSV support: Fitbit daily activity and Garmin's
/// Activities export. A preview requires the user to choose distance units;
/// neither provider's unit preference is reliably encoded in CSV headers.
class FitnessFilePreview {
  const FitnessFilePreview(this.provider, this.records, this.skipped);
  final String provider;
  final List<TrackerRecord> records;
  final int skipped;
}

List<List<String>> _csv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '"') {
      if (quoted && i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ',' && !quoted) {
      row.add(field.toString());
      field = StringBuffer();
    } else if ((c == '\n' || c == '\r') && !quoted) {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      if (row.any((v) => v.trim().isNotEmpty)) rows.add(row);
      row = [];
      field = StringBuffer();
    } else {
      field.write(c);
    }
  }
  if (quoted) throw const FormatException('Unclosed CSV quote.');
  row.add(field.toString());
  if (row.any((v) => v.trim().isNotEmpty)) rows.add(row);
  return rows;
}

FitnessFilePreview parseFitnessCsv(
  String text, {
  required bool miles,
  required String account,
  String dateOrder = 'iso',
}) {
  if (text.length > 10000000) {
    throw const FormatException('File exceeds 10 MB.');
  }
  if (account.trim().isEmpty) {
    throw const FormatException(
      'Enter an account label to keep sources separate.',
    );
  }
  final rows = _csv(text.replaceFirst('\ufeff', ''));
  final headerIndex = rows.indexWhere(
    (r) =>
        r.contains('Date') &&
        (r.contains('Steps') || r.contains('Activity Type')),
  );
  if (headerIndex < 0) {
    throw const FormatException(
      'Expected Fitbit daily activity or Garmin Activities CSV headers.',
    );
  }
  final headers = rows[headerIndex].map((s) => s.trim()).toList();
  final garmin = headers.contains('Activity Type');
  if (!headers.contains(garmin ? 'Time' : 'Steps')) {
    throw const FormatException('Required columns missing.');
  }
  final provider = garmin ? 'Garmin CSV' : 'Fitbit CSV';
  final out = <TrackerRecord>[];
  var skipped = 0;
  for (final row in rows.skip(headerIndex + 1)) {
    String cell(String key) {
      final i = headers.indexOf(key);
      return i < 0 || i >= row.length ? '' : row[i].trim();
    }

    double? number(String key) =>
        double.tryParse(cell(key).replaceAll(',', ''));
    try {
      final rawDate = cell('Date');
      DateTime? date;
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(rawDate)) {
        date = DateTime.tryParse(rawDate);
      } else if (dateOrder != 'iso') {
        final parts = rawDate.split('/');
        if (parts.length == 3) {
          final a = int.tryParse(parts[0]),
              b = int.tryParse(parts[1]),
              y = int.tryParse(parts[2]);
          if (a != null && b != null && y != null) {
            final month = dateOrder == 'monthFirst' ? a : b,
                day = dateOrder == 'monthFirst' ? b : a;
            final candidate = DateTime(y, month, day);
            if (candidate.year == y &&
                candidate.month == month &&
                candidate.day == day) {
              date = candidate;
            }
          }
        }
      }
      if (date == null) throw const FormatException();
      final distance = number('Distance');
      final fields = <String, Object?>{
        'imported': true,
        'source': provider,
        'platform': 'file',
        'accountLabel': account.trim(),
        'sourceStart': date.toIso8601String(),
        if (distance != null)
          FitField.distanceKm: distance * (miles ? 1.609344 : 1),
      };
      if (garmin) {
        final parts = cell('Time').split(':').map(double.parse).toList();
        if (parts.length < 2 || parts.length > 3) throw const FormatException();
        final minutes = parts.length == 3
            ? parts[0] * 60 + parts[1] + parts[2] / 60
            : parts[0] + parts[1] / 60;
        if (minutes <= 0) throw const FormatException();
        fields.addAll({
          FitField.activity: _activity(cell('Activity Type')),
          FitField.minutes: minutes.round(),
          FitField.calories: number('Calories')?.round(),
          FitField.heartRate: number('Avg HR')?.round(),
        });
      } else {
        final steps = number('Steps');
        if (steps == null || steps < 0 || steps != steps.roundToDouble()) {
          throw const FormatException();
        }
        // Fitbit's Calories Burned is total energy, not active energy.
        fields.addAll({
          'steps': steps.toInt(),
          'totalEnergyKcal': number('Calories Burned')?.round(),
        });
      }
      if (distance != null && (distance < 0 || !distance.isFinite)) {
        throw const FormatException();
      }
      final key =
          '$provider:${account.trim()}:${date.toIso8601String()}:${garmin ? cell('Activity Type') : 'daily'}:${garmin ? cell('Title') : ''}';
      final sourceId = sha256.convert(utf8.encode(key)).toString();
      fields.addAll({'sourceId': sourceId, 'sourceKey': 'file:$sourceId'});
      final now = DateTime.now();
      out.add(
        TrackerRecord(
          id: const Uuid().v5(
            Namespace.url.value,
            'prism:fitness:file:$sourceId',
          ),
          kind: garmin ? TrackerKind.fitnessWorkout : TrackerKind.fitnessDaily,
          title: garmin ? cell('Title') : '',
          occurredAt: date,
          createdAt: now,
          modifiedAt: now,
          isPrivate: true,
        ).withFields(fields),
      );
    } catch (_) {
      skipped++;
    }
  }
  if (out.isEmpty) {
    throw const FormatException(
      'No valid rows. Dates must use YYYY-MM-DD, optionally with a time.',
    );
  }
  return FitnessFilePreview(provider, out, skipped);
}

String _activity(String text) {
  final s = text.toLowerCase();
  if (s.contains('run')) return 'run';
  if (s.contains('walk')) return 'walk';
  if (s.contains('cycl') || s.contains('bik')) return 'cycle';
  if (s.contains('swim')) return 'swim';
  if (s.contains('strength')) return 'strength';
  return 'other';
}

Future<void> showFitnessFileImport(BuildContext context) =>
    PrismSheet.showFullScreen(
      context: context,
      builder: (ctx, scroll) => _FileImport(scroll: scroll),
    );

class _FileImport extends ConsumerStatefulWidget {
  const _FileImport({this.scroll});
  final ScrollController? scroll;
  @override
  ConsumerState<_FileImport> createState() => _FileImportState();
}

class _FileImportState extends ConsumerState<_FileImport> {
  final _account = TextEditingController();
  String _dateOrder = 'iso';
  bool _miles = false, _busy = false;
  FitnessFilePreview? _preview;
  String? _error;
  Uint8List? _bytes;
  @override
  void dispose() {
    _account.dispose();
    super.dispose();
  }

  void _parse() {
    try {
      _preview = parseFitnessCsv(
        utf8.decode(_bytes!),
        miles: _miles,
        account: _account.text,
        dateOrder: _dateOrder,
      );
      _error = null;
    } catch (e) {
      _preview = null;
      _error = e is FormatException ? e.message : 'Could not read this file.';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Import fitness file')),
    body: ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Supported: Fitbit daily activity CSV and Garmin Activities CSV. Choose the date format and distance units used in your export. CSV imports are separate from on-device Sync now. No provider password is needed.',
        ),
        TextField(
          controller: _account,
          decoration: const InputDecoration(
            labelText: 'Source account label',
            helperText:
                'Use the same label on repeat imports. Stored privately.',
          ),
          onChanged: (_) => setState(() {
            if (_bytes != null) _parse();
          }),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _dateOrder,
          decoration: const InputDecoration(
            labelText: 'Date format in the export',
          ),
          items: const [
            DropdownMenuItem(value: 'iso', child: Text('YYYY-MM-DD')),
            DropdownMenuItem(
              value: 'monthFirst',
              child: Text('MM/DD/YYYY (Fitbit US)'),
            ),
            DropdownMenuItem(value: 'dayFirst', child: Text('DD/MM/YYYY')),
          ],
          onChanged: (v) => setState(() {
            _dateOrder = v!;
            if (_bytes != null) _parse();
          }),
        ),
        SwitchListTile(
          title: const Text('Distances in this export are miles'),
          subtitle: const Text(
            'Off means kilometers. Match the export’s provider settings.',
          ),
          value: _miles,
          onChanged: (v) => setState(() {
            _miles = v;
            if (_bytes != null) _parse();
          }),
        ),
        PrismButton(
          label: 'Choose CSV file',
          onPressed: () async {
            final picked = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['csv'],
              withData: true,
            );
            if (picked == null || !mounted) return;
            setState(() {
              _bytes = picked.files.single.bytes;
              if (_bytes == null) {
                _error = 'Could not read the file.';
              } else {
                _parse();
              }
            });
          },
        ),
        if (_error != null) Text(_error!),
        if (_preview case final p?) ...[
          Text(
            '${p.provider}: ${p.records.length} valid records · ${p.skipped} rows skipped.',
          ),
          Text(
            'Range: ${(p.records.map((r) => r.occurredAt!).toList()..sort()).first} to ${(p.records.map((r) => r.occurredAt!).toList()..sort()).last}',
          ),
          Text(
            'Types: ${p.records.first.kind == TrackerKind.fitnessWorkout ? 'workouts' : 'daily steps and distance (total energy kept separately)'}',
          ),
          const Text(
            'Existing records from this file source will be updated. Manual corrections are retained. Other sources and manual entries are retained.',
          ),
          PrismButton(
            label: 'Import previewed records',
            isLoading: _busy,
            onPressed: () async {
              if (_busy) return;
              setState(() => _busy = true);
              try {
                final repo = ref.read(trackerRecordRepositoryProvider);
                var added = 0, updated = 0;
                for (final incoming in p.records) {
                  final previous = await repo.getById(incoming.id);
                  if (previous == null) {
                    await repo.create(
                      incoming.withFields({'importSnapshot': incoming.fields}),
                    );
                    added++;
                  } else {
                    final snapshot =
                        (previous.fields['importSnapshot'] as Map?) ?? {};
                    final fields = Map<String, Object?>.from(incoming.fields);
                    for (final key in fields.keys.toList()) {
                      if (snapshot.containsKey(key) &&
                          previous.fields[key] != snapshot[key]) {
                        fields[key] = previous.fields[key];
                      }
                    }
                    await repo.update(
                      previous
                          .withFields({
                            ...fields,
                            'importSnapshot': incoming.fields,
                          })
                          .copyWith(modifiedAt: DateTime.now()),
                    );
                    updated++;
                  }
                }
                if (mounted) {
                  setState(() {
                    _error =
                        '$added new records · $updated updated · ${p.skipped} skipped. Saved to Fitness.';
                    _preview = null;
                  });
                }
              } catch (_) {
                if (mounted) {
                  setState(
                    () => _error =
                        'Some records could not be saved. Retry this file safely.',
                  );
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
        ],
      ],
    ),
  );
}
