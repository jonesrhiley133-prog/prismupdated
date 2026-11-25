import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:qr_flutter/qr_flutter.dart';

import 'package:prism_plurality/features/account/account_core.dart';
import 'package:prism_plurality/features/prism_social/social_remote.dart'
    show socialConnectionProvider;
import 'package:prism_plurality/shared/ui_kit.dart';

Future<T?> _push<T>(BuildContext context, Widget page) => Navigator.of(
  context,
  rootNavigator: true,
).push<T>(MaterialPageRoute(builder: (_) => page));

String _fmt(DateTime t) => DateFormat.yMMMd().add_jm().format(t.toLocal());
String _size(int b) => b > 1024 * 1024
    ? '${(b / 1024 / 1024).toStringAsFixed(1)} MB'
    : '${(b / 1024).ceil()} KB';

/// Fetches the signed-in account's profile and devices.
final _meProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, String>((ref, key) async {
      final a = ref
          .watch(accountsProvider)
          .value
          ?.accounts
          .where((x) => x.key == key)
          .firstOrNull;
      if (a == null) return const {};
      return AccountClient(a.server, a.token).get('/v1/accounts/me');
    });

final _backupsProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>((ref, key) async {
      final a = ref
          .watch(accountsProvider)
          .value
          ?.accounts
          .where((x) => x.key == key)
          .firstOrNull;
      if (a == null) return const [];
      return ref.read(accountActionsProvider).listBackups(a);
    });

/// Settings → Account & backup.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountsProvider);
    final a = state.value?.active;
    return PrismPageScaffold(
      topBar: const PrismTopBar(
        title: 'Account & backup',
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: state.isLoading
            ? const PrismLoadingState()
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  32 + NavBarInset.of(context),
                ),
                children: a == null
                    ? _signedOut(context)
                    : _signedIn(context, ref, a, state.value!),
              ),
      ),
    );
  }

  List<Widget> _signedOut(BuildContext context) {
    final theme = Theme.of(context);
    return [
      PrismSurface(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_done_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text('An account is optional', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Prism works fully without one. An account adds encrypted cloud backups you can restore on any device.',
            ),
            const SizedBox(height: 12),
            for (final (i, t) in const [
              (
                Icons.lock_outline,
                'End-to-end encrypted: backups are locked on your device. The server can\'t read them, and never sees your password.',
              ),
              (
                Icons.key_outlined,
                'You get a recovery key. Keep it safe — if you forget your password, it\'s the only way back into your backups.',
              ),
              (
                Icons.devices_outlined,
                'Sign in on several devices, see where you\'re signed in, and add two-step codes.',
              ),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(i, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t, style: theme.textTheme.bodySmall)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: PrismButton(
                    label: 'Create account',
                    tone: PrismButtonTone.filled,
                    onPressed: () =>
                        _push(context, const _AuthScreen(create: true)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrismButton(
                    label: 'Sign in',
                    tone: PrismButtonTone.outlined,
                    onPressed: () =>
                        _push(context, const _AuthScreen(create: false)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _signedIn(
    BuildContext context,
    WidgetRef ref,
    SavedAccount a,
    AccountsState all,
  ) {
    final theme = Theme.of(context);
    return [
      PrismSurface(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(a.username.characters.first.toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.username, style: theme.textTheme.titleMedium),
                  Text(
                    [
                      if (a.email != null) a.email!,
                      Uri.tryParse(a.server)?.host ?? a.server,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (a.backupKey == null) ...[
        const SizedBox(height: 10),
        PrismSurface(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Backups are locked on this device',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter your recovery key to back up and restore here.',
              ),
              const SizedBox(height: 8),
              PrismButton(
                label: 'Enter recovery key',
                icon: Icons.key_outlined,
                onPressed: () => _enterRecovery(context, ref, a),
              ),
            ],
          ),
        ),
      ],
      PrismSectionHeader(title: 'BACKUPS'),
      _BackupsCard(account: a),
      PrismSectionHeader(title: 'SECURITY'),
      PrismSurface(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            PrismListRow(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Two-step sign-in'),
              subtitle: Text(
                a.twoStep
                    ? 'On — a code from your authenticator app is needed to sign in'
                    : 'Off',
              ),
              showChevron: true,
              onTap: () => _push(context, _TwoStepScreen(account: a)),
            ),
            PrismListRow(
              leading: const Icon(Icons.password),
              title: const Text('Change password'),
              showChevron: true,
              onTap: () => _push(context, _ChangePasswordScreen(account: a)),
            ),
            PrismListRow(
              leading: const Icon(Icons.devices_outlined),
              title: const Text('Devices'),
              subtitle: const Text('Where you\'re signed in'),
              showChevron: true,
              onTap: () => _push(context, _DevicesScreen(account: a)),
            ),
            PrismListRow(
              leading: const Icon(Icons.key_outlined),
              title: const Text('Recovery key'),
              subtitle: Text(
                a.backupKey == null
                    ? 'Not on this device'
                    : 'Saved on this device',
              ),
              onTap: () => _enterRecovery(context, ref, a),
            ),
          ],
        ),
      ),
      PrismSectionHeader(title: 'ACCOUNTS'),
      PrismSurface(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (final x in all.accounts)
              PrismListRow(
                leading: Icon(
                  x.key == a.key
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: x.key == a.key ? theme.colorScheme.primary : null,
                ),
                title: Text(x.username),
                subtitle: Text(Uri.tryParse(x.server)?.host ?? x.server),
                onTap: x.key == a.key
                    ? null
                    : () => ref.read(accountsProvider.notifier).activate(x.key),
              ),
            PrismListRow(
              leading: const Icon(Icons.person_add_alt),
              title: const Text('Add another account'),
              onTap: () => _push(context, const _AuthScreen(create: false)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      PrismButton(
        label: 'Sign out of ${a.username}',
        icon: Icons.logout,
        tone: PrismButtonTone.outlined,
        expanded: true,
        onPressed: () => signOutFlow(context, ref, a),
      ),
      const SizedBox(height: 8),
      PrismButton(
        label: 'Delete account',
        icon: Icons.delete_outline,
        tone: PrismButtonTone.destructive,
        expanded: true,
        onPressed: () => _deleteAccount(context, ref, a),
      ),
    ];
  }

  Future<void> _enterRecovery(
    BuildContext context,
    WidgetRef ref,
    SavedAccount a,
  ) async {
    final c = TextEditingController(text: a.backupKey == null ? '' : '');
    final ok = await PrismDialog.show<bool>(
      context: context,
      title: 'Recovery key',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a.backupKey != null) ...[
            SelectableText(
              _group(a.backupKey!),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep a copy somewhere safe. Enter a different key below only if you were given a new one.',
            ),
            const SizedBox(height: 8),
          ],
          PrismTextField(
            controller: c,
            hintText: 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      ),
      actions: [
        PrismButton(
          label: 'Close',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        PrismButton(
          label: 'Save key',
          tone: PrismButtonTone.filled,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    final key = normalizeRecoveryKey(c.text);
    c.dispose();
    if (ok == true && key.length == 25) {
      await ref.read(accountActionsProvider).useRecoveryKey(a, key);
      if (context.mounted)
        PrismToast.show(context, message: 'Recovery key saved on this device');
    } else if (ok == true && context.mounted) {
      PrismToast.show(
        context,
        message: 'A recovery key has 25 letters and numbers',
      );
    }
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    SavedAccount a,
  ) async {
    final c = TextEditingController();
    final ok = await PrismDialog.show<bool>(
      context: context,
      title: 'Delete account?',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This deletes the account and every backup in it. Data on this device is kept. This can\'t be undone.',
          ),
          const SizedBox(height: 10),
          PrismTextField(
            controller: c,
            labelText: 'Password',
            obscureText: true,
          ),
        ],
      ),
      actions: [
        PrismButton(
          label: 'Cancel',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        PrismButton(
          label: 'Delete',
          tone: PrismButtonTone.destructive,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    final pw = c.text;
    c.dispose();
    if (ok != true) return;
    try {
      await ref.read(accountActionsProvider).deleteAccount(a, pw);
      if (context.mounted) PrismToast.show(context, message: 'Account deleted');
    } catch (e) {
      if (context.mounted) PrismToast.show(context, message: '$e');
    }
  }
}

String _group(String k) => [
  for (var i = 0; i < k.length; i += 5)
    k.substring(i, (i + 5).clamp(0, k.length)),
].join('-');

class _BackupsCard extends ConsumerStatefulWidget {
  const _BackupsCard({required this.account});
  final SavedAccount account;
  @override
  ConsumerState<_BackupsCard> createState() => _BackupsCardState();
}

class _BackupsCardState extends ConsumerState<_BackupsCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f, String done) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) PrismToast.show(context, message: done);
      ref.invalidate(_backupsProvider(widget.account.key));
    } catch (e) {
      if (mounted) PrismToast.show(context, message: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(activeAccountProvider) ?? widget.account;
    final list = ref.watch(_backupsProvider(a.key));
    final actions = ref.read(accountActionsProvider);
    final theme = Theme.of(context);
    return PrismSurface(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          PrismSwitchRow(
            title: 'Automatic backups',
            subtitle: 'Once a day while Prism is open. The newest 10 are kept.',
            value: a.autoBackup,
            onChanged: (v) => ref
                .read(accountsProvider.notifier)
                .replace(a.copyWith(autoBackup: v)),
          ),
          PrismListRow(
            title: Text(
              a.lastBackupAt == null
                  ? 'No backup from this device yet'
                  : 'Last backup ${_fmt(a.lastBackupAt!)}',
            ),
            trailing: PrismButton(
              label: 'Back up now',
              density: PrismControlDensity.compact,
              isLoading: _busy,
              enabled: a.backupKey != null,
              onPressed: () => _run(() => actions.backUpNow(a), 'Backed up'),
            ),
          ),
          const Divider(height: 1),
          list.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: PrismLoadingState(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '$e',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            data: (items) => items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No backups in your account yet.'),
                  )
                : Column(
                    children: [
                      for (final b in items)
                        PrismListRow(
                          leading: Icon(
                            b['label'] == 'Automatic backup'
                                ? Icons.schedule
                                : Icons.backup_outlined,
                          ),
                          title: Text('${b['label']}'),
                          subtitle: Text(
                            '${_fmt(DateTime.parse('${b['createdAt']}'))} · ${b['device']} · ${_size((b['size'] as num).toInt())}',
                          ),
                          trailing: PrismPopupMenu<String>(
                            items: const [
                              PrismMenuItem(
                                value: 'restore',
                                label: 'Restore',
                                icon: Icons.restore,
                              ),
                              PrismMenuItem(
                                value: 'delete',
                                label: 'Delete',
                                icon: Icons.delete_outline,
                                destructive: true,
                              ),
                            ],
                            onSelected: (v) async {
                              if (v == 'restore') {
                                final ok = await PrismDialog.confirm(
                                  context: context,
                                  title: 'Restore this backup?',
                                  message:
                                      'Its data is merged into this device. Make a backup first if you\'re unsure.',
                                  confirmLabel: 'Restore',
                                );
                                if (ok)
                                  await _run(
                                    () => actions.restore(a, '${b['id']}'),
                                    'Backup restored',
                                  );
                              } else {
                                final ok = await PrismDialog.confirm(
                                  context: context,
                                  title: 'Delete this backup?',
                                  confirmLabel: 'Delete',
                                  destructive: true,
                                );
                                if (ok)
                                  await _run(
                                    () => actions.deleteBackup(a, '${b['id']}'),
                                    'Backup deleted',
                                  );
                              }
                            },
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Sign in or create an account.
class _AuthScreen extends ConsumerStatefulWidget {
  const _AuthScreen({required this.create});
  final bool create;
  @override
  ConsumerState<_AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<_AuthScreen> {
  late final _server = TextEditingController(
    text:
        ref.read(socialConnectionProvider)?.url ??
        ref.read(activeAccountProvider)?.server ??
        '',
  );
  final _user = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _code = TextEditingController();
  bool _needCode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_server, _user, _email, _pw, _pw2, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final server = _server.text.trim();
    if (server.isEmpty)
      return setState(() => _error = 'Enter your Prism server address.');
    if (_user.text.trim().length < 3)
      return setState(() => _error = 'Enter your username.');
    if (widget.create) {
      if (_pw.text.length < 10)
        return setState(
          () => _error = 'Use at least 10 characters for your password.',
        );
      if (_pw.text != _pw2.text)
        return setState(() => _error = "The passwords don't match.");
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final actions = ref.read(accountActionsProvider);
    try {
      if (widget.create) {
        final key = await actions.signUp(
          server: server,
          username: _user.text,
          email: _email.text.trim().isEmpty ? null : _email.text,
          password: _pw.text,
        );
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => _RecoveryKeyScreen(recoveryKey: key),
          ),
        );
      } else {
        final unlocked = await actions.signIn(
          server: server,
          login: _user.text,
          password: _pw.text,
          code: _needCode ? _code.text : null,
        );
        if (!mounted) return;
        PrismToast.show(
          context,
          message: unlocked
              ? 'Signed in'
              : 'Signed in — enter your recovery key to unlock backups',
        );
        Navigator.of(context).pop();
      }
    } on AccountError catch (e) {
      setState(() {
        if (e.code == 'code_required') _needCode = true;
        _error = e.message ?? e.code;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: widget.create ? 'Create account' : 'Sign in',
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            32 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            PrismTextField(
              controller: _server,
              labelText: 'Server',
              hintText: 'prism-social.up.railway.app',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            PrismTextField(
              controller: _user,
              labelText: 'Username',
              textInputAction: TextInputAction.next,
            ),
            if (widget.create) ...[
              const SizedBox(height: 12),
              PrismTextField(
                controller: _email,
                labelText: 'Email (optional)',
                keyboardType: TextInputType.emailAddress,
                helperText: 'Only for contact. Sign-in uses your username.',
              ),
            ],
            const SizedBox(height: 12),
            PrismTextField(
              controller: _pw,
              labelText: 'Password',
              obscureText: true,
            ),
            if (widget.create) ...[
              const SizedBox(height: 12),
              PrismTextField(
                controller: _pw2,
                labelText: 'Repeat password',
                obscureText: true,
              ),
            ],
            if (_needCode) ...[
              const SizedBox(height: 12),
              PrismTextField(
                controller: _code,
                labelText: '6-digit code',
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            PrismButton(
              label: widget.create ? 'Create account' : 'Sign in',
              tone: PrismButtonTone.filled,
              expanded: true,
              isLoading: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            Text(
              widget.create
                  ? "Your password never leaves this device — Prism can't reset it. You'll get a recovery key next; it's the only way back into backups if you forget your password."
                  : 'Signing in takes a few seconds while your password is turned into a secure key on this device.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryKeyScreen extends StatelessWidget {
  const _RecoveryKeyScreen({required this.recoveryKey});
  final String recoveryKey;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: const PrismTopBar(title: 'Your recovery key'),
      body: ClampedBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Save this key somewhere safe — a password manager, or written down. It unlocks your backups if you forget your password. Prism can\'t show it to anyone else or recover it for you.',
            ),
            const SizedBox(height: 20),
            PrismSurface(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: SelectableText(
                  recoveryKey,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PrismButton(
              label: 'Copy',
              icon: Icons.copy,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: recoveryKey));
                PrismToast.show(context, message: 'Copied');
              },
            ),
            const SizedBox(height: 24),
            PrismButton(
              label: "I've saved it",
              tone: PrismButtonTone.filled,
              expanded: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TwoStepScreen extends ConsumerStatefulWidget {
  const _TwoStepScreen({required this.account});
  final SavedAccount account;
  @override
  ConsumerState<_TwoStepScreen> createState() => _TwoStepScreenState();
}

class _TwoStepScreenState extends ConsumerState<_TwoStepScreen> {
  String? _secret, _uri, _error;
  final _code = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _pw.dispose();
    super.dispose();
  }

  SavedAccount get _a => ref.read(activeAccountProvider) ?? widget.account;
  AccountClient get _c => AccountClient(_a.server, _a.token);

  Future<void> _go(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
    } on AccountError catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = (ref.watch(activeAccountProvider) ?? widget.account).twoStep;
    final theme = Theme.of(context);
    return PrismPageScaffold(
      topBar: const PrismTopBar(
        title: 'Two-step sign-in',
        showBackButton: true,
      ),
      body: ClampedBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              on
                  ? 'Two-step sign-in is on. Signing in on a new device needs your password and a code from your authenticator app.'
                  : 'Add a second step: a 6-digit code from an authenticator app (like Aegis, 2FAS, Google Authenticator or 1Password) when signing in.',
            ),
            const SizedBox(height: 16),
            if (!on && _secret == null)
              PrismButton(
                label: 'Set up',
                tone: PrismButtonTone.filled,
                isLoading: _busy,
                onPressed: () => _go(() async {
                  final r = await _c.post('/v1/accounts/totp/setup', const {});
                  setState(() {
                    _secret = r['secret'] as String?;
                    _uri = r['uri'] as String?;
                  });
                }),
              ),
            if (!on && _secret != null) ...[
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(10),
                  child: QrImageView(data: _uri!, size: 200),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Scan this in your authenticator app, or enter this key:',
              ),
              SelectableText(
                _secret!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              PrismTextField(
                controller: _code,
                labelText: '6-digit code',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
              ),
              const SizedBox(height: 8),
              PrismButton(
                label: 'Turn on',
                tone: PrismButtonTone.filled,
                isLoading: _busy,
                onPressed: () => _go(() async {
                  await _c.post('/v1/accounts/totp/enable', {
                    'code': _code.text,
                  });
                  await ref
                      .read(accountsProvider.notifier)
                      .replace(_a.copyWith(twoStep: true));
                  if (context.mounted)
                    PrismToast.show(context, message: 'Two-step sign-in is on');
                }),
              ),
            ],
            if (on) ...[
              PrismTextField(
                controller: _pw,
                labelText: 'Password',
                obscureText: true,
              ),
              const SizedBox(height: 8),
              PrismButton(
                label: 'Turn off',
                tone: PrismButtonTone.destructive,
                isLoading: _busy,
                onPressed: () => _go(() async {
                  await _c.post('/v1/accounts/totp/disable', {
                    'secret': await deriveLoginSecret(_a.username, _pw.text),
                  });
                  await ref
                      .read(accountsProvider.notifier)
                      .replace(_a.copyWith(twoStep: false));
                  if (context.mounted)
                    PrismToast.show(
                      context,
                      message: 'Two-step sign-in is off',
                    );
                }),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordScreen extends ConsumerStatefulWidget {
  const _ChangePasswordScreen({required this.account});
  final SavedAccount account;
  @override
  ConsumerState<_ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<_ChangePasswordScreen> {
  final _cur = TextEditingController(),
      _new = TextEditingController(),
      _new2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _new2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrismPageScaffold(
    topBar: const PrismTopBar(title: 'Change password', showBackButton: true),
    body: ClampedBody(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PrismTextField(
            controller: _cur,
            labelText: 'Current password',
            obscureText: true,
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _new,
            labelText: 'New password',
            obscureText: true,
          ),
          const SizedBox(height: 12),
          PrismTextField(
            controller: _new2,
            labelText: 'Repeat new password',
            obscureText: true,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          PrismButton(
            label: 'Change password',
            tone: PrismButtonTone.filled,
            expanded: true,
            isLoading: _busy,
            onPressed: () async {
              if (_new.text.length < 10)
                return setState(() => _error = 'Use at least 10 characters.');
              if (_new.text != _new2.text)
                return setState(
                  () => _error = "The new passwords don't match.",
                );
              setState(() {
                _busy = true;
                _error = null;
              });
              try {
                await ref
                    .read(accountActionsProvider)
                    .changePassword(
                      ref.read(activeAccountProvider) ?? widget.account,
                      _cur.text,
                      _new.text,
                    );
                if (!context.mounted) return;
                PrismToast.show(
                  context,
                  message: 'Password changed. Other devices were signed out.',
                );
                Navigator.of(context).pop();
              } catch (e) {
                setState(() => _error = '$e');
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Your backups stay readable, and your recovery key doesn\'t change.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _DevicesScreen extends ConsumerWidget {
  const _DevicesScreen({required this.account});
  final SavedAccount account;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(_meProvider(account.key));
    return PrismPageScaffold(
      topBar: const PrismTopBar(title: 'Devices', showBackButton: true),
      body: ClampedBody(
        child: me.when(
          loading: () => const PrismLoadingState(),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('$e'),
            ),
          ),
          data: (m) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PrismSurface(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final s
                        in (m['sessions'] as List? ?? const []).cast<Map>())
                      PrismListRow(
                        leading: Icon(
                          s['platform'] == 'web'
                              ? Icons.language
                              : Icons.smartphone,
                        ),
                        title: Text(
                          '${s['device']}${s['current'] == true ? ' (this device)' : ''}',
                        ),
                        subtitle: Text(
                          'Signed in ${_fmt(DateTime.parse('${s['createdAt']}'))} · active ${_fmt(DateTime.parse('${s['lastSeen']}'))}',
                        ),
                        trailing: s['current'] == true
                            ? null
                            : PrismButton(
                                label: 'Sign out',
                                density: PrismControlDensity.compact,
                                onPressed: () async {
                                  try {
                                    await AccountClient(
                                      account.server,
                                      account.token,
                                    ).delete(
                                      '/v1/accounts/sessions/${s['id']}',
                                    );
                                    ref.invalidate(_meProvider(account.key));
                                  } catch (e) {
                                    if (context.mounted)
                                      PrismToast.show(context, message: '$e');
                                  }
                                },
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signs out after a warning when the latest changes aren't backed up, then
/// shows the sign-in screen. Data on this device is never deleted.
Future<void> signOutFlow(
  BuildContext context,
  WidgetRef ref,
  SavedAccount a,
) async {
  final stale =
      a.backupKey != null &&
      (a.lastBackupAt == null ||
          DateTime.now().difference(a.lastBackupAt!) >
              const Duration(hours: 24));
  final pick = await PrismDialog.show<String>(
    context: context,
    title: 'Sign out of ${a.username}?',
    message: stale
        ? 'There\'s no backup from this device in the last day, so recent changes aren\'t in your account yet. Your data stays on this device either way.'
        : 'Your data stays on this device. Backups stay in your account.',
    builder: (_) => const SizedBox.shrink(),
    actions: [
      PrismButton(
        label: 'Cancel',
        onPressed: () =>
            Navigator.of(context, rootNavigator: true).pop('cancel'),
      ),
      if (stale)
        PrismButton(
          label: 'Back up, then sign out',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop('backup'),
        ),
      PrismButton(
        label: 'Sign out',
        tone: PrismButtonTone.filled,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop('out'),
      ),
    ],
  );
  if (pick == null || pick == 'cancel' || !context.mounted) return;
  final actions = ref.read(accountActionsProvider);
  if (pick == 'backup') {
    try {
      await actions.backUpNow(a, label: 'Before signing out');
    } catch (e) {
      if (context.mounted)
        PrismToast.show(
          context,
          message: 'Backup failed: $e — still signed in.',
        );
      return;
    }
  }
  await actions.signOut(a);
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => const AccountAuthScreen(signedOut: true),
    ),
    (r) => r.isFirst,
  );
}

/// Where you land after signing out (or when choosing an account): saved
/// accounts, sign in, create one, or carry on without an account. Only
/// sign-in methods Prism actually supports are shown.
class AccountAuthScreen extends ConsumerWidget {
  const AccountAuthScreen({super.key, this.signedOut = false});
  final bool signedOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final saved =
        ref.watch(accountsProvider).value?.accounts ?? const <SavedAccount>[];
    return PrismPageScaffold(
      body: SafeArea(
        child: ClampedBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            children: [
              Icon(
                Icons.account_circle_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                signedOut ? 'You\'re signed out' : 'Choose an account',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Everything on this device is still here. Sign in to back up and restore, or keep going without an account.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (saved.isNotEmpty) ...[
                Text('Saved accounts', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                PrismSurface(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final x in saved)
                        PrismListRow(
                          leading: CircleAvatar(
                            child: Text(
                              x.username.characters.first.toUpperCase(),
                            ),
                          ),
                          title: Text(x.username),
                          subtitle: Text(
                            Uri.tryParse(x.server)?.host ?? x.server,
                          ),
                          showChevron: true,
                          onTap: () async {
                            await ref
                                .read(accountsProvider.notifier)
                                .activate(x.key);
                            if (context.mounted)
                              await Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AccountScreen(),
                                ),
                              );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              PrismButton(
                label: 'Sign in',
                icon: Icons.login,
                tone: PrismButtonTone.filled,
                expanded: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _AuthScreen(create: false),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PrismButton(
                label: 'Create an account',
                icon: Icons.person_add_alt,
                expanded: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _AuthScreen(create: true),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PrismButton(
                label: 'Continue without an account',
                icon: Icons.offline_bolt_outlined,
                expanded: true,
                onPressed: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).popUntil((r) => r.isFirst),
              ),
              const SizedBox(height: 16),
              Center(
                child: PrismButton(
                  label: 'Forgot your password?',
                  density: PrismControlDensity.compact,
                  onPressed: () => PrismDialog.show<void>(
                    context: context,
                    title: 'Forgot your password?',
                    message:
                        'Prism never sees your password, so it can\'t reset it — that\'s what keeps backups private. If you saved your recovery key, you can still restore a downloaded backup with it, and create a new account. Without the password or the key, backups in the old account can\'t be opened.',
                    builder: (_) => const SizedBox.shrink(),
                    actions: [
                      PrismButton(
                        label: 'OK',
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Google, Microsoft and Facebook sign-in aren\'t available: Prism accounts are end-to-end encrypted with your own password.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
