import 'package:flutter/foundation.dart';

import 'package:prism_plurality/domain/models/fronting_session.dart';
import 'package:prism_plurality/domain/models/member.dart';
import 'package:prism_plurality/domain/models/mood_entry.dart';
import 'package:prism_plurality/features/fronting_notification/models/fronting_notification_settings.dart';

/// Localised words the snapshot needs (passed in so this stays pure).
@immutable
class FnStrings {
  const FnStrings({
    required this.nobodyFronting,
    required this.frontingLine,
    required this.cofrontingLine,
    required this.sinceLine,
    required this.asleepLine,
    required this.statusLine,
    required this.moodLine,
    required this.emotionsLine,
    required this.locationLine,
    required this.workingLine,
    required this.workoutLine,
    required this.studyLine,
    required this.publicTitle,
    required this.publicText,
    required this.actionLabels,
    required this.moodLabel,
    required this.formatTime,
  });

  final String nobodyFronting;
  final String Function(String names) frontingLine;
  final String Function(String names) cofrontingLine;
  final String Function(String time) sinceLine;
  final String Function(String time) asleepLine;
  final String Function(String status) statusLine;
  final String Function(String label, int level) moodLine;
  final String Function(String list) emotionsLine;
  final String Function(String place) locationLine;
  final String Function(String job) workingLine;
  final String Function(String activity) workoutLine;
  final String Function(String subject) studyLine;
  final String publicTitle;
  final String publicText;
  final Map<String, String> actionLabels;
  final String Function(int level) moodLabel;
  final String Function(DateTime t) formatTime;
}

/// What is happening right now, gathered from Prism's own data.
@immutable
class FnInputs {
  const FnInputs({
    required this.sessions,
    required this.members,
    this.sleep,
    this.latestMood,
    this.locationName,
    this.workJob,
    this.liveWorkout,
    this.liveStudy,
  });

  /// Active fronting sessions (not sleep).
  final List<FrontingSession> sessions;
  final Map<String, Member> members;
  final FrontingSession? sleep;
  final MoodEntry? latestMood;
  final String? locationName;
  final String? workJob;
  final String? liveWorkout;
  final String? liveStudy;
}

/// The notification content, before icons are rendered.
@immutable
class FnSnapshot {
  const FnSnapshot({
    required this.hidden,
    required this.title,
    required this.text,
    required this.lines,
    this.subText,
    this.chronometerBase,
    this.primaryMemberId,
    this.iconEmoji,
    this.accentColor,
    this.backgroundColor,
    this.textColor,
    required this.actions,
    required this.publicTitle,
    required this.publicText,
  });

  /// True when the notification should be removed (nobody fronting and
  /// the user chose to hide it then).
  final bool hidden;
  final String title;
  final String text;
  final List<String> lines;
  final String? subText;
  final DateTime? chronometerBase;
  final String? primaryMemberId;
  final String? iconEmoji;
  final int? accentColor;
  final int? backgroundColor;
  final int? textColor;
  final List<(String, String)> actions;
  final String publicTitle;
  final String publicText;

  Map<String, Object?> toComparable() => {
    'hidden': hidden,
    'title': title,
    'text': text,
    'lines': lines.join('\n'),
    'sub': subText,
    'base': chronometerBase?.millisecondsSinceEpoch,
    'primary': primaryMemberId,
    'emoji': iconEmoji,
    'accent': accentColor,
    'bg': backgroundColor,
    'fg': textColor,
    'actions': actions.map((a) => a.$1).join(','),
    'public': '$publicTitle|$publicText',
  };
}

String _cleanEmotion(String raw) {
  final at = raw.indexOf('@');
  final key = at < 0 ? raw : raw.substring(0, at);
  return key.replaceAll('_', ' ');
}

String fillTemplate(String template, Map<String, String> values) => template
    .replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => values[m[1]] ?? '')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();

/// Builds the notification content from [settings] and current data.
FnSnapshot buildFrontingSnapshot(
  FrontingNotificationSettings settings,
  FnInputs input,
  FnStrings s,
  DateTime now,
) {
  final sessions = [
    for (final x in input.sessions)
      if (x.memberId != null && input.members.containsKey(x.memberId)) x,
  ]..sort((a, b) => b.startTime.compareTo(a.startTime));
  final fronters = [for (final x in sessions) input.members[x.memberId]!];
  final primary = fronters.isEmpty ? null : fronters.first;
  final style = primary == null ? null : settings.memberStyles[primary.id];
  final showPronouns = settings.info.contains(FnInfo.pronouns);
  String nameOf(Member m) {
    final p = m.pronouns?.trim();
    return showPronouns && p != null && p.isNotEmpty
        ? '${m.name} ($p)'
        : m.name;
  }

  final mood =
      input.latestMood != null &&
          now.difference(input.latestMood!.recordedAt) <=
              Duration(hours: settings.moodMaxAgeHours)
      ? input.latestMood
      : null;
  final values = {
    'fronters': fronters.map((m) => m.name).join(', '),
    'first': primary?.name ?? '',
    'cofronters': fronters.skip(1).map((m) => m.name).join(', '),
    'count': '${fronters.length}',
    'mood': mood == null ? '' : s.moodLabel(mood.mood),
    'location': input.locationName ?? '',
  };
  final actions = [
    for (final a in settings.actions)
      if (s.actionLabels[a] != null) (a, s.actionLabels[a]!),
  ];

  if (fronters.isEmpty && input.sleep == null) {
    if (settings.whenEmpty == FnWhenEmpty.hide) {
      return FnSnapshot(
        hidden: true,
        title: '',
        text: '',
        lines: const [],
        actions: const [],
        publicTitle: '',
        publicText: '',
      );
    }
    final msg = settings.emptyMessage.trim().isEmpty
        ? s.nobodyFronting
        : settings.emptyMessage.trim();
    return FnSnapshot(
      hidden: false,
      title: msg,
      text: settings.customStatus.trim(),
      lines: [
        if (settings.info.contains(FnInfo.customStatus) &&
            settings.customStatus.trim().isNotEmpty)
          settings.customStatus.trim(),
        if (settings.info.contains(FnInfo.custom)) ...settings.customLines,
      ],
      iconEmoji: settings.iconEmoji,
      accentColor: settings.accentColor,
      backgroundColor: settings.backgroundColor,
      textColor: settings.textColor,
      actions: [
        for (final a in actions)
          if (a.$1 != FnAction.switchFronter) a,
      ],
      publicTitle: s.publicTitle,
      publicText: s.publicText,
    );
  }

  final earliest = sessions.isEmpty
      ? input.sleep?.startTime
      : sessions
            .map((x) => x.startTime)
            .reduce((a, b) => a.isBefore(b) ? a : b);
  final primaryStart = sessions.isEmpty
      ? input.sleep?.startTime
      : sessions.first.startTime;
  final lines = <String>[];
  for (final item in settings.info) {
    switch (item) {
      case FnInfo.fronters:
        if (fronters.isNotEmpty) {
          lines.add(
            s.frontingLine(
              settings.info.contains(FnInfo.cofronters)
                  ? nameOf(fronters.first)
                  : fronters.map(nameOf).join(', '),
            ),
          );
        }
      case FnInfo.cofronters:
        if (fronters.length > 1)
          lines.add(s.cofrontingLine(fronters.skip(1).map(nameOf).join(', ')));
      case FnInfo.duration:
        if (primaryStart != null)
          lines.add(s.sinceLine(s.formatTime(primaryStart)));
      case FnInfo.status:
        if (input.sleep != null) {
          lines.add(s.asleepLine(s.formatTime(input.sleep!.startTime)));
        } else {
          final notes = sessions.isEmpty ? null : sessions.first.notes?.trim();
          if (notes != null && notes.isNotEmpty) lines.add(s.statusLine(notes));
        }
      case FnInfo.customStatus:
        if (settings.customStatus.trim().isNotEmpty)
          lines.add(settings.customStatus.trim());
      case FnInfo.mood:
        if (mood != null)
          lines.add(s.moodLine(s.moodLabel(mood.mood), mood.mood));
      case FnInfo.emotions:
        if (mood != null && mood.emotions.isNotEmpty)
          lines.add(
            s.emotionsLine(mood.emotions.map(_cleanEmotion).take(5).join(', ')),
          );
      case FnInfo.location:
        if (input.locationName != null)
          lines.add(s.locationLine(input.locationName!));
      case FnInfo.activity:
        if (input.workJob != null) lines.add(s.workingLine(input.workJob!));
        if (input.liveWorkout != null)
          lines.add(s.workoutLine(input.liveWorkout!));
        if (input.liveStudy != null) lines.add(s.studyLine(input.liveStudy!));
      case FnInfo.custom:
        lines.addAll(settings.customLines.where((l) => l.trim().isNotEmpty));
    }
  }

  final titleTemplate = (style?.title?.trim().isNotEmpty ?? false)
      ? style!.title!
      : settings.titleTemplate;
  var title = fillTemplate(titleTemplate, values);
  if (title.isEmpty)
    title = fronters.isEmpty
        ? s.asleepLine(s.formatTime(input.sleep!.startTime))
        : values['fronters']!;
  final greetingTemplate = (style?.greeting?.trim().isNotEmpty ?? false)
      ? style!.greeting!
      : settings.greeting;
  final greeting = fillTemplate(greetingTemplate, values);
  final text = greeting.isNotEmpty
      ? greeting
      : (lines.where((l) => !l.startsWith(s.frontingLine(''))).firstOrNull ??
            (lines.isEmpty ? '' : lines.first));
  return FnSnapshot(
    hidden: false,
    title: title,
    text: text,
    lines: lines,
    subText: fronters.length > 1 ? '${fronters.length}' : null,
    chronometerBase: settings.info.contains(FnInfo.duration)
        ? (primaryStart ?? earliest)
        : null,
    primaryMemberId: primary?.id,
    iconEmoji:
        style?.emoji ??
        (settings.iconSource == FnIconSource.emoji
            ? settings.iconEmoji
            : primary?.emoji),
    accentColor: style?.accentColor ?? settings.accentColor,
    backgroundColor: style?.backgroundColor ?? settings.backgroundColor,
    textColor: style?.textColor ?? settings.textColor,
    actions: actions,
    publicTitle: s.publicTitle,
    publicText: s.publicText,
  );
}
