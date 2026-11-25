import 'package:prism_plurality/features/links/models/record_ref.dart';
import 'package:prism_plurality/features/links/providers/link_providers.dart';
import 'package:prism_plurality/shared/ui_kit.dart';

/// Pick an existing Prism record to attach (by reference — nothing is
/// copied). Private records are marked so nothing sensitive is added by
/// accident.
Future<String?> pickRecordKey(
  BuildContext context,
  WidgetRef ref, {
  String title = 'Attach a record',
}) {
  final catalog = ref.read(recordCatalogProvider).values.toList()
    ..sort(
      (a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)),
    );
  var query = '';
  String? module;
  return PrismSheet.show<String>(
    context: context,
    title: title,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final list = catalog
            .where(
              (r) =>
                  (module == null || r.module == module) &&
                  (query.isEmpty ||
                      '${r.title} ${r.subtitle ?? ''}'.toLowerCase().contains(
                        query,
                      )),
            )
            .take(80)
            .toList();
        final modules = {for (final r in catalog) r.module}.toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: PrismTextField(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                onChanged: (v) => set(() => query = v.trim().toLowerCase()),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PrismChip(
                      label: 'All',
                      selected: module == null,
                      onTap: () => set(() => module = null),
                    ),
                  ),
                  for (final m in modules)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PrismChip(
                        label: moduleFor(m).label(ctx),
                        selected: module == m,
                        onTap: () => set(() => module = m),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nothing found.'),
                    ),
                  for (final r in list)
                    PrismListRow(
                      leading: Icon(
                        moduleFor(r.module).icon,
                        color: moduleFor(r.module).color,
                      ),
                      title: Text(
                        r.title.isEmpty ? '(untitled)' : r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          moduleFor(r.module).label(ctx),
                          if (r.isPrivate) '🔒 private',
                        ].join(' · '),
                      ),
                      onTap: () => Navigator.of(ctx).pop(r.ref.key),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
