import 'package:flutter_test/flutter_test.dart';

import 'package:prism_plurality/features/account/account_core.dart';

void main() {
  test(
    'login secret is stable, salted by username, and hides the password',
    () async {
      final a = await deriveLoginSecret('Moon', 'correct horse battery');
      final b = await deriveLoginSecret('moon ', 'correct horse battery');
      final c = await deriveLoginSecret('sun', 'correct horse battery');
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(a, b);
      expect(a, isNot(c));
      expect(a.contains('horse'), isFalse);
    },
  );

  test('recovery key format and normalising', () {
    final k = newRecoveryKey();
    expect(k, matches(RegExp(r'^[A-Z2-9]{5}(-[A-Z2-9]{5}){4}$')));
    expect(normalizeRecoveryKey(k.toLowerCase()), k.replaceAll('-', ''));
  });

  test('backup key wraps with the password and only unwraps with it', () async {
    final k = newRecoveryKey();
    final wrapped = await wrapKey(k, 'pass-one-two');
    expect(await unwrapKey(wrapped, 'pass-one-two'), normalizeRecoveryKey(k));
    expect(await unwrapKey(wrapped, 'wrong'), isNull);
  });

  test('saved account round-trips', () {
    final a = SavedAccount(
      server: 'https://x.test',
      username: 'moon',
      userId: 'u1',
      token: 't' * 64,
      backupKey: 'K' * 25,
      lastBackupAt: DateTime(2026, 1, 2),
    );
    final b = SavedAccount.fromJson(a.toJson());
    expect(b.key, a.key);
    expect(b.backupKey, a.backupKey);
    expect(b.lastBackupAt, a.lastBackupAt);
    expect(b.autoBackup, isTrue);
  });
}
