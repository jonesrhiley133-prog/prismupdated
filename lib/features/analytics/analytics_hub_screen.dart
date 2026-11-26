import 'package:go_router/go_router.dart';

import 'package:prism_plurality/core/router/app_routes.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Entry point for the deeper analytics pages.
class AnalyticsHubScreen extends StatelessWidget {
  const AnalyticsHubScreen({super.key, this.showBackButton = false});
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        PhosphorIcons.usersThree(),
        tr(context, 'Co-fronting', 'Co-frente'),
        tr(
          context,
          'Who fronts together, how often and for how long — with rankings, calendar and timeline.',
          'Quién está al frente junto, con qué frecuencia y cuánto tiempo.',
        ),
        '/analytics/cofronting',
        const Color(0xFF8E7CC3),
      ),
      (
        PhosphorIcons.chartScatter(),
        tr(context, 'Mood correlations', 'Correlaciones de ánimo'),
        tr(
          context,
          'Compare mood with fronting, sleep, food, activity, places and more.',
          'Compara el ánimo con el frente, el sueño, la comida, la actividad, lugares y más.',
        ),
        '/analytics/mood',
        const Color(0xFFE6A23C),
      ),
      (
        PhosphorIcons.graph(),
        tr(context, 'Connections explorer', 'Explorador de conexiones'),
        tr(
          context,
          'See how your records link together.',
          'Mira cómo se enlazan tus registros.',
        ),
        '/links',
        const Color(0xFF4FA3A5),
      ),
      (
        PhosphorIcons.chartLine(),
        tr(context, 'Fronting statistics', 'Estadísticas de frente'),
        tr(
          context,
          'The classic fronting charts.',
          'Los gráficos clásicos de frente.',
        ),
        AppRoutePaths.statistics,
        const Color(0xFF6C8EBF),
      ),
      (
        PhosphorIcons.lightbulb(),
        tr(context, 'Daily insights', 'Observaciones diarias'),
        tr(
          context,
          'A short look at today and recent days.',
          'Un vistazo a hoy y los últimos días.',
        ),
        AppRoutePaths.insights,
        const Color(0xFF59A14F),
      ),
    ];
    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Analytics', 'Análisis'),
        showBackButton: showBackButton || Navigator.of(context).canPop(),
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      body: ListView(
        padding: EdgeInsets.only(top: 8, bottom: NavBarInset.of(context) + 16),
        children: [
          for (final (icon, title, sub, path, color) in items)
            PrismSurface(
              margin: const EdgeInsets.only(bottom: 10),
              onTap: () => context.push(path),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: prismCorners(context, 14),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(sub, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Icon(AppIcons.chevronRight),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
