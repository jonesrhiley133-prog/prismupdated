import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/features/app_update/app_update_service.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>(
  (ref) => AppUpdateService(),
);

enum AppUpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  needsPermission,
  installing,
  error,
}

@immutable
class AppUpdateState {
  const AppUpdateState({
    this.phase = AppUpdatePhase.idle,
    this.info,
    this.progress = 0,
    this.errorCode,
    this.lastChecked,
    this.dismissedBuild,
    this.downloadedPath,
  });

  final AppUpdatePhase phase;
  final AppUpdateInfo? info;
  final double progress;
  final String? errorCode;
  final DateTime? lastChecked;

  /// Build the user tapped "Later" on; the home banner stays hidden for it.
  final int? dismissedBuild;
  final String? downloadedPath;

  bool get busy =>
      phase == AppUpdatePhase.checking ||
      phase == AppUpdatePhase.downloading ||
      phase == AppUpdatePhase.installing;

  AppUpdateState copyWith({
    AppUpdatePhase? phase,
    AppUpdateInfo? info,
    double? progress,
    String? errorCode,
    DateTime? lastChecked,
    int? dismissedBuild,
    String? downloadedPath,
    bool clearError = false,
  }) => AppUpdateState(
    phase: phase ?? this.phase,
    info: info ?? this.info,
    progress: progress ?? this.progress,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    lastChecked: lastChecked ?? this.lastChecked,
    dismissedBuild: dismissedBuild ?? this.dismissedBuild,
    downloadedPath: downloadedPath ?? this.downloadedPath,
  );
}

class AppUpdateNotifier extends Notifier<AppUpdateState> {
  static const autoCheckInterval = Duration(hours: 6);

  AppUpdateService get _service => ref.read(appUpdateServiceProvider);

  @override
  AppUpdateState build() => const AppUpdateState();

  bool get isSupported => _service.isSupported;

  /// Checks quietly unless a check ran recently. Used by the home banner.
  Future<void> autoCheck({DateTime? now}) async {
    if (!isSupported || state.busy) return;
    final last = state.lastChecked;
    final t = now ?? DateTime.now();
    if (last != null && t.difference(last) < autoCheckInterval) return;
    await check(now: t, quiet: true);
  }

  Future<void> check({DateTime? now, bool quiet = false}) async {
    if (state.busy) return;
    state = state.copyWith(phase: AppUpdatePhase.checking, clearError: true);
    try {
      final info = await _service.checkForUpdate();
      state = AppUpdateState(
        phase: info == null
            ? AppUpdatePhase.upToDate
            : AppUpdatePhase.available,
        info: info,
        lastChecked: now ?? DateTime.now(),
        dismissedBuild: state.dismissedBuild,
      );
    } on AppUpdateException catch (e) {
      state = AppUpdateState(
        phase: quiet ? AppUpdatePhase.idle : AppUpdatePhase.error,
        errorCode: e.code,
        lastChecked: now ?? DateTime.now(),
        dismissedBuild: state.dismissedBuild,
      );
    }
  }

  void dismiss() {
    final b = state.info?.buildNumber;
    if (b != null) state = state.copyWith(dismissedBuild: b);
  }

  /// Downloads (if needed) and opens the installer.
  Future<void> downloadAndInstall() async {
    final info = state.info;
    if (info == null || state.busy) return;
    try {
      var path = state.downloadedPath;
      if (path == null) {
        state = state.copyWith(
          phase: AppUpdatePhase.downloading,
          progress: 0,
          clearError: true,
        );
        path = await _service.download(
          info,
          onProgress: (p) => state = state.copyWith(progress: p),
        );
        state = state.copyWith(downloadedPath: path);
      }
      if (!await _service.canInstall()) {
        state = state.copyWith(phase: AppUpdatePhase.needsPermission);
        return;
      }
      state = state.copyWith(phase: AppUpdatePhase.installing);
      await _service.install(path);
      // The installer is now on screen; Android replaces the app if the user
      // confirms. Return to "available" so they can retry if they cancel.
      state = state.copyWith(phase: AppUpdatePhase.available);
    } on AppUpdateException catch (e) {
      state = state.copyWith(phase: AppUpdatePhase.error, errorCode: e.code);
    } on Exception catch (e) {
      state = state.copyWith(
        phase: AppUpdatePhase.error,
        errorCode: 'install_failed',
      );
      debugPrint('App update failed: $e');
    }
  }

  Future<void> openPermissionSettings() =>
      _service.openInstallPermissionSettings();
}

final appUpdateNotifierProvider =
    NotifierProvider<AppUpdateNotifier, AppUpdateState>(AppUpdateNotifier.new);
