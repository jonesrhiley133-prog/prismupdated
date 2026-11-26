import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prism_plurality/core/services/app_data_dir.dart';

/// Demo Mode keeps sample data in its own database file (`prism_demo.db`),
/// opened with the same key, while the real `prism.db` stays untouched.
/// Sync and PluralKit are switched off, and app settings are snapshotted on
/// entry and restored exactly on exit, so leaving Demo Mode brings back the
/// real alters, records, settings and dashboard.
abstract final class DemoMode {
  static const _kActive = 'prism.demo.active';
  static const _kDuration = 'prism.demo.duration';
  static const _kSeeded = 'prism.demo.seeded';
  static const _kBackup = 'prism.demo.realPrefs.v1';
  static const demoDbName = 'prism_demo.db';

  /// Read once at startup (before the database opens) and after restarts.
  static bool active = false;

  static void load(SharedPreferences prefs) {
    active = prefs.getBool(_kActive) ?? false;
  }

  static String duration(SharedPreferences prefs) =>
      prefs.getString(_kDuration) ?? '1m';
  static bool seeded(SharedPreferences prefs) =>
      prefs.getBool(_kSeeded) ?? false;
  static Future<void> markSeeded(SharedPreferences prefs) =>
      prefs.setBool(_kSeeded, true);

  static Future<File> demoFile() async =>
      File(p.join((await getAppDataDir()).path, demoDbName));

  static bool _isDemoKey(String k) => k.startsWith('prism.demo.');

  static Map<String, Object?> _snapshot(SharedPreferences prefs) {
    final out = <String, Object?>{};
    for (final k in prefs.getKeys()) {
      if (_isDemoKey(k)) continue;
      final v = prefs.get(k);
      out[k] = switch (v) {
        bool b => {'t': 'b', 'v': b},
        int i => {'t': 'i', 'v': i},
        double d => {'t': 'd', 'v': d},
        String s => {'t': 's', 'v': s},
        List l => {'t': 'l', 'v': l.cast<String>()},
        _ => null,
      };
    }
    return out;
  }

  /// Switches to Demo Mode. Takes effect after [AppRestartScope.restart].
  static Future<void> enter(
    SharedPreferences prefs,
    String duration, {
    bool freshData = true,
  }) async {
    if (prefs.getBool(_kActive) ?? false) return;
    final snap = jsonEncode(_snapshot(prefs));
    await prefs.setString(_kBackup, snap);
    // Second copy on disk in case preferences are cleared mid-demo.
    if (!kIsWeb) {
      try {
        await File(
          p.join((await getAppDataDir()).path, 'prism_demo_prefs_backup.json'),
        ).writeAsString(snap, flush: true);
      } catch (e) {
        debugPrint('[DEMO] could not write prefs backup file: $e');
      }
    }
    await prefs.setString(_kDuration, duration);
    if (freshData) {
      await prefs.setBool(_kSeeded, false);
      await _deleteDemoDb();
    }
    await prefs.setBool(_kActive, true);
  }

  /// Leaves Demo Mode and restores the real settings exactly.
  static Future<void> exit(
    SharedPreferences prefs, {
    bool keepDemoData = true,
  }) async {
    var raw = prefs.getString(_kBackup);
    if (raw == null && !kIsWeb) {
      try {
        final f = File(
          p.join((await getAppDataDir()).path, 'prism_demo_prefs_backup.json'),
        );
        if (await f.exists()) raw = await f.readAsString();
      } catch (_) {}
    }
    if (raw != null) {
      final snap = (jsonDecode(raw) as Map).cast<String, Object?>();
      for (final k in prefs.getKeys().toList()) {
        if (!_isDemoKey(k) && !snap.containsKey(k)) await prefs.remove(k);
      }
      for (final e in snap.entries) {
        final m = e.value;
        if (m is! Map) continue;
        final v = m['v'];
        switch (m['t']) {
          case 'b':
            await prefs.setBool(e.key, v as bool);
          case 'i':
            await prefs.setInt(e.key, (v as num).toInt());
          case 'd':
            await prefs.setDouble(e.key, (v as num).toDouble());
          case 's':
            await prefs.setString(e.key, v as String);
          case 'l':
            await prefs.setStringList(e.key, (v as List).cast<String>());
        }
      }
    }
    await prefs.setBool(_kActive, false);
    await prefs.remove(_kBackup);
    if (!keepDemoData) {
      await prefs.setBool(_kSeeded, false);
    }
  }

  /// Deletes the demo database file (only when the demo DB is not open).
  static Future<void> _deleteDemoDb() async {
    if (kIsWeb) return;
    try {
      final f = await demoFile();
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final x = File('${f.path}$suffix');
        if (await x.exists()) await x.delete();
      }
    } catch (e) {
      debugPrint('[DEMO] could not delete demo database: $e');
    }
  }

  /// Deletes the demo database before it opens when a regenerate was asked.
  static Future<void> wipeIfRequested(SharedPreferences prefs) async {
    if (prefs.getBool('prism.demo.wipeOnStart') != true) return;
    await _deleteDemoDb();
    await prefs.remove('prism.demo.wipeOnStart');
  }

  /// Called at startup when not in demo: removes leftover demo data that
  /// the user asked to discard.
  static Future<void> cleanupIfRequested(SharedPreferences prefs) async {
    if (active || seeded(prefs)) return;
    await _deleteDemoDb();
  }
}

/// Rebuilds everything under it (a fresh Riverpod container, so the
/// database reopens) when [restart] is called.
class AppRestartScope extends StatefulWidget {
  const AppRestartScope({super.key, required this.child});
  final Widget child;

  static void restart(BuildContext context) =>
      context.findAncestorStateOfType<_AppRestartScopeState>()?._restart();

  @override
  State<AppRestartScope> createState() => _AppRestartScopeState();
}

class _AppRestartScopeState extends State<AppRestartScope> {
  Key _key = UniqueKey();
  bool _blank = false;

  Future<void> _restart() async {
    // Unmount first so the old database closes before the new one opens.
    setState(() => _blank = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    DemoMode.load(prefs);
    await DemoMode.wipeIfRequested(prefs);
    if (!DemoMode.active) await DemoMode.cleanupIfRequested(prefs);
    if (!mounted) return;
    setState(() {
      _blank = false;
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) => _blank
      ? const Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(color: Color(0xFF111111)),
        )
      : KeyedSubtree(key: _key, child: widget.child);
}
