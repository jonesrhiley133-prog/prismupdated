import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/core/app_icon/app_icon.dart';
import 'package:prism_plurality/core/app_icon/icon_catalog.dart';
import 'package:prism_plurality/features/seasonal/seasonal_models.dart';
import 'package:prism_plurality/features/seasonal/seasonal_providers.dart';

/// Switches to a seasonal icon while a holiday is showing, and back again
/// after, but only when the person turned this on in the icon gallery.
/// Seasonal decorations never touch the icon otherwise.
class SeasonalIconScheduler extends ConsumerStatefulWidget {
  const SeasonalIconScheduler({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<SeasonalIconScheduler> createState() =>
      _SeasonalIconSchedulerState();
}

class _SeasonalIconSchedulerState extends ConsumerState<SeasonalIconScheduler> {
  String? _applied;

  /// The seasonal design for [v], if it belongs to a holiday or season.
  static IconDesign? designFor(SeasonalVariation? v) {
    if (v == null) return null;
    final list = seasonalIconDesigns(v.collectionId);
    return list.isEmpty ? null : list[v.index % list.length];
  }

  Future<void> _sync(SeasonalVariation? v) async {
    if (!appIconSupported) return;
    final svc = ref.read(appIconServiceProvider);
    if (!await svc.autoSeasonal()) return;
    final d = designFor(v);
    if (d?.id == _applied) return;
    if (d != null) {
      if (await svc.setDesign(d, ask: false)) _applied = d.id;
      return;
    }
    // The holiday is over: put the usual icon back.
    final current = ref.read(appIconProvider).value ?? 'classic';
    final preset = appIconPresetById(current);
    if (kIsWeb && preset != null) {
      await svc.set(current);
    } else if (preset?.art != null) {
      await svc.setDesign(
        IconDesign(preset!.id, preset.en, preset.es, preset.group, preset.art!),
        ask: false,
      );
    }
    _applied = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(ref.read(activeSeasonProvider)?.variation);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      activeSeasonProvider.select((a) => a?.variation?.id),
      (_, _) => _sync(ref.read(activeSeasonProvider)?.variation),
    );
    return widget.child;
  }
}
