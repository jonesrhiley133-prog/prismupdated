import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/fronting_roles/roles_data.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

const _intervals = <int>[30, 60, 120, 180, 300, 480, 720, 1440];

String intervalLabel(BuildContext c, int m) => m < 60
    ? tr(c, '$m min', '$m min')
    : (m % 60 == 0
          ? tr(c, '${m ~/ 60} h', '${m ~/ 60} h')
          : tr(c, '${m ~/ 60} h ${m % 60} min', '${m ~/ 60} h ${m % 60} min'));

/// Settings › Fronting statuses & Who's There.
class FrontStatusesScreen extends ConsumerWidget {
  const FrontStatusesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(roleSettingsProvider);
    final types = ref.watch(frontStatusTypesProvider);
    final roles = ref.watch(currentRolesProvider);
    final members =
        ref.watch(userVisibleMembersProvider).value ?? const <Member>[];
    final prefer = ref.watch(memberNamePreferDisplayProvider);
    final actions = ref.read(rolesActionsProvider);
    final byId = {for (final m in members) m.id: m};

    return PrismPageScaffold(
      topBar: PrismTopBar(
        title: tr(context, 'Fronting statuses', 'Estados de frente'),
      ),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            PrismSectionHeader(
              title: tr(context, "WHO'S THERE?", '¿QUIÉN ESTÁ?'),
            ),
            PrismSurface(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: PrismSwitchRow(
                title: tr(
                  context,
                  'Ask who\'s fronting',
                  'Preguntar quién está al frente',
                ),
                subtitle: tr(
                  context,
                  'Shown when you open Prism or return to Home after a while, never in the middle of something.',
                  'Aparece al abrir Prism o volver al inicio tras un rato, nunca en mitad de algo.',
                ),
                value: settings.whosThereEnabled,
                onChanged: (v) => actions.saveSettings(
                  settings.copyWith(whosThereEnabled: v),
                ),
              ),
            ),
            if (settings.whosThereEnabled) ...[
              const SizedBox(height: 10),
              Text(
                tr(
                  context,
                  'Ask after no fronting change for',
                  'Preguntar tras sin cambios durante',
                ),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in _intervals)
                    PrismChip(
                      label: intervalLabel(context, m),
                      selected: settings.intervalMinutes == m,
                      onTap: () => actions.saveSettings(
                        settings.copyWith(intervalMinutes: m),
                      ),
                    ),
                  PrismChip(
                    label: _intervals.contains(settings.intervalMinutes)
                        ? tr(context, 'Custom…', 'Personalizado…')
                        : intervalLabel(context, settings.intervalMinutes),
                    selected: !_intervals.contains(settings.intervalMinutes),
                    onTap: () async {
                      final ctl = TextEditingController(
                        text: '${settings.intervalMinutes}',
                      );
                      final v = await PrismSheet.show<int>(
                        context: context,
                        title: tr(
                          context,
                          'Custom interval (minutes)',
                          'Intervalo (minutos)',
                        ),
                        builder: (ctx) => SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PrismTextField(
                                controller: ctl,
                                keyboardType: TextInputType.number,
                                autofocus: true,
                              ),
                              const SizedBox(height: 10),
                              PrismButton(
                                tone: PrismButtonTone.filled,
                                label: tr(ctx, 'Save', 'Guardar'),
                                onPressed: () => Navigator.of(
                                  ctx,
                                ).pop(int.tryParse(ctl.text.trim())),
                              ),
                            ],
                          ),
                        ),
                      );
                      ctl.dispose();
                      if (v != null && v >= 5)
                        await actions.saveSettings(
                          settings.copyWith(intervalMinutes: v),
                        );
                    },
                  ),
                ],
              ),
            ],
            PrismSectionHeader(title: tr(context, 'RIGHT NOW', 'AHORA MISMO')),
            if (roles.isEmpty)
              Text(
                tr(
                  context,
                  'Nobody has a status right now.',
                  'Nadie tiene un estado ahora mismo.',
                ),
                style: theme.textTheme.bodySmall,
              )
            else
              PrismSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final r in roles)
                      if (byId[r.memberId] != null)
                        PrismListRow(
                          leading: MemberAvatar(
                            avatarImageData: byId[r.memberId]!.avatarImageData,
                            memberName: byId[r.memberId]!.name,
                            emoji: byId[r.memberId]!.emoji,
                            customColorEnabled:
                                byId[r.memberId]!.customColorEnabled,
                            customColorHex: byId[r.memberId]!.customColorHex,
                            size: 32,
                          ),
                          title: Text(
                            byId[r.memberId]!.effectiveName(
                              preferDisplayName: prefer,
                            ),
                          ),
                          subtitle: Text(
                            '${statusById(types, r.statusId)?.emoji ?? ''} ${statusById(types, r.statusId)?.name ?? r.statusId}',
                          ),
                          trailing: Icon(PhosphorIcons.caretRight()),
                          onTap: () =>
                              pickStatusFor(context, ref, byId[r.memberId]!),
                        ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            PrismButton(
              icon: PhosphorIcons.userPlus(),
              label: tr(context, 'Give an alter a status', 'Asignar un estado'),
              onPressed: () async {
                final m = await _pickMember(context, members, prefer);
                if (m != null && context.mounted)
                  await pickStatusFor(context, ref, m);
              },
            ),
            PrismSectionHeader(title: tr(context, 'STATUSES', 'ESTADOS')),
            PrismSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final t in types)
                    PrismListRow(
                      leading: Text(
                        t.emoji.isEmpty ? '•' : t.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(t.name),
                      subtitle: Text(
                        [
                          if (t.description.isNotEmpty) t.description,
                          t.activeFronting
                              ? tr(
                                  context,
                                  'Counts as fronting',
                                  'Cuenta como frente',
                                )
                              : tr(
                                  context,
                                  'Awareness (not fronting)',
                                  'Conciencia (no al frente)',
                                ),
                          if (t.maxAlters != null)
                            tr(
                              context,
                              'Up to ${t.maxAlters}',
                              'Hasta ${t.maxAlters}',
                            ),
                          if (t.builtIn) tr(context, 'Built in', 'Incluido'),
                        ].join(' · '),
                      ),
                      onTap: t.builtIn
                          ? null
                          : () => editStatusType(context, ref, t),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            PrismButton(
              tone: PrismButtonTone.filled,
              icon: PhosphorIcons.plus(),
              label: tr(context, 'Add a status', 'Añadir un estado'),
              onPressed: () => editStatusType(context, ref, null),
            ),
            PrismSurface(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: PrismSwitchRow(
                title: tr(
                  context,
                  'Allow more than one status per alter',
                  'Permitir más de un estado por alter',
                ),
                subtitle: tr(
                  context,
                  'e.g. Co-front and Blended at the same time.',
                  'p. ej. Co-frente y Fusionado a la vez.',
                ),
                value: settings.allowMultipleStatuses,
                onChanged: (v) => actions.saveSettings(
                  settings.copyWith(allowMultipleStatuses: v),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<Member?> _pickMember(
  BuildContext context,
  List<Member> members,
  bool prefer,
) => PrismSheet.show<Member>(
  context: context,
  title: tr(context, 'Choose an alter', 'Elige un alter'),
  maxHeightFactor: 0.85,
  builder: (ctx) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    children: [
      for (final m in members.where((m) => !m.isDeleted))
        PrismListRow(
          dense: true,
          leading: MemberAvatar(
            avatarImageData: m.avatarImageData,
            memberName: m.name,
            emoji: m.emoji,
            customColorEnabled: m.customColorEnabled,
            customColorHex: m.customColorHex,
            size: 30,
          ),
          title: Text(m.effectiveName(preferDisplayName: prefer)),
          onTap: () => Navigator.of(ctx).pop(m),
        ),
    ],
  ),
);

/// Choose a status for [m] (or clear it).
Future<void> pickStatusFor(
  BuildContext context,
  WidgetRef ref,
  Member m,
) async {
  final types = ref
      .read(frontStatusTypesProvider)
      .where((t) => t.visible)
      .toList();
  final roles = ref.read(currentRolesProvider);
  final v = await PrismSheet.show<String>(
    context: context,
    title: m.name,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in types)
            PrismListRow(
              dense: true,
              leading: Text(
                t.emoji.isEmpty ? '•' : t.emoji,
                style: const TextStyle(fontSize: 20),
              ),
              title: Text(t.name),
              subtitle:
                  t.maxAlters != null &&
                      roles
                              .where(
                                (r) => r.statusId == t.id && r.memberId != m.id,
                              )
                              .length >=
                          t.maxAlters!
                  ? Text(
                      tr(
                        ctx,
                        'Full — choosing this moves the current holder to Co-front',
                        'Lleno: el actual pasará a Co-frente',
                      ),
                    )
                  : null,
              trailing:
                  roles.any((r) => r.memberId == m.id && r.statusId == t.id)
                  ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill))
                  : null,
              onTap: () => Navigator.of(ctx).pop(t.id),
            ),
          PrismListRow(
            dense: true,
            leading: Icon(PhosphorIcons.x()),
            title: Text(tr(ctx, 'No status', 'Sin estado')),
            onTap: () => Navigator.of(ctx).pop(kNoStatus),
          ),
        ],
      ),
    ),
  );
  if (v == null) return;
  final actions = ref.read(rolesActionsProvider);
  final type = statusById(ref.read(frontStatusTypesProvider), v);
  // Respect the limit: bump the longest-standing holder to Co-front.
  if (type?.maxAlters != null) {
    final holders =
        roles.where((r) => r.statusId == v && r.memberId != m.id).toList()
          ..sort(
            (a, b) =>
                (a.since ?? DateTime(0)).compareTo(b.since ?? DateTime(0)),
          );
    while (holders.length >= type!.maxAlters!) {
      await actions.setStatus(holders.removeAt(0).memberId, kCoFront);
    }
  }
  await actions.setStatus(m.id, v);
}

/// Create or edit a custom status.
Future<void> editStatusType(
  BuildContext context,
  WidgetRef ref,
  FrontStatusType? existing,
) => PrismSheet.show<void>(
  context: context,
  title: existing == null
      ? tr(context, 'New status', 'Nuevo estado')
      : tr(context, 'Edit status', 'Editar estado'),
  maxHeightFactor: 0.92,
  builder: (_) => _StatusEditor(existing: existing),
);

class _StatusEditor extends ConsumerStatefulWidget {
  const _StatusEditor({this.existing});
  final FrontStatusType? existing;
  @override
  ConsumerState<_StatusEditor> createState() => _StatusEditorState();
}

class _StatusEditorState extends ConsumerState<_StatusEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _desc = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _emoji = TextEditingController(text: widget.existing?.emoji ?? '');
  late final _max = TextEditingController(
    text: widget.existing?.maxAlters?.toString() ?? '',
  );
  late int? _color = widget.existing?.color;
  late bool _active = widget.existing?.activeFronting ?? false;
  late bool _visible = widget.existing?.visible ?? true;
  late bool _analytics = widget.existing?.inAnalytics ?? true;
  late bool _dashboard = widget.existing?.onDashboard ?? true;
  late bool _notify = widget.existing?.inNotification ?? true;
  static const _palette = [
    0xFFE76F51,
    0xFFF4A261,
    0xFFE9C46A,
    0xFF8AB17D,
    0xFF2A9D8F,
    0xFF5B8DEF,
    0xFF9B72CF,
    0xFFE5989B,
    0xFF8D6E63,
  ];

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _emoji.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(frontStatusTypesProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.existing == null) ...[
            Text(
              tr(context, 'Ideas (optional)', 'Ideas (opcional)'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (n, e, active) in statusSuggestions)
                  if (!types.any((t) => t.name == n))
                    PrismChip(
                      label: '$e $n',
                      selected: false,
                      onTap: () => setState(() {
                        _name.text = n;
                        _emoji.text = e;
                        _active = active;
                      }),
                    ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              SizedBox(
                width: 72,
                child: PrismTextField(
                  controller: _emoji,
                  labelText: tr(context, 'Emoji', 'Emoji'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrismTextField(
                  controller: _name,
                  labelText: tr(context, 'Name', 'Nombre'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PrismTextField(
            controller: _desc,
            labelText: tr(
              context,
              'Description (optional)',
              'Descripción (opcional)',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          PrismTextField(
            controller: _max,
            labelText: tr(
              context,
              'Most alters at once (optional)',
              'Máximo de alters a la vez (opcional)',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (final c in _palette)
                GestureDetector(
                  onTap: () => setState(() => _color = _color == c ? null : c),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: prismRound(context),
                      border: Border.all(
                        width: _color == c ? 3 : 1,
                        color: _color == c
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          PrismSwitchRow(
            title: tr(context, 'Counts as fronting', 'Cuenta como frente'),
            subtitle: tr(
              context,
              'Needs a fronting session; off for awareness statuses like Nearby.',
              'Requiere una sesión; desactívalo para estados como Cerca.',
            ),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          PrismSwitchRow(
            title: tr(context, 'Show in pickers', 'Mostrar en selectores'),
            value: _visible,
            onChanged: (v) => setState(() => _visible = v),
          ),
          PrismSwitchRow(
            title: tr(context, 'Show on Home', 'Mostrar en Inicio'),
            value: _dashboard,
            onChanged: (v) => setState(() => _dashboard = v),
          ),
          PrismSwitchRow(
            title: tr(
              context,
              'Show in the fronting notification',
              'Mostrar en la notificación',
            ),
            value: _notify,
            onChanged: (v) => setState(() => _notify = v),
          ),
          PrismSwitchRow(
            title: tr(
              context,
              'Include in statistics',
              'Incluir en estadísticas',
            ),
            value: _analytics,
            onChanged: (v) => setState(() => _analytics = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (widget.existing != null) ...[
                Expanded(
                  child: PrismButton(
                    label: tr(context, 'Delete', 'Eliminar'),
                    onPressed: () async {
                      await ref
                          .read(rolesActionsProvider)
                          .deleteStatusType(widget.existing!);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: PrismButton(
                  tone: PrismButtonTone.filled,
                  label: tr(context, 'Save', 'Guardar'),
                  onPressed: () async {
                    if (_name.text.trim().isEmpty) return;
                    await ref
                        .read(rolesActionsProvider)
                        .saveStatusType(
                          FrontStatusType(
                            id: widget.existing?.id ?? '',
                            name: _name.text.trim(),
                            description: _desc.text.trim(),
                            emoji: _emoji.text.trim(),
                            color: _color,
                            order:
                                widget.existing?.order ?? (10 + types.length),
                            visible: _visible,
                            maxAlters: int.tryParse(_max.text.trim()),
                            activeFronting: _active,
                            inAnalytics: _analytics,
                            onDashboard: _dashboard,
                            inNotification: _notify,
                            record: widget.existing?.record,
                          ),
                        );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
