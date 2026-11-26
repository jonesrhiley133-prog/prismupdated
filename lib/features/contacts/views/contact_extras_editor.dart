import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/contact.dart';
import 'package:prism_plurality/features/calendar/providers/calendar_providers.dart';
import 'package:prism_plurality/features/chat/providers/chat_providers.dart';
import 'package:prism_plurality/features/companions/companion_screens.dart'
    show memberNamesProvider;
import 'package:prism_plurality/features/contacts/contact_extras.dart';
import 'package:prism_plurality/features/experiences/color_sheet.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/tracker_kinds.dart';
import 'package:prism_plurality/shared/media/prism_media.dart';
import 'package:prism_plurality/shared/ui_kit.dart';
import 'package:prism_plurality/shared/utils/prism_image_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';

/// Opens the editor for everything on a contact's profile beyond the basics.
Future<void> showContactExtrasEditor(BuildContext context, Contact contact) =>
    PrismSheet.showFullScreen<void>(
      context: context,
      builder: (ctx, scroll) =>
          ContactExtrasEditor(contact: contact, scroll: scroll),
    );

class ContactExtrasEditor extends ConsumerStatefulWidget {
  const ContactExtrasEditor({super.key, required this.contact, this.scroll});
  final Contact contact;
  final ScrollController? scroll;

  @override
  ConsumerState<ContactExtrasEditor> createState() =>
      _ContactExtrasEditorState();
}

class _ContactExtrasEditorState extends ConsumerState<ContactExtrasEditor> {
  late ContactExtras _e = ref.read(contactExtrasProvider(widget.contact.id));
  late final _nick = TextEditingController(text: _e.nickname);
  late final _pro = TextEditingController(text: _e.pronouns);
  late final _rel = TextEditingController(text: _e.relationship);
  late final _status = TextEditingController(text: _e.status);
  late final _comm = TextEditingController(text: _e.commPrefs);
  late final _bound = TextEditingController(text: _e.boundaries);
  late final _private = TextEditingController(text: _e.privateNotes);
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_nick, _pro, _rel, _status, _comm, _bound, _private]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final out = _e.copyWith(
      nickname: _nick.text.trim(),
      pronouns: _pro.text.trim(),
      relationship: _rel.text.trim(),
      status: _status.text.trim(),
      commPrefs: _comm.text.trim(),
      boundaries: _bound.text.trim(),
      privateNotes: _private.text.trim(),
    );
    await ref.read(contactExtrasActionsProvider).save(out);
    if (mounted) Navigator.of(context).pop();
  }

  Future<String?> _pickImage(PrismCropSpec spec) =>
      PrismMedia.pickImage(ref, spec: spec);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = ref.watch(memberNamesProvider);
    final c = widget.contact;
    final accent = _e.accent == null ? null : Color(_e.accent!);

    Widget header(String t, {String? sub}) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: theme.textTheme.titleSmall),
          if (sub != null)
            Text(
              sub,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        header(tr(context, 'About', 'Acerca de')),
        PrismTextField(
          controller: _nick,
          labelText: tr(
            context,
            'Preferred name or nickname',
            'Apodo o nombre preferido',
          ),
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _pro,
          labelText: tr(context, 'Pronouns', 'Pronombres'),
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _rel,
          labelText: tr(
            context,
            'Relationship (friend, sibling, partner…)',
            'Relación (amigo, hermano, pareja…)',
          ),
        ),
        const SizedBox(height: 8),
        PrismTextField(
          controller: _status,
          labelText: tr(context, 'Custom status', 'Estado personalizado'),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PrismButton(
              icon: Icons.account_circle_outlined,
              label: _e.avatar == null
                  ? tr(context, 'Picture', 'Foto')
                  : tr(context, 'Change picture', 'Cambiar foto'),
              tone: PrismButtonTone.outlined,
              onPressed: () async {
                final id = await _pickImage(PrismCropSpec.avatar);
                if (id != null) setState(() => _e = _e.copyWith(avatar: id));
              },
            ),
            if (_e.avatar != null)
              PrismButton(
                label: tr(context, 'Remove picture', 'Quitar foto'),
                tone: PrismButtonTone.outlined,
                onPressed: () => setState(() => _e = _e.copyWith(avatar: null)),
              ),
            PrismButton(
              icon: Icons.panorama_outlined,
              label: _e.banner == null
                  ? tr(context, 'Banner', 'Banner')
                  : tr(context, 'Change banner', 'Cambiar banner'),
              tone: PrismButtonTone.outlined,
              onPressed: () async {
                final id = await _pickImage(PrismCropSpec.banner);
                if (id != null) setState(() => _e = _e.copyWith(banner: id));
              },
            ),
            if (_e.banner != null)
              PrismButton(
                label: tr(context, 'Remove banner', 'Quitar banner'),
                tone: PrismButtonTone.outlined,
                onPressed: () => setState(() => _e = _e.copyWith(banner: null)),
              ),
            PrismButton(
              icon: Icons.palette_outlined,
              label: accent == null
                  ? tr(context, 'Accent colour', 'Color de acento')
                  : tr(context, 'Change accent', 'Cambiar acento'),
              tone: PrismButtonTone.outlined,
              onPressed: () async {
                final col = await showPrismColorPicker(
                  context: context,
                  initial: accent ?? theme.colorScheme.primary,
                  title: tr(context, 'Accent colour', 'Color de acento'),
                );
                if (col != null)
                  setState(() => _e = _e.copyWith(accent: col.toARGB32()));
              },
            ),
            if (accent != null)
              PrismButton(
                label: tr(context, 'Clear accent', 'Quitar acento'),
                tone: PrismButtonTone.outlined,
                onPressed: () => setState(() => _e = _e.copyWith(accent: null)),
              ),
          ],
        ),
        if (c.phones.isNotEmpty || c.emails.isNotEmpty)
          header(
            tr(context, 'Labels', 'Etiquetas'),
            sub: tr(
              context,
              'Name each number and email (Mobile, Home, Work…)',
              'Nombra cada número y correo (Móvil, Casa, Trabajo…)',
            ),
          ),
        for (final ph in c.phones)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LabelField(
              hint: ph,
              initial: _e.phoneLabels[ph] ?? '',
              onChanged: (v) =>
                  _e = _e.copyWith(phoneLabels: {..._e.phoneLabels}..[ph] = v),
            ),
          ),
        for (final em in c.emails)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LabelField(
              hint: em,
              initial: _e.emailLabels[em] ?? '',
              onChanged: (v) =>
                  _e = _e.copyWith(emailLabels: {..._e.emailLabels}..[em] = v),
            ),
          ),
        header(
          tr(context, 'Social accounts', 'Redes sociales'),
          sub: tr(
            context,
            'A link or handle: https://… , @name',
            'Un enlace o usuario',
          ),
        ),
        _PairList(
          items: _e.socials,
          keyA: 'label',
          keyB: 'url',
          hintA: tr(context, 'Platform', 'Plataforma'),
          hintB: tr(context, 'Link or @handle', 'Enlace o @usuario'),
          addLabel: tr(context, 'Add account', 'Añadir cuenta'),
          onChanged: (v) => setState(() => _e = _e.copyWith(socials: v)),
        ),
        header(tr(context, 'Addresses', 'Direcciones')),
        _PairList(
          items: _e.addresses,
          keyA: 'label',
          keyB: 'text',
          hintA: tr(context, 'Label (Home)', 'Etiqueta (Casa)'),
          hintB: tr(context, 'Address', 'Dirección'),
          addLabel: tr(context, 'Add address', 'Añadir dirección'),
          onChanged: (v) => setState(() => _e = _e.copyWith(addresses: v)),
        ),
        header(
          tr(
            context,
            'Anniversaries & important dates',
            'Aniversarios y fechas importantes',
          ),
        ),
        _DateList(
          items: _e.dates,
          onChanged: (v) => setState(() => _e = _e.copyWith(dates: v)),
        ),
        header(
          tr(
            context,
            'Communication preferences',
            'Preferencias de comunicación',
          ),
        ),
        PrismTextField(
          controller: _comm,
          maxLines: 3,
          minLines: 2,
          hintText: tr(
            context,
            'Texts over calls, best in the evening…',
            'Mejor mensajes que llamadas…',
          ),
        ),
        header(tr(context, 'Boundaries', 'Límites')),
        PrismTextField(
          controller: _bound,
          maxLines: 3,
          minLines: 2,
          hintText: tr(
            context,
            'What to keep in mind with this person',
            'Qué tener en cuenta con esta persona',
          ),
        ),
        header(tr(context, 'Important reminders', 'Recordatorios importantes')),
        _ReminderList(
          items: _e.reminders,
          onChanged: (v) => setState(() => _e = _e.copyWith(reminders: v)),
        ),
        header(tr(context, 'Custom fields', 'Campos propios')),
        _PairList(
          items: _e.custom,
          keyA: 'label',
          keyB: 'value',
          hintA: tr(context, 'Field name', 'Nombre del campo'),
          hintB: tr(context, 'Value', 'Valor'),
          addLabel: tr(context, 'Add field', 'Añadir campo'),
          onChanged: (v) => setState(() => _e = _e.copyWith(custom: v)),
        ),
        if (names.isNotEmpty) ...[
          header(
            tr(context, 'Connected alters', 'Alters conectados'),
            sub: tr(
              context,
              'Who in your system knows this person',
              'Quién de tu sistema conoce a esta persona',
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in names.entries)
                PrismChip(
                  label: n.value,
                  selected: _e.alters.contains(n.key),
                  onTap: () => setState(
                    () => _e = _e.copyWith(
                      alters: _e.alters.contains(n.key)
                          ? _e.alters.where((a) => a != n.key).toList()
                          : [..._e.alters, n.key],
                    ),
                  ),
                ),
            ],
          ),
          for (final id in _e.alters)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _LabelField(
                hint: tr(
                  context,
                  'How ${names[id] ?? 'they'} relate to ${c.displayName}',
                  'Cómo se relaciona ${names[id] ?? ''} con ${c.displayName}',
                ),
                initial: _e.alterNotes[id] ?? '',
                onChanged: (v) =>
                    _e = _e.copyWith(alterNotes: {..._e.alterNotes}..[id] = v),
              ),
            ),
        ],
        header(
          tr(context, 'Conversation', 'Conversación'),
          sub: tr(
            context,
            'Add a Message shortcut to an existing Prism conversation',
            'Atajo a una conversación existente de Prism',
          ),
        ),
        _ConversationPicker(
          value: _e.conversation,
          onChanged: (v) => setState(() => _e = _e.copyWith(conversation: v)),
        ),
        header(
          tr(
            context,
            'Linked journal, scrapbook & events',
            'Diario, álbumes y eventos vinculados',
          ),
        ),
        _LinkPicker(
          links: _e.links,
          onChanged: (v) => setState(() => _e = _e.copyWith(links: v)),
        ),
        header(tr(context, 'Shared memories', 'Recuerdos compartidos')),
        _StringList(
          items: _e.sharedMemories,
          hint: tr(context, 'A memory you share', 'Un recuerdo compartido'),
          addLabel: tr(context, 'Add memory', 'Añadir recuerdo'),
          onChanged: (v) => setState(() => _e = _e.copyWith(sharedMemories: v)),
        ),
        header(tr(context, 'Gift ideas', 'Ideas de regalo')),
        _StringList(
          items: _e.giftIdeas,
          hint: tr(context, 'A gift idea', 'Una idea de regalo'),
          addLabel: tr(context, 'Add idea', 'Añadir idea'),
          onChanged: (v) => setState(() => _e = _e.copyWith(giftIdeas: v)),
        ),
        header(
          tr(
            context,
            'Safety & comfort labels · private',
            'Etiquetas de seguridad y comodidad · privado',
          ),
          sub: tr(
            context,
            'Only you see these. They are never shared.',
            'Solo tú las ves. Nunca se comparten.',
          ),
        ),
        _StringList(
          items: _e.safety,
          hint: tr(
            context,
            'e.g. Safe person, Needs notice before visits',
            'p. ej. Persona segura',
          ),
          addLabel: tr(context, 'Add label', 'Añadir etiqueta'),
          onChanged: (v) => setState(() => _e = _e.copyWith(safety: v)),
        ),
        header(
          tr(context, 'Private notes · only you', 'Notas privadas · solo tú'),
          sub: tr(
            context,
            'Never shared or shown to anyone else.',
            'Nunca se comparten.',
          ),
        ),
        PrismTextField(controller: _private, maxLines: 6, minLines: 3),
        const SizedBox(height: 20),
        PrismButton(
          label: tr(context, 'Save', 'Guardar'),
          tone: PrismButtonTone.filled,
          expanded: true,
          onPressed: () {
            if (!_saving) _save();
          },
        ),
      ],
    );
  }
}

/// One text field that reports each keystroke (the owner keeps the value).
class _LabelField extends StatefulWidget {
  const _LabelField({
    required this.hint,
    required this.initial,
    required this.onChanged,
  });
  final String hint, initial;
  final ValueChanged<String> onChanged;
  @override
  State<_LabelField> createState() => _LabelFieldState();
}

class _LabelFieldState extends State<_LabelField> {
  late final _c = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PrismTextField(
    controller: _c,
    hintText: widget.hint,
    onChanged: widget.onChanged,
  );
}

/// A list of two-field rows with add and delete.
class _PairList extends StatefulWidget {
  const _PairList({
    required this.items,
    required this.keyA,
    required this.keyB,
    required this.hintA,
    required this.hintB,
    required this.addLabel,
    required this.onChanged,
  });
  final List<Map<String, String>> items;
  final String keyA, keyB, hintA, hintB, addLabel;
  final ValueChanged<List<Map<String, String>>> onChanged;
  @override
  State<_PairList> createState() => _PairListState();
}

class _PairListState extends State<_PairList> {
  late final List<(TextEditingController, TextEditingController)> _rows = [
    for (final i in widget.items)
      (
        TextEditingController(text: i[widget.keyA] ?? ''),
        TextEditingController(text: i[widget.keyB] ?? ''),
      ),
  ];

  @override
  void dispose() {
    for (final r in _rows) {
      r.$1.dispose();
      r.$2.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged([
    for (final r in _rows)
      if (r.$1.text.trim().isNotEmpty || r.$2.text.trim().isNotEmpty)
        {widget.keyA: r.$1.text.trim(), widget.keyB: r.$2.text.trim()},
  ]);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, r) in _rows.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: PrismTextField(
                  controller: r.$1,
                  hintText: widget.hintA,
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: PrismTextField(
                  controller: r.$2,
                  hintText: widget.hintB,
                  onChanged: (_) => _emit(),
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Remove', 'Quitar'),
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    final x = _rows.removeAt(i);
                    x.$1.dispose();
                    x.$2.dispose();
                  });
                  _emit();
                },
              ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: PrismButton(
          icon: Icons.add,
          label: widget.addLabel,
          tone: PrismButtonTone.outlined,
          density: PrismControlDensity.compact,
          onPressed: () => setState(
            () => _rows.add((TextEditingController(), TextEditingController())),
          ),
        ),
      ),
    ],
  );
}

class _StringList extends StatefulWidget {
  const _StringList({
    required this.items,
    required this.hint,
    required this.addLabel,
    required this.onChanged,
  });
  final List<String> items;
  final String hint, addLabel;
  final ValueChanged<List<String>> onChanged;
  @override
  State<_StringList> createState() => _StringListState();
}

class _StringListState extends State<_StringList> {
  late final List<TextEditingController> _rows = [
    for (final i in widget.items) TextEditingController(text: i),
  ];

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged([
    for (final r in _rows)
      if (r.text.trim().isNotEmpty) r.text.trim(),
  ]);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, r) in _rows.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: PrismTextField(
                  controller: r,
                  hintText: widget.hint,
                  onChanged: (_) => _emit(),
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Remove', 'Quitar'),
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => _rows.removeAt(i).dispose());
                  _emit();
                },
              ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: PrismButton(
          icon: Icons.add,
          label: widget.addLabel,
          tone: PrismButtonTone.outlined,
          density: PrismControlDensity.compact,
          onPressed: () => setState(() => _rows.add(TextEditingController())),
        ),
      ),
    ],
  );
}

class _DateList extends StatefulWidget {
  const _DateList({required this.items, required this.onChanged});
  final List<Map<String, String>> items;
  final ValueChanged<List<Map<String, String>>> onChanged;
  @override
  State<_DateList> createState() => _DateListState();
}

class _DateListState extends State<_DateList> {
  late final List<(TextEditingController, DateTime?)> _rows = [
    for (final i in widget.items)
      (
        TextEditingController(text: i['label'] ?? ''),
        DateTime.tryParse(i['date'] ?? ''),
      ),
  ];

  @override
  void dispose() {
    for (final r in _rows) {
      r.$1.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged([
    for (final r in _rows)
      if (r.$2 != null)
        {
          'label': r.$1.text.trim(),
          'date':
              '${r.$2!.year.toString().padLeft(4, '0')}-${r.$2!.month.toString().padLeft(2, '0')}-${r.$2!.day.toString().padLeft(2, '0')}',
        },
  ]);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, r) in _rows.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: PrismTextField(
                  controller: r.$1,
                  hintText: tr(
                    context,
                    'Anniversary, met on…',
                    'Aniversario, nos conocimos…',
                  ),
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (bc) => PrismButton(
                  label: r.$2 == null
                      ? tr(context, 'Pick date', 'Elegir fecha')
                      : '${r.$2!.day}/${r.$2!.month}/${r.$2!.year}',
                  tone: PrismButtonTone.outlined,
                  density: PrismControlDensity.compact,
                  onPressed: () async {
                    final d = await showPrismDatePicker(
                      context: context,
                      anchorContext: bc,
                      initialDate: r.$2 ?? DateTime.now(),
                    );
                    if (d != null) {
                      setState(() => _rows[i] = (r.$1, d));
                      _emit();
                    }
                  },
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Remove', 'Quitar'),
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => _rows.removeAt(i).$1.dispose());
                  _emit();
                },
              ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: PrismButton(
          icon: Icons.add,
          label: tr(context, 'Add date', 'Añadir fecha'),
          tone: PrismButtonTone.outlined,
          density: PrismControlDensity.compact,
          onPressed: () =>
              setState(() => _rows.add((TextEditingController(), null))),
        ),
      ),
    ],
  );
}

class _ReminderList extends StatefulWidget {
  const _ReminderList({required this.items, required this.onChanged});
  final List<Map<String, String>> items;
  final ValueChanged<List<Map<String, String>>> onChanged;
  @override
  State<_ReminderList> createState() => _ReminderListState();
}

class _ReminderListState extends State<_ReminderList> {
  late final List<(TextEditingController, DateTime?)> _rows = [
    for (final i in widget.items)
      (
        TextEditingController(text: i['text'] ?? ''),
        DateTime.tryParse(i['date'] ?? ''),
      ),
  ];

  @override
  void dispose() {
    for (final r in _rows) {
      r.$1.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged([
    for (final r in _rows)
      if (r.$1.text.trim().isNotEmpty)
        {
          'text': r.$1.text.trim(),
          if (r.$2 != null) 'date': r.$2!.toIso8601String().substring(0, 10),
        },
  ]);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, r) in _rows.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: PrismTextField(
                  controller: r.$1,
                  hintText: tr(context, 'Remember to…', 'Recordar…'),
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (bc) => PrismButton(
                  label: r.$2 == null
                      ? tr(context, 'No date', 'Sin fecha')
                      : '${r.$2!.day}/${r.$2!.month}/${r.$2!.year}',
                  tone: PrismButtonTone.outlined,
                  density: PrismControlDensity.compact,
                  onPressed: () async {
                    final d = await showPrismDatePicker(
                      context: context,
                      anchorContext: bc,
                      initialDate: r.$2 ?? DateTime.now(),
                    );
                    if (d != null) {
                      setState(() => _rows[i] = (r.$1, d));
                      _emit();
                    }
                  },
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Remove', 'Quitar'),
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => _rows.removeAt(i).$1.dispose());
                  _emit();
                },
              ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: PrismButton(
          icon: Icons.add,
          label: tr(context, 'Add reminder', 'Añadir recordatorio'),
          tone: PrismButtonTone.outlined,
          density: PrismControlDensity.compact,
          onPressed: () =>
              setState(() => _rows.add((TextEditingController(), null))),
        ),
      ),
    ],
  );
}

class _ConversationPicker extends ConsumerWidget {
  const _ConversationPicker({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convs = ref.watch(conversationsProvider).value ?? const [];
    if (convs.isEmpty) {
      return Text(
        tr(context, 'No conversations yet.', 'Aún no hay conversaciones.'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return PrismSelect<String>(
      labelText: tr(context, 'Conversation', 'Conversación'),
      value: value ?? '',
      items: [
        PrismSelectItem(value: '', label: tr(context, 'None', 'Ninguna')),
        for (final c in convs)
          PrismSelectItem(
            value: c.id,
            label:
                '${c.emoji ?? '💬'} ${c.title ?? tr(context, 'Conversation', 'Conversación')}',
          ),
      ],
      onChanged: (v) => onChanged(v == null || v.isEmpty ? null : v),
    );
  }
}

/// Link journal entries, scrapbook pages and calendar events to a contact.
class _LinkPicker extends ConsumerWidget {
  const _LinkPicker({required this.links, required this.onChanged});
  final List<String> links;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal =
        ref.watch(trackerKindProvider(TrackerKind.journalEntry)).value ??
        const [];
    final pages =
        ref.watch(trackerKindProvider(TrackerKind.scrapPage)).value ?? const [];
    final events = ref.watch(calendarEventsProvider).value ?? const [];
    String label(String ref0) {
      final i = ref0.indexOf(':');
      final kind = ref0.substring(0, i), id = ref0.substring(i + 1);
      return switch (kind) {
        'journal' =>
          '📓 ${journal.where((r) => r.id == id).firstOrNull?.title ?? tr(context, 'Journal entry', 'Entrada de diario')}',
        'scrap' =>
          '📖 ${pages.where((r) => r.id == id).firstOrNull?.title ?? tr(context, 'Scrapbook page', 'Página de álbum')}',
        _ =>
          '📅 ${events.where((e) => e.id == id).firstOrNull?.title ?? tr(context, 'Event', 'Evento')}',
      };
    }

    Future<void> add(
      String kind,
      List<(String id, String title)> options,
      String title,
    ) async {
      final picked = await PrismSheet.show<String>(
        context: context,
        title: title,
        builder: (ctx) => SizedBox(
          height: 360,
          child: options.isEmpty
              ? Center(
                  child: Text(
                    tr(
                      ctx,
                      'Nothing to link yet.',
                      'Aún no hay nada para vincular.',
                    ),
                  ),
                )
              : ListView(
                  children: [
                    for (final o in options.where(
                      (o) => !links.contains('$kind:${o.$1}'),
                    ))
                      PrismListRow(
                        title: Text(o.$2.isEmpty ? '—' : o.$2),
                        onTap: () => Navigator.of(ctx).pop(o.$1),
                      ),
                  ],
                ),
        ),
      );
      if (picked != null) onChanged([...links, '$kind:$picked']);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final l in links)
              PrismChip(
                label: label(l),
                selected: true,
                onTap: () => onChanged(links.where((x) => x != l).toList()),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PrismButton(
              label: tr(context, 'Journal entry', 'Entrada de diario'),
              icon: Icons.add,
              tone: PrismButtonTone.outlined,
              density: PrismControlDensity.compact,
              onPressed: () => add('journal', [
                for (final r in journal) (r.id, r.title),
              ], tr(context, 'Link a journal entry', 'Vincular entrada')),
            ),
            PrismButton(
              label: tr(context, 'Scrapbook page', 'Página de álbum'),
              icon: Icons.add,
              tone: PrismButtonTone.outlined,
              density: PrismControlDensity.compact,
              onPressed: () => add('scrap', [
                for (final r in pages) (r.id, r.title),
              ], tr(context, 'Link a scrapbook page', 'Vincular página')),
            ),
            PrismButton(
              label: tr(context, 'Calendar event', 'Evento'),
              icon: Icons.add,
              tone: PrismButtonTone.outlined,
              density: PrismControlDensity.compact,
              onPressed: () => add('cal', [
                for (final e in events) (e.id, e.title),
              ], tr(context, 'Link an event', 'Vincular evento')),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            tr(
              context,
              'Tap a linked item to remove it.',
              'Toca un elemento para quitarlo.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
