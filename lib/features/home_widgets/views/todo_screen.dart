import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prism_plurality/domain/models/tracker_record.dart';
import 'package:prism_plurality/features/accessibility/a11y_views.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_models.dart';
import 'package:prism_plurality/features/members/providers/members_providers.dart';
import 'package:prism_plurality/features/trackers/providers/tracker_providers.dart';
import 'package:prism_plurality/features/trackers/widgets/member_picker.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';
import 'package:prism_plurality/shared/theme/app_icons.dart';
import 'package:prism_plurality/shared/theme/prism_tokens.dart';
import 'package:prism_plurality/shared/widgets/prism_button.dart';
import 'package:prism_plurality/shared/widgets/prism_date_picker.dart';
import 'package:prism_plurality/shared/widgets/prism_page_scaffold.dart';
import 'package:prism_plurality/shared/widgets/prism_surface.dart';
import 'package:prism_plurality/shared/widgets/prism_text_field.dart';
import 'package:prism_plurality/shared/widgets/prism_top_bar.dart';

/// Simple shared to-do list (also shown by the To-Do widget). Each task
/// can belong to a member; new ones default to whoever is fronting.
class TodoScreen extends ConsumerStatefulWidget {
  const TodoScreen({super.key, this.focusNew = false});

  final bool focusNew;

  @override
  ConsumerState<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends ConsumerState<TodoScreen> {
  final _title = TextEditingController();
  final _focus = FocusNode();
  DateTime? _due;
  String? _memberId;
  String? _filter;
  bool _memberTouched = false;

  @override
  void dispose() {
    _title.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    await ref.read(trackerNotifierProvider.notifier).create(
      kind: todoKind,
      title: title,
      occurredAt: _due,
      memberId: _memberTouched ? _memberId : currentFronterId(ref),
    );
    _title.clear();
    setState(() => _due = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final all = ref.watch(trackerKindProvider(todoKind)).value ?? const <TrackerRecord>[];
    final members = {for (final m in ref.watch(allMembersProvider).value ?? const []) m.id: m};
    final items = [for (final t in all) if (_filter == null || t.memberId == _filter) t]
      ..sort((a, b) {
        if (a.flag('done') != b.flag('done')) return a.flag('done') ? 1 : -1;
        final ad = a.occurredAt, bd = b.occurredAt;
        if (ad == null && bd == null) return b.createdAt.compareTo(a.createdAt);
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    final notifier = ref.read(trackerNotifierProvider.notifier);
    final fmt = MaterialLocalizations.of(context);
    return PrismPageScaffold(
      topBar: PrismTopBar(title: l10n.hwTodo, showBackButton: true),
      topBarMaxWidth: PrismTokens.contentMaxWidth,
      bodyPadding: EdgeInsets.zero,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: PrismTokens.contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrismSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PrismTextField(
                          controller: _title,
                          focusNode: _focus,
                          autofocus: widget.focusNew,
                          labelText: l10n.hwAddTask,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _add(),
                        ),
                        const SizedBox(height: 8),
                        TrackerMemberPicker(
                          label: l10n.hwTaskFor,
                          value: _memberTouched ? _memberId : currentFronterId(ref),
                          onChanged: (v) => setState(() {
                            _memberTouched = true;
                            _memberId = v;
                          }),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Builder(
                              builder: (anchor) => PrismButton(
                                label: _due == null ? l10n.hwDueDate : fmt.formatMediumDate(_due!),
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final d = await showPrismDatePicker(
                                    context: context,
                                    anchorContext: anchor,
                                    initialDate: _due ?? now,
                                    firstDate: DateTime(now.year - 1),
                                    lastDate: DateTime(now.year + 10),
                                  );
                                  if (d != null) setState(() => _due = d);
                                },
                              ),
                            ),
                            PrismButton(label: l10n.add, tone: PrismButtonTone.filled, onPressed: _add),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TrackerMemberFilter(value: _filter, onChanged: (v) => setState(() => _filter = v)),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l10n.hwNoTasks, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                    ),
                  for (final TrackerRecord t in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: PrismSurface(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        onTap: () => notifier.save(t.withFields({'done': !t.flag('done')})),
                        child: Row(
                          children: [
                            Icon(
                              t.flag('done') ? AppIcons.checkCircle : AppIcons.radioButtonUnchecked,
                              color: t.flag('done') ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.title,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      decoration: t.flag('done') ? TextDecoration.lineThrough : null,
                                      color: t.flag('done') ? theme.colorScheme.onSurfaceVariant : null,
                                    ),
                                  ),
                                  if (t.occurredAt != null || members[t.memberId] != null)
                                    Text(
                                      [
                                        if (members[t.memberId] != null) members[t.memberId]!.name,
                                        if (t.occurredAt != null) fmt.formatMediumDate(t.occurredAt!),
                                      ].join(' · '),
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                ],
                              ),
                            ),
                            PrismButton(
                              label: l10n.delete,
                              density: PrismControlDensity.compact,
                              tone: PrismButtonTone.destructive,
                              onPressed: () async {
                                if (await confirmIfAsked(context, ref, title: l10n.delete, message: t.title)) await notifier.delete(t.id);
                              },
                            ),
                          ],
                        ),
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
