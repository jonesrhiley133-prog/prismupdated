import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/features/feature_state.dart';
import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/features/prism_social/social_core.dart';
import 'package:prism_plurality/features/prism_social/social_feed.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// One optional detail of a milestone the system can choose to include.
typedef MilestoneDetail = (String label, String value);

/// "Share to Social": never automatic. Shows a preview where the system picks
/// which details to include, then opens the composer (audience, caption,
/// post as system or alter).
Future<void> shareToSocial(BuildContext context, WidgetRef ref, {required String title, required String source, List<MilestoneDetail> details = const []}) async {
  if (!ref.read(featureEnabledProvider('prismSocial'))) return;
  final me = ref.read(actingProvider);
  if (me == null) {
    PrismToast.show(context, message: tr(context, 'Set up your Social profile first.', 'Primero configura tu perfil social.'), icon: AppIcons.navSocial);
    await GoRouter.of(context).push(AppRoutePaths.prismSocial);
    return;
  }
  final chosen = await PrismSheet.show<Map<String, Object?>>(context: context, title: tr(context, 'Share to Social', 'Compartir en Social'), builder: (ctx) => _Pick(title: title, source: source, details: details));
  if (chosen == null || !context.mounted) return;
  await showPostComposer(context, me, milestone: chosen);
}

class _Pick extends StatefulWidget {
  const _Pick({required this.title, required this.source, required this.details});
  final String title;
  final String source;
  final List<MilestoneDetail> details;
  @override
  State<_Pick> createState() => _PickState();
}

class _PickState extends State<_Pick> {
  late final _on = {for (var i = 0; i < widget.details.length; i++) i};

  Map<String, Object?> get _data => {
    'title': widget.title,
    'source': widget.source,
    'details': [
      for (var i = 0; i < widget.details.length; i++)
        if (_on.contains(i)) {'label': widget.details[i].$1, 'value': widget.details[i].$2},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(context, 'Only what you choose is shared. Nothing else from Prism leaves this screen.', 'Solo se comparte lo que elijas. Nada más de Prism sale de aquí.'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          for (var i = 0; i < widget.details.length; i++)
            PrismSwitchRow(
              title: widget.details[i].$1,
              subtitle: widget.details[i].$2,
              value: _on.contains(i),
              padding: const EdgeInsets.symmetric(vertical: 4),
              onChanged: (v) => setState(() => v ? _on.add(i) : _on.remove(i)),
            ),
          const SizedBox(height: 10),
          Text(tr(context, 'Preview', 'Vista previa'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          MilestoneCard(data: _data),
          const SizedBox(height: 14),
          PrismButton(label: tr(context, 'Continue', 'Continuar'), tone: PrismButtonTone.filled, icon: PhosphorIcons.arrowRight(), onPressed: () => Navigator.of(context).pop(_data)),
        ],
      ),
    );
  }
}

/// A small "Share to Social" button that hides itself when Social is off.
class ShareToSocialButton extends ConsumerWidget {
  const ShareToSocialButton({super.key, required this.title, required this.source, this.details = const []});
  final String title;
  final String source;
  final List<MilestoneDetail> details;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureEnabledProvider('prismSocial'))) return const SizedBox.shrink();
    return PrismTopBarAction(icon: PhosphorIcons.shareNetwork(), tooltip: tr(context, 'Share to Social', 'Compartir en Social'), onPressed: () => shareToSocial(context, ref, title: title, source: source, details: details));
  }
}
