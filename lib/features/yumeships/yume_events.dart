import 'package:prism_plurality/features/yumeships/yume_data.dart';
import 'package:prism_plurality/features/yumeships/yume_widgets.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Add or edit an anniversary / birthday / celebration for a yumeship.
/// You decide whether it shows on Prism's calendar and whether it notifies.
Future<void> showYumeEventEditor(
  BuildContext context, {
  required String shipId,
  YumeEvent? existing,
  String type = 'anniversary',
  String? title,
  DateTime? date,
}) => PrismSheet.showFullScreen<void>(
  context: context,
  builder: (ctx, scroll) => _EventEditor(
    shipId: shipId,
    existing: existing,
    scroll: scroll,
    type: type,
    title: title,
    date: date,
  ),
);

class _EventEditor extends ConsumerStatefulWidget {
  const _EventEditor({
    required this.shipId,
    required this.scroll,
    this.existing,
    required this.type,
    this.title,
    this.date,
  });
  final String shipId;
  final YumeEvent? existing;
  final ScrollController scroll;
  final String type;
  final String? title;
  final DateTime? date;
  @override
  ConsumerState<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<_EventEditor> {
  late final x = widget.existing;
  late final _title = TextEditingController(text: x?.r.title ?? widget.title);
  late final _note = TextEditingController(text: x?.note);
  late String _type = x?.type ?? widget.type;
  late DateTime _date = x?.date ?? widget.date ?? DateTime.now();
  late String _repeat =
      x?.recurrence ??
      (const {'anniversary', 'birthday', 'appreciation'}.contains(widget.type)
          ? 'yearly'
          : 'none');
  late bool _onCalendar =
      x?.onCalendar ?? ref.read(yumeSettingsProvider).calendarDefault;
  late bool _notify = x?.notify ?? ref.read(yumeSettingsProvider).notifyDefault;
  late String _lead = x?.lead ?? 'day';
  late bool _countdown = x?.countdown ?? false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ship = ref.watch(yumeShipByIdProvider(widget.shipId));
    final theme = Theme.of(context);
    return TrackerEditorScaffold(
      title: x == null
          ? tr(context, 'New date', 'Nueva fecha')
          : tr(context, 'Edit date', 'Editar fecha'),
      canSave: !_busy,
      scrollController: widget.scroll,
      onSave: () async {
        setState(() => _busy = true);
        await ref
            .read(yumeActionsProvider)
            .saveEvent(
              existing: x,
              shipId: widget.shipId,
              type: _type,
              title: _title.text.trim().isEmpty
                  ? (yumeEventTypes[_type]?.$1 ?? '')
                  : _title.text,
              date: _date,
              note: _note.text,
              repeat: _repeat,
              onCalendar: _onCalendar,
              notify: _onCalendar && _notify,
              lead: _lead,
              countdown: _countdown,
            );
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        TrackerLabel(tr(context, 'Kind of date', 'Tipo de fecha')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in yumeEventTypes.entries)
              PrismChip(
                label: '${t.value.$3} ${tr(context, t.value.$1, t.value.$2)}',
                selected: _type == t.key,
                onTap: () => setState(() => _type = t.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PrismTextField(
          controller: _title,
          labelText: tr(context, 'Title', 'Título'),
          hintText: yumeEventTypes[_type]?.$1,
        ),
        const SizedBox(height: 10),
        PrismListRow(
          padding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(yumeDate(_date)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final d = await showPrismDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(1),
              lastDate: DateTime(2200),
            );
            if (d != null) setState(() => _date = d);
          },
        ),
        PrismSelect<String>(
          labelText: tr(context, 'Repeats', 'Se repite'),
          value: _repeat,
          items: [
            for (final r in yumeRecurrences.entries)
              PrismSelectItem(value: r.key, label: r.value),
          ],
          onChanged: (v) => setState(() => _repeat = v ?? 'none'),
        ),
        const SizedBox(height: 10),
        PrismTextField(
          controller: _note,
          labelText: tr(context, 'Notes', 'Notas'),
          minLines: 2,
          maxLines: 6,
        ),
        const SizedBox(height: 12),
        PrismSwitchRow(
          padding: EdgeInsets.zero,
          title: tr(context, 'Show on my calendar', 'Mostrar en mi calendario'),
          subtitle: tr(
            context,
            'Adds it to Prism’s Calendar (category “Yumeship”).',
            'Lo añade al Calendario de Prism (categoría “Yumeship”).',
          ),
          value: _onCalendar,
          onChanged: (v) => setState(() => _onCalendar = v),
        ),
        if (_onCalendar) ...[
          PrismSwitchRow(
            padding: EdgeInsets.zero,
            title: tr(
              context,
              'Send a notification',
              'Enviar una notificación',
            ),
            subtitle: ship != null && !ship.notify
                ? tr(
                    context,
                    'Notifications are off for this whole yumeship.',
                    'Las notificaciones están apagadas para este yumeship.',
                  )
                : null,
            value: _notify,
            onChanged: (v) => setState(() => _notify = v),
          ),
          if (_notify)
            PrismSelect<String>(
              labelText: tr(context, 'When', 'Cuándo'),
              value: _lead,
              items: [
                for (final l in yumeAlertLeads.entries)
                  PrismSelectItem(value: l.key, label: l.value.$1),
              ],
              onChanged: (v) => setState(() => _lead = v ?? 'day'),
            ),
        ],
        PrismSwitchRow(
          padding: EdgeInsets.zero,
          title: tr(
            context,
            'Countdown on the dashboard',
            'Cuenta atrás en el panel',
          ),
          value: _countdown,
          onChanged: (v) => setState(() => _countdown = v),
        ),
        if (x != null) ...[
          const SizedBox(height: 16),
          PrismButton(
            label: tr(context, 'Delete this date', 'Eliminar esta fecha'),
            icon: Icons.delete_outline,
            onPressed: () async {
              final ok = await PrismDialog.confirm(
                context: context,
                title: tr(
                  context,
                  'Delete this date?',
                  '¿Eliminar esta fecha?',
                ),
                message: tr(
                  context,
                  'It’s removed from your calendar too.',
                  'También se quita de tu calendario.',
                ),
                destructive: true,
                confirmLabel: tr(context, 'Delete', 'Eliminar'),
              );
              if (!ok) return;
              await ref.read(yumeActionsProvider).deleteEvent(x!);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
        const SizedBox(height: 8),
        Text(
          tr(
            context,
            'Notifications follow your calendar settings and quiet hours.',
            'Las notificaciones siguen los ajustes del calendario y las horas de silencio.',
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
