import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:prism_plurality/shared/theme/prism_shapes.dart';
import 'package:flutter/material.dart';

import 'package:prism_plurality/features/home_widgets/models/widget_config.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_controller.dart';
import 'package:prism_plurality/features/home_widgets/services/home_widget_data.dart';
import 'package:prism_plurality/shared/extensions/app_localizations_extension.dart';

/// Home screen sizes in dp for the three widget sizes.
Size widgetPreviewSize(String size) => switch (size) {
  'small' => const Size(156, 156),
  'medium' => const Size(328, 156),
  _ => const Size(328, 340),
};

String _time(AppLocalizations l10n, Object? ms, Object? style, DateTime now) {
  if (ms is! int || ms <= 0) return '';
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  if (style == 'days') {
    final d = DateTime(t.year, t.month, t.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (d == 0) return l10n.hwToday;
    if (d == 1) return l10n.hwTomorrow;
    return d > 0 ? l10n.hwInDays(d) : l10n.hwDaysAgo(-d);
  }
  final diff = now.difference(t).abs();
  final v = diff.inMinutes < 60
      ? l10n.hwMinutesShort(diff.inMinutes)
      : diff.inHours < 24
      ? l10n.hwHoursShort(diff.inHours)
      : l10n.hwDaysShort(diff.inDays);
  return t.isAfter(now) ? l10n.hwInTime(v) : l10n.hwTimeAgo(v);
}

String? _fontFamily(WidgetFont f) => switch (f) {
  WidgetFont.sans => null,
  WidgetFont.serif => 'serif',
  WidgetFont.mono => 'monospace',
  WidgetFont.condensed => 'sans-serif-condensed',
};

final _imageCache = <String, Uint8List>{};
Uint8List? _decode(Object? b64) {
  if (b64 is! String || b64.isEmpty) return null;
  try {
    return _imageCache.putIfAbsent(b64, () => base64Decode(b64));
  } on FormatException {
    return null;
  }
}

/// In-app rendering of a widget model that follows the same rules as the
/// native renderer (row limits, sizes, palette, fonts).
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({super.key, required this.model, required this.config, required this.data, required this.size, required this.dark});

  /// Model from buildWidgetModel (not yet enriched with images).
  final Map<String, Object?> model;
  final WidgetConfig config;
  final HomeWidgetData? data;
  final String size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = config.style;
    final pal = paletteFor(s, dark: s.theme == WidgetTheme.system ? dark : s.theme != WidgetTheme.light);
    final dims = widgetPreviewSize(size);
    final small = size == 'small';
    final scale = s.textScale;
    final family = _fontFamily(s.font);
    final now = data?.now ?? DateTime.now();
    final text = Color(pal.text), text2 = Color(pal.text2), accent = Color(pal.accent);
    final header = model['header'] as Map<String, Object?>?;
    final rows = [for (final r in model['rows'] as List? ?? const []) r as Map<String, Object?>];
    final buttons = [for (final b in model['buttons'] as List? ?? const []) b as Map<String, Object?>];
    final mapId = model['headspaceMapId'];
    final hasImage = mapId is String && !small;
    final maxRows = switch (size) {
      'small' => model['rowsSmall'] as int? ?? 2,
      'medium' => model['rowsMedium'] as int? ?? (hasImage ? 1 : 4),
      _ => model['rowsLarge'] as int? ?? (hasImage ? 3 : 8),
    };
    final maxButtons = switch (size) { 'small' => model['buttonsSmall'] as int? ?? 2, 'medium' => 3, _ => 5 };
    final bg = _decode(s.bgImage);
    final radius = prismCorners(context, s.radius);
    final angle = s.gradientAngle * math.pi / 180;

    Widget avatar(Map<String, Object?> node, double d) {
      if (!s.showAvatars) return const SizedBox.shrink();
      final id = node['memberId'];
      final bytes = id is String ? data?.members[id]?.avatarImageData : null;
      final emoji = node['emoji'];
      if (bytes != null && bytes.isNotEmpty) {
        final r = switch (s.avatarShape) { AvatarShape.circle => d / 2, AvatarShape.rounded => d / 4, AvatarShape.square => 0.0 };
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ClipRRect(
            borderRadius: prismCorners(context, r),
            child: Image.memory(bytes, width: d, height: d, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        );
      }
      if (emoji is String && emoji.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(emoji, style: TextStyle(fontSize: d * 0.62)),
        );
      }
      return const SizedBox.shrink();
    }

    TextStyle ts(double sz, Color c, {FontWeight w = FontWeight.w400}) =>
        TextStyle(fontSize: sz * scale, color: c, fontWeight: w, fontFamily: family, height: 1.2, decoration: TextDecoration.none);

    final children = <Widget>[];
    if (header != null) {
      final sub = header['subtitle'];
      final showSub = sub is String && sub.isNotEmpty && (!small || header['subtitleSmall'] == true);
      final trailing = (header['trailing'] as String?)?.isNotEmpty == true
          ? header['trailing'] as String
          : _time(l10n, header['time'], header['timeStyle'], now);
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            avatar(header, small ? 26 : 34),
            Expanded(
                            child: Column(
                crossAxisAlignment: s.centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  Text('${header['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(small ? 14 : 16, text, w: FontWeight.w700)),
                  if (showSub) Text(sub, maxLines: small ? 1 : 2, overflow: TextOverflow.ellipsis, style: ts(11, text2)),
                ],
              ),
            ),
            if (trailing.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: dims.width * 0.42),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(trailing, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, text2)),
                ),
              ),
            if (s.showRefresh && !small) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.refresh, size: 16, color: text2)),
          ],
        ),
      );
    }
    if (hasImage) {
      children.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: FutureBuilder<String?>(
              future: data == null
                  ? null
                  : renderHeadspaceMap(mapId, data!, hidePrivate: config.privacy.hideSensitive, textColor: pal.text),
              builder: (context, snap) {
                final bytes = _decode(snap.data);
                return bytes == null ? const SizedBox.expand() : Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true);
              },
            ),
          ),
        ),
      );
    }
    final shown = rows.take(maxRows).toList();
    if (shown.isEmpty && rows.isEmpty && model['empty'] is String && !hasImage) {
      children.add(
        Expanded(
          child: Center(
            child: Text(model['empty'] as String, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: ts(12, text2)),
          ),
        ),
      );
    } else if (shown.isNotEmpty) {
      final list = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in shown)
            Padding(
              padding: EdgeInsets.only(top: s.compact ? 3 : 6),
              child: Row(
                children: [
                  avatar(r, 24),
                  Expanded(
                                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${r['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, text, w: FontWeight.w500)),
                        if (r['subtitle'] is String && (r['subtitle'] as String).isNotEmpty && !(s.compact && small))
                          Text(r['subtitle'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, text2)),
                        if (r['progress'] is num)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: ClipRRect(
                              borderRadius: prismCorners(context, 2),
                              child: SizedBox(
                                height: 4,
                                child: Stack(
                                  children: [
                                    Container(color: text2.withValues(alpha: 0.25)),
                                    FractionallySizedBox(widthFactor: (r['progress'] as num).toDouble().clamp(0, 1), child: Container(color: accent)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  () {
                    final t = (r['trailing'] as String?)?.isNotEmpty == true ? r['trailing'] as String : _time(l10n, r['time'], r['timeStyle'], now);
                    return t.isEmpty
                        ? const SizedBox.shrink()
                        : ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: dims.width * 0.42),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, text2)),
                            ),
                          );
                  }(),
                  if (r['checked'] is bool)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        r['checked'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18,
                        color: r['checked'] == true ? accent : text2,
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
      children.add(hasImage ? list : Expanded(child: ClipRect(child: OverflowBox(alignment: Alignment.topCenter, maxHeight: double.infinity, child: list))));
    } else if (!hasImage) {
      children.add(const Spacer());
    }
    final shownButtons = buttons.take(maxButtons).toList();
    if (shownButtons.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              for (var i = 0; i < shownButtons.length; i++)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.22), borderRadius: prismCorners(context, 12)),
                    alignment: Alignment.center,
                    child: Text(
                      small && '${shownButtons[i]['emoji'] ?? ''}'.isNotEmpty
                          ? '${shownButtons[i]['emoji']}'
                          : ['${shownButtons[i]['emoji'] ?? ''}', '${shownButtons[i]['label'] ?? ''}'].where((x) => x.isNotEmpty).join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(12, text, w: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: dims.width,
      height: dims.height,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: s.opacity,
              child: bg != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(bg, fit: BoxFit.cover, gaplessPlayback: true),
                        Container(color: Color(pal.bg1).withValues(alpha: s.imageDim)),
                      ],
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-math.cos(angle), -math.sin(angle)),
                          end: Alignment(math.cos(angle), math.sin(angle)),
                          colors: [Color(pal.bg1), Color(pal.bg2)],
                        ),
                      ),
                    ),
            ),
            if (s.borderWidth > 0)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: Color(pal.border), width: s.borderWidth),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(s.compact || small ? 10 : 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ],
        ),
      ),
    );
  }
}
