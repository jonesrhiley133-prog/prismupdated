import 'package:prism_plurality/shared/ui_kit.dart';

/// Pick any colour with hue/saturation/brightness sliders.
Future<Color?> showPrismColorPicker({
  required BuildContext context,
  required Color initial,
  String title = 'Custom colour',
}) {
  var value = initial.toARGB32();
  return PrismSheet.show<Color>(
    context: context,
    title: title,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Color(value),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            HsvSliders(value: value, onChanged: (v) => set(() => value = v)),
            const SizedBox(height: 12),
            PrismButton(
              label: 'Use colour',
              tone: PrismButtonTone.filled,
              onPressed: () => Navigator.of(ctx).pop(Color(value)),
            ),
          ],
        ),
      ),
    ),
  );
}
