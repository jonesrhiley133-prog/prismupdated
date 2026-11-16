import 'package:flutter_test/flutter_test.dart';
import 'package:prism_plurality/features/fitness/health/fitness_file_import.dart';

void main() {
  test(
    'Garmin quoted CSV preview normalizes miles and repeat imports have stable source identity',
    () {
      const csv =
          'Activity Type,Date,Title,Distance,Calories,Time,Avg HR\r\nRunning,2026-03-02 09:00:00,"Morning, run",3.1,300,00:30:00,120\r\nRunning,not-a-date,Bad,4,300,00:30:00,120';
      final p = parseFitnessCsv(csv, miles: true, account: 'a');
      expect(p.records.length, 1);
      expect(p.skipped, 1);
      expect(p.records.single.title, 'Morning, run');
      expect(p.records.single.number('distanceKm'), closeTo(4.9889664, .0001));
      expect(p.records.single.integer('minutes'), 30);
      final repeated = parseFitnessCsv(
        csv.replaceAll(',300,', ',350,'),
        miles: true,
        account: 'a',
      );
      expect(repeated.records.single.id, p.records.single.id);
      expect(repeated.records.single.integer('calories'), 350);
      expect(
        parseFitnessCsv(
          csv,
          miles: true,
          account: 'different account',
        ).records.single.id,
        isNot(p.records.single.id),
      );
    },
  );
  test(
    'Fitbit total calories are distinct from active energy and invalid rows are counted',
    () {
      const csv =
          'Date,Steps,Distance,Calories Burned\n2026-03-02,4200,3.2,2100\n03/04/2026,5000,4,2000\n2026-03-03,-2,3,2000';
      final p = parseFitnessCsv(csv, miles: false, account: 'a');
      expect(p.skipped, 2);
      expect(p.records.single.integer('steps'), 4200);
      expect(p.records.single.integer('totalEnergyKcal'), 2100);
      expect(p.records.single.fields['calories'], isNull);
    },
  );
  test('malformed or unsupported data never produces a successful preview', () {
    expect(
      () => parseFitnessCsv(
        'Date,Steps\n"unterminated',
        miles: false,
        account: 'a',
      ),
      throwsFormatException,
    );
    expect(
      () => parseFitnessCsv('Name,Value\nabc,2', miles: false, account: 'a'),
      throwsFormatException,
    );
    expect(
      () => parseFitnessCsv(
        'Date,Steps\n2026-03-02,50',
        miles: false,
        account: '',
      ),
      throwsFormatException,
    );
  });
}
