import 'package:prism_plurality/features/companions/companion_screens.dart'
    show memberNamesProvider;
import 'package:prism_plurality/features/voice/voice_engine.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Personality & voice: how Prism talks to you.
class VoiceSettingsScreen extends ConsumerStatefulWidget {
  const VoiceSettingsScreen({super.key});
  @override
  ConsumerState<VoiceSettingsScreen> createState() =>
      _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends ConsumerState<VoiceSettingsScreen> {
  VoiceContext _previewCtx = VoiceContext.greeting;
  int _shuffle = 0;

  VoiceActions get _a => ref.read(voiceActionsProvider);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(voiceSettingsProvider);
    final engine = ref.watch(voiceEngineProvider);
    final theme = Theme.of(context);
    final names = ref.watch(memberNamesProvider);
    final custom = ref.watch(customLinesProvider);
    final t = s.base;
    String sample(VoiceContext c, VoiceTuning tun) {
      _shuffle;
      return engine.line(
        c,
        preview: tun,
        vars: const {'name': 'Sam', 'game': 'Word Hunt', 'score': '12'},
      );
    }

    Widget slider(
      String label,
      String low,
      String high,
      double v,
      ValueChanged<double> on,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(low, style: theme.textTheme.labelSmall),
              ),
              Expanded(
                child: Slider(
                  value: v,
                  onChanged: on,
                  semanticFormatterCallback: (x) =>
                      '$label ${(x * 100).round()}%',
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  high,
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return PrismPageScaffold(
      topBar: const PrismTopBar(
        title: 'Personality & voice',
        showBackButton: true,
      ),
      bodyPadding: EdgeInsets.zero,
      body: ClampedBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + NavBarInset.of(context)),
          children: [
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: PrismSwitchRow(
                title: 'Use Prism\'s personality',
                subtitle:
                    'Off keeps Prism\'s standard wording everywhere. Works offline; English only for now.',
                value: s.enabled,
                onChanged: (v) => _a.save(s.copyWith(enabled: v)),
              ),
            ),
            PrismSectionHeader(title: 'LIVE PREVIEW'),
            PrismSurface(
              tone: PrismSurfaceTone.strong,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“${sample(_previewCtx, t)}”',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_previewCtx.label}${_previewCtx.sensitive ? ' · sensitive — always gentle' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      PrismButton(
                        label: 'Another',
                        icon: Icons.refresh,
                        density: PrismControlDensity.compact,
                        onPressed: () => setState(() => _shuffle++),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in VoiceContext.values)
                  PrismChip(
                    label: c.label,
                    selected: _previewCtx == c,
                    onTap: () => setState(() => _previewCtx = c),
                  ),
              ],
            ),
            PrismSectionHeader(title: 'PRESETS'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in voicePresets.entries)
                  PrismChip(
                    label: e.key,
                    selected:
                        t.toJson().toString() == e.value.toJson().toString(),
                    onTap: () => _a.save(s.copyWith(base: e.value)),
                  ),
              ],
            ),
            PrismSectionHeader(title: 'STYLE'),
            LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth > 600
                    ? (box.maxWidth - 16) / 3
                    : (box.maxWidth > 380
                          ? (box.maxWidth - 8) / 2
                          : box.maxWidth);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in VoiceStyle.values)
                      SizedBox(
                        width: w,
                        child: PrismSurface(
                          onTap: () =>
                              _a.save(s.copyWith(base: t.copyWith(style: v))),
                          semanticLabel:
                              '${v.label} style${t.style == v ? ', selected' : ''}',
                          accentColor: t.style == v
                              ? theme.colorScheme.primary
                              : null,
                          tone: t.style == v
                              ? PrismSurfaceTone.accent
                              : PrismSurfaceTone.subtle,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      v.label,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ),
                                  if (t.style == v)
                                    Icon(
                                      Icons.check_circle,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                ],
                              ),
                              Text(v.blurb, style: theme.textTheme.bodySmall),
                              const SizedBox(height: 6),
                              Text(
                                '“${sample(VoiceContext.greeting, t.copyWith(style: v))}”',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            PrismSectionHeader(title: 'FINE-TUNE'),
            slider(
              'Emoji',
              'None',
              'Lots',
              t.emoji,
              (v) => _a.save(s.copyWith(base: t.copyWith(emoji: v))),
            ),
            slider(
              'Energy',
              'Calm',
              'Excited',
              t.energy,
              (v) => _a.save(s.copyWith(base: t.copyWith(energy: v))),
            ),
            slider(
              'Warmth',
              'Reserved',
              'Affectionate',
              t.warmth,
              (v) => _a.save(s.copyWith(base: t.copyWith(warmth: v))),
            ),
            slider(
              'Length',
              'Short',
              'Chatty',
              t.length,
              (v) => _a.save(s.copyWith(base: t.copyWith(length: v))),
            ),
            slider(
              'Formality',
              'Casual',
              'Formal',
              t.formality,
              (v) => _a.save(s.copyWith(base: t.copyWith(formality: v))),
            ),
            PrismSectionHeader(title: 'BY FEATURE'),
            Text(
              'Give parts of Prism their own voice — say, Gamer for Games and Poetic for Astro.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final f in voiceFeatures.entries)
                    PrismListRow(
                      dense: true,
                      title: Text(f.value),
                      trailing: SizedBox(
                        width: 170,
                        child: PrismSelect<String>.compact(
                          value: s.features[f.key]?.name ?? '',
                          items: [
                            const PrismSelectItem(
                              value: '',
                              label: 'Main style',
                            ),
                            for (final v in VoiceStyle.values)
                              PrismSelectItem(value: v.name, label: v.label),
                          ],
                          onChanged: (v) {
                            final next = {...s.features};
                            if (v == null || v.isEmpty) {
                              next.remove(f.key);
                            } else {
                              next[f.key] = VoiceStyle.values.byName(v);
                            }
                            _a.save(s.copyWith(features: next));
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PrismSectionHeader(title: 'BY HEADMATE'),
            Text(
              'When someone with their own voice is fronting, Prism talks their way.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final e in s.profiles.entries)
                    PrismListRow(
                      dense: true,
                      title: Text(names[e.key] ?? 'Someone'),
                      subtitle: Text(e.value.style.label),
                      onTap: () =>
                          _editProfile(s, e.key, names[e.key] ?? 'Someone'),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close),
                        onPressed: () => _a.save(
                          s.copyWith(profiles: {...s.profiles}..remove(e.key)),
                        ),
                      ),
                    ),
                  PrismListRow(
                    dense: true,
                    leading: const Icon(Icons.person_add_alt),
                    title: const Text('Add a headmate\'s voice'),
                    onTap: () async {
                      final pick = await PrismSheet.show<String>(
                        context: context,
                        title: 'Whose voice?',
                        builder: (ctx) => ListView(
                          shrinkWrap: true,
                          children: [
                            for (final n in names.entries)
                              if (!s.profiles.containsKey(n.key))
                                PrismListRow(
                                  title: Text(n.value),
                                  onTap: () => Navigator.of(ctx).pop(n.key),
                                ),
                          ],
                        ),
                      );
                      if (pick != null) {
                        await _a.save(
                          s.copyWith(profiles: {...s.profiles, pick: s.base}),
                        );
                        if (mounted)
                          _editProfile(
                            ref.read(voiceSettingsProvider),
                            pick,
                            names[pick] ?? 'Someone',
                          );
                      }
                    },
                  ),
                ],
              ),
            ),
            PrismSectionHeader(title: 'SENSITIVE MOMENTS'),
            Text(
              'Hard days and health moments never get teasing, grumpy or chaotic wording. Choose the gentle voice used then:',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in VoiceStyle.values.where((v) => v.gentle))
                  PrismChip(
                    label: v.label,
                    selected: s.sensitiveStyle == v,
                    onTap: () => _a.save(s.copyWith(sensitiveStyle: v)),
                  ),
              ],
            ),
            PrismSectionHeader(title: 'YOUR OWN LINES'),
            PrismSurface(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  PrismSwitchRow(
                    title: 'Use my lines',
                    subtitle: 'Mixed in with Prism\'s, and picked more often',
                    value: s.customTracks,
                    onChanged: (v) => _a.save(s.copyWith(customTracks: v)),
                  ),
                  for (final l in custom)
                    PrismListRow(
                      dense: true,
                      title: Text(
                        l.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          l.context.label,
                          if (l.style != null) l.style!.label,
                          if (l.memberId != null)
                            names[l.memberId] ?? 'Someone',
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: l.enabled,
                            onChanged: (v) => _a.toggleLine(l, v),
                          ),
                          IconButton(
                            tooltip: 'Delete line',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _a.deleteLine(l),
                          ),
                        ],
                      ),
                    ),
                  PrismListRow(
                    dense: true,
                    leading: const Icon(Icons.add),
                    title: const Text('Write a line'),
                    subtitle: const Text('Use {name} for whoever\'s fronting'),
                    onTap: () => _addLine(names),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile(VoiceSettings s, String id, String name) async {
    await PrismSheet.show<void>(
      context: context,
      title: '$name\'s voice',
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final cur = ref.watch(voiceSettingsProvider);
          final t = cur.profiles[id] ?? cur.base;
          void put(VoiceTuning n) => ref
              .read(voiceActionsProvider)
              .save(cur.copyWith(profiles: {...cur.profiles, id: n}));
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '“${ref.read(voiceEngineProvider).line(VoiceContext.greeting, preview: t, vars: {'name': name})}”',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final v in VoiceStyle.values)
                      PrismChip(
                        label: v.label,
                        selected: t.style == v,
                        onTap: () => put(t.copyWith(style: v)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 70, child: Text('Emoji')),
                    Expanded(
                      child: Slider(
                        value: t.emoji,
                        onChanged: (v) => put(t.copyWith(emoji: v)),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 70, child: Text('Energy')),
                    Expanded(
                      child: Slider(
                        value: t.energy,
                        onChanged: (v) => put(t.copyWith(energy: v)),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 70, child: Text('Warmth')),
                    Expanded(
                      child: Slider(
                        value: t.warmth,
                        onChanged: (v) => put(t.copyWith(warmth: v)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addLine(Map<String, String> names) async {
    final text = TextEditingController();
    var ctx = VoiceContext.greeting;
    VoiceStyle? style;
    String? member;
    final ok = await PrismSheet.show<bool>(
      context: context,
      title: 'Write a line',
      builder: (c) => StatefulBuilder(
        builder: (c, set) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            PrismTextField(
              controller: text,
              labelText: 'What should Prism say?',
              hintText: 'Morning, {name}! The plants missed you.',
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            PrismSelect<String>(
              labelText: 'When',
              value: ctx.name,
              items: [
                for (final v in VoiceContext.values)
                  PrismSelectItem(
                    value: v.name,
                    label: v.label,
                    subtitle: v.hint,
                  ),
              ],
              onChanged: (v) =>
                  set(() => ctx = VoiceContext.values.byName(v ?? ctx.name)),
            ),
            const SizedBox(height: 10),
            PrismSelect<String>(
              labelText: 'Only in this style',
              value: style?.name ?? '',
              items: [
                const PrismSelectItem(value: '', label: 'Any style'),
                for (final v in VoiceStyle.values)
                  PrismSelectItem(value: v.name, label: v.label),
              ],
              onChanged: (v) => set(
                () => style = v == null || v.isEmpty
                    ? null
                    : VoiceStyle.values.byName(v),
              ),
            ),
            const SizedBox(height: 10),
            PrismSelect<String>(
              labelText: 'Only for',
              value: member ?? '',
              items: [
                const PrismSelectItem(value: '', label: 'Everyone'),
                for (final n in names.entries)
                  PrismSelectItem(value: n.key, label: n.value),
              ],
              onChanged: (v) =>
                  set(() => member = v == null || v.isEmpty ? null : v),
            ),
            if (ctx.sensitive) ...[
              const SizedBox(height: 8),
              Text(
                'This is a sensitive moment — please keep it gentle.',
                style: Theme.of(c).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            PrismButton(
              label: 'Save line',
              tone: PrismButtonTone.filled,
              onPressed: () => Navigator.of(c).pop(true),
            ),
          ],
        ),
      ),
    );
    if (ok == true && text.text.trim().isNotEmpty)
      await _a.addLine(text.text, ctx, style: style, memberId: member);
    text.dispose();
  }
}
