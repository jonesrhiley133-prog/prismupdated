import 'package:cupertino_calendar_picker/cupertino_calendar_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoTheme, CupertinoThemeData, CupertinoTextThemeData;
import 'package:flutter/material.dart';

/// Shows a time picker.
///
/// With a small [anchorContext] (the tapped button, from a [Builder]) it
/// opens as an inline iOS-style dropdown next to that button. Without one —
/// or when the anchor is a whole sheet or screen, which used to squeeze the
/// dropdown into a tiny strip at the top — it opens a full-size wheel
/// picker in a bottom sheet instead.
Future<TimeOfDay?> showPrismTimePicker({
  required BuildContext context,
  BuildContext? anchorContext,
  required TimeOfDay initialTime,
}) {
  final anchor = anchorContext ?? context;
  final renderBox = anchor.findRenderObject() as RenderBox?;
  final use24 = MediaQuery.of(context).alwaysUse24HourFormat;
  final small = renderBox != null && renderBox.hasSize && renderBox.size.height <= 120 && renderBox.size.width <= MediaQuery.sizeOf(context).width * 0.9;
  if (anchorContext != null && small) {
    return showCupertinoTimePicker(context, widgetRenderBox: renderBox, initialTime: initialTime, use24hFormat: use24);
  }
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _TimeWheelSheet(initialTime: initialTime, use24: use24),
  );
}

class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.initialTime, required this.use24});
  final TimeOfDay initialTime;
  final bool use24;
  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  late TimeOfDay _value = widget.initialTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final l10n = MaterialLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: theme.brightness,
                primaryColor: theme.colorScheme.primary,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: widget.use24,
                initialDateTime: DateTime(now.year, now.month, now.day, widget.initialTime.hour, widget.initialTime.minute),
                onDateTimeChanged: (d) => _value = TimeOfDay(hour: d.hour, minute: d.minute),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancelButtonLabel))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: () => Navigator.of(context).pop(_value), child: Text(l10n.okButtonLabel))),
            ],
          ),
        ],
      ),
    );
  }
}
