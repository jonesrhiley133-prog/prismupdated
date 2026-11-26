import 'package:intl/intl.dart';

import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/features/alter_status/status_models.dart';
import 'package:prism_plurality/features/alter_status/status_providers.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/icon_choices.dart';
import 'package:prism_plurality/shared/pickers/style_pickers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/widgets/member_avatar.dart';

String _lang(BuildContext c) => Localizations.localeOf(c).languageCode;

/// Small status dot with the status icon.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.status, this.size = 16});
  final AlterStatus status;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: status.title,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(status.color),
        borderRadius: prismRound(context),
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
      child: Icon(status.icon, size: size * 0.55, color: Colors.white),
    ),
  );
}

/// "● Busy — studying · until 5:00 PM" line.
class StatusLine extends StatelessWidget {
  const StatusLine({super.key, required this.status, this.compact = false});
  final AlterStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final until = status.expiresAt == null
        ? null
        : tr(context, 'until ', 'hasta ') +
              DateFormat.MMMd(
                context.dateLocale,
              ).add_jm().format(status.expiresAt!);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(status.icon, size: 14, color: Color(status.color)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            [
              status.title,
              if (status.message != null) status.message!,
              if (!compact && status.activity != null) '🎯 ${status.activity}',
              if (!compact && until != null) until,
            ].join(' · '),
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Status block for an alter profile: shows the status and lets you change it.
class MemberStatusPanel extends ConsumerWidget {
  const MemberStatusPanel({super.key, required this.memberId});
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(alterStatusesProvider(_lang(context)))[memberId];
    return PrismSurface(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: () => showStatusEditor(context, memberId),
      child: Row(
        children: [
          if (s != null)
            StatusDot(status: s, size: 22)
          else
            Icon(PhosphorIcons.circleDashed(), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: s == null
                ? Text(tr(context, 'Set a status', 'Poner un estado'))
                : StatusLine(status: s),
          ),
          Icon(AppIcons.chevronRight, size: 18),
        ],
      ),
    );
  }
}

Future<void> showStatusEditor(BuildContext context, String memberId) =>
    PrismSheet.showFullScreen(
      context: context,
      builder: (ctx, scroll) =>
          _StatusEditor(memberId: memberId, scroll: scroll),
    );

class _StatusEditor extends ConsumerStatefulWidget {
  const _StatusEditor({required this.memberId, required this.scroll});
  final String memberId;
  final ScrollController scroll;

  @override
  ConsumerState<_StatusEditor> createState() => _StatusEditorState();
}

class _StatusEditorState extends ConsumerState<_StatusEditor> {
  StatusType? _type;
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _activity = TextEditingController();
  int? _color;
  String? _icon;
  Duration? _expiry;
  DateTime? _customUntil;
  bool _private = false;
  bool _init = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _activity.dispose();
    super.dispose();
  }

  void _pick(StatusType t) => setState(() {
    _type = t;
    _title.text = t.title;
    _color = t.color;
    _icon = t.iconKey;
  });

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(statusTypesProvider(_lang(context)));
    final current = ref.watch(
      alterStatusesProvider(_lang(context)),
    )[widget.memberId];
    if (!_init) {
      _init = true;
      if (current != null) {
        _type = types.where((t) => t.key == current.typeKey).firstOrNull;
        _title.text = current.title;
        _message.text = current.message ?? '';
        _activity.text = current.activity ?? '';
        _color = current.color;
        _icon = current.iconKey;
        _private = current.isPrivate;
        _customUntil = current.expiresAt;
      }
    }
    final expiries = <(String, Duration?)>[
      (tr(context, 'Never', 'Nunca'), null),
      (tr(context, '30 min', '30 min'), const Duration(minutes: 30)),
      (tr(context, '1 hour', '1 hora'), const Duration(hours: 1)),
      (tr(context, '4 hours', '4 horas'), const Duration(hours: 4)),
      (tr(context, 'Today', 'Hoy'), const Duration(days: -1)),
      (tr(context, '1 week', '1 semana'), const Duration(days: 7)),
    ];
    final theme = Theme.of(context);
    return TrackerEditorScaffold(
      title: tr(context, 'Status', 'Estado'),
      canSave: _type != null,
      scrollController: widget.scroll,
      onSave: _save,
      children: [
        TrackerLabel(tr(context, 'Choose a status', 'Elige un estado')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in types)
              PrismChip(
                avatar: Icon(
                  iconForKey(t.iconKey),
                  size: 16,
                  color: Color(t.color),
                ),
                label: t.title,
                selected: _type?.key == t.key,
                selectedColor: Color(t.color),
                onTap: () => _pick(t),
              ),
            PrismChip(
              label: tr(context, '+ Custom status', '+ Estado personalizado'),
              selected: false,
              variant: PrismChipVariant.inline,
              onTap: () => showCustomStatusEditor(context),
            ),
          ],
        ),
        if (_type != null) ...[
          const SizedBox(height: 16),
          PrismTextField(
            controller: _title,
            labelText: tr(context, 'Status title', 'Título del estado'),
          ),
          const SizedBox(height: 10),
          PrismTextField(
            controller: _message,
            labelText: tr(context, 'Message (optional)', 'Mensaje (opcional)'),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 10),
          PrismTextField(
            controller: _activity,
            labelText: tr(
              context,
              'Activity or current interest (optional)',
              'Actividad o interés actual (opcional)',
            ),
            prefixIcon: Icon(PhosphorIcons.target()),
          ),
          const SizedBox(height: 14),
          TrackerLabel(tr(context, 'Colour', 'Color')),
          ColorChoiceRow(
            value: _color,
            onChanged: (c) => setState(() => _color = c),
          ),
          const SizedBox(height: 14),
          TrackerLabel(tr(context, 'Icon', 'Icono')),
          IconChoiceGrid(
            value: _icon,
            color: _color == null ? null : Color(_color!),
            onChanged: (k) => setState(() => _icon = k),
          ),
          const SizedBox(height: 14),
          TrackerLabel(tr(context, 'Clear after', 'Borrar después de')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (label, d) in expiries)
                PrismChip(
                  label: label,
                  selected: _customUntil == null && _expiry == d,
                  onTap: () => setState(() {
                    _expiry = d;
                    _customUntil = null;
                  }),
                ),
              PrismChip(
                label: _customUntil == null
                    ? tr(context, 'Pick time…', 'Elegir hora…')
                    : DateFormat.MMMd(
                        context.dateLocale,
                      ).add_jm().format(_customUntil!),
                selected: _customUntil != null,
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showPrismDatePicker(
                    context: context,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                    initialDate: now,
                  );
                  if (d == null || !context.mounted) return;
                  final t = await showPrismTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(
                      now.add(const Duration(hours: 1)),
                    ),
                  );
                  if (t == null) return;
                  setState(
                    () => _customUntil = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      t.hour,
                      t.minute,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          PrismSwitchRow(
            title: tr(context, 'Keep private', 'Mantener privado'),
            subtitle: tr(
              context,
              'Only shown on this alter’s profile, not on Home or lists.',
              'Solo se muestra en el perfil de este alter, no en Inicio ni listas.',
            ),
            value: _private,
            onChanged: (v) => setState(() => _private = v),
          ),
          if (current != null) ...[
            const SizedBox(height: 8),
            PrismButton(
              label: tr(context, 'Clear status', 'Borrar estado'),
              icon: AppIcons.close,
              onPressed: () async {
                await ref.read(statusActionsProvider).clear(widget.memberId);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              'Previous statuses are kept in the status history.',
              'Los estados anteriores se guardan en el historial.',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<void> _save() async {
    final t = _type;
    if (t == null) return;
    DateTime? until = _customUntil;
    if (until == null && _expiry != null) {
      final now = DateTime.now();
      until = _expiry!.isNegative
          ? DateTime(now.year, now.month, now.day, 23, 59)
          : now.add(_expiry!);
    }
    await ref
        .read(statusActionsProvider)
        .set(
          memberId: widget.memberId,
          type: t,
          title: _title.text,
          message: _message.text.trim().isEmpty ? null : _message.text.trim(),
          activity: _activity.text,
          color: _color,
          iconKey: _icon,
          expiresAt: until,
          isPrivate: _private,
        );
    if (mounted) Navigator.of(context).pop();
  }
}

IconData iconForKey(String k) => iconFor(k);

Future<void> showCustomStatusEditor(
  BuildContext context, {
  TrackerRecord? editing,
}) => PrismSheet.showFullScreen(
  context: context,
  builder: (ctx, scroll) =>
      _CustomStatusEditor(editing: editing, scroll: scroll),
);

class _CustomStatusEditor extends ConsumerStatefulWidget {
  const _CustomStatusEditor({this.editing, required this.scroll});
  final TrackerRecord? editing;
  final ScrollController scroll;

  @override
  ConsumerState<_CustomStatusEditor> createState() =>
      _CustomStatusEditorState();
}

class _CustomStatusEditorState extends ConsumerState<_CustomStatusEditor> {
  late final _name = TextEditingController(text: widget.editing?.title);
  late final _desc = TextEditingController(text: widget.editing?.body);
  late String _icon = widget.editing?.str('icon') ?? 'star';
  late int _color = widget.editing?.integer('color') ?? 0xFF8E7CC3;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TrackerEditorScaffold(
      title: widget.editing == null
          ? tr(context, 'New custom status', 'Nuevo estado personalizado')
          : tr(context, 'Edit status', 'Editar estado'),
      canSave: _name.text.trim().isNotEmpty,
      scrollController: widget.scroll,
      onSave: () async {
        await ref
            .read(statusActionsProvider)
            .saveCustom(
              editing: widget.editing,
              name: _name.text.trim(),
              icon: _icon,
              color: _color,
              description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            );
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        Center(
          child: PrismCircleAvatar(
            radius: 32,
            backgroundColor: Color(_color),
            child: Icon(iconForKey(_icon), color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _name,
          labelText: tr(context, 'Name', 'Nombre'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        PrismTextField(
          controller: _desc,
          labelText: tr(context, 'Description', 'Descripción'),
          maxLines: 3,
          minLines: 1,
        ),
        const SizedBox(height: 14),
        TrackerLabel(tr(context, 'Colour', 'Color')),
        ColorChoiceRow(
          value: _color,
          onChanged: (c) => setState(() => _color = c),
        ),
        const SizedBox(height: 14),
        TrackerLabel(tr(context, 'Icon', 'Icono')),
        IconChoiceGrid(
          value: _icon,
          color: Color(_color),
          onChanged: (k) => setState(() => _icon = k),
        ),
        if (widget.editing != null) ...[
          const SizedBox(height: 16),
          PrismButton(
            label: tr(context, 'Delete status', 'Eliminar estado'),
            tone: PrismButtonTone.destructive,
            icon: AppIcons.delete,
            onPressed: () async {
              final ok = await PrismDialog.confirm(
                context: context,
                title: tr(
                  context,
                  'Delete this custom status?',
                  '¿Eliminar este estado personalizado?',
                ),
                message: tr(
                  context,
                  'Alters currently using it keep their status text.',
                  'Los alters que lo usan conservan su texto.',
                ),
                destructive: true,
                confirmLabel: tr(context, 'Delete', 'Eliminar'),
                cancelLabel: context.l10n.cancel,
              );
              if (!ok) return;
              await ref
                  .read(trackerNotifierProvider.notifier)
                  .delete(widget.editing!.id, children: false);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}

/// Home dashboard card: everyone with a shared status, tap to change.
class StatusesDashboardCard extends ConsumerWidget {
  const StatusesDashboardCard({super.key, this.onOpenAll});
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(publicStatusesProvider(_lang(context)));
    final members = {
      for (final m
          in ref.watch(activeMembersProvider).value ?? const <Member>[])
        m.id: m,
    };
    final preferDisplay = ref.watch(memberNamePreferDisplayProvider);
    final shown = [
      for (final e in statuses.entries)
        if (members.containsKey(e.key)) e,
    ];
    final theme = Theme.of(context);
    return PrismSurface(
      onTap: onOpenAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIcons.chatCircleDots(),
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(context, 'Statuses', 'Estados'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Icon(AppIcons.chevronRight, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            Text(
              tr(
                context,
                'No one has a status right now. Tap to set one.',
                'Nadie tiene estado ahora. Toca para poner uno.',
              ),
              style: theme.textTheme.bodySmall,
            )
          else
            for (final e in shown.take(6))
              InkWell(
                onTap: () => showStatusEditor(context, e.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          MemberAvatar(
                            avatarImageData: members[e.key]!.avatarImageData,
                            memberName: members[e.key]!.effectiveName(
                              preferDisplayName: preferDisplay,
                            ),
                            emoji: members[e.key]!.emoji,
                            customColorEnabled:
                                members[e.key]!.customColorEnabled,
                            customColorHex: members[e.key]!.customColorHex,
                            size: 32,
                          ),
                          Positioned(
                            right: -3,
                            bottom: -3,
                            child: StatusDot(status: e.value, size: 14),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              members[e.key]!.effectiveName(
                                preferDisplayName: preferDisplay,
                              ),
                              style: theme.textTheme.bodyMedium,
                            ),
                            StatusLine(status: e.value, compact: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
