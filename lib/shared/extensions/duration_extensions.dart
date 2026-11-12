extension DurationFormatting on Duration {
  /// Format as M:SS for voice/audio display (e.g., "1:05", "0:30").
  String toVoiceFormat() {
    final totalSeconds = inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Returns a short formatted string like "1h 45m", "23m", or "45s".
  String toShortString() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    if (minutes > 0) {
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    }
    return '${seconds}s';
  }

  /// Exact to the second, for live timers: "2:05:09", "12:03", "0:42".
  /// Hours are not wrapped into days, so long sessions read naturally.
  String toClockString() {
    final total = inSeconds.abs();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final sign = isNegative ? '-' : '';
    if (h > 0) {
      return '$sign$h:${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '$sign$m:${s.toString().padLeft(2, '0')}';
  }

  /// Exact to the second in words: "1h 45m 03s", "12m 07s", "42s".
  String toExactString() {
    final total = inSeconds.abs();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m '
          '${s.toString().padLeft(2, '0')}s';
    }
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  /// Returns a rounded string without seconds (unless under 1 minute).
  /// e.g. "2d 5h", "2h 15m", "45m", "30s".
  String toRoundedString() {
    final days = inDays;
    final hours = inHours % 24;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    if (days > 0) {
      return '${days}d ${hours}h';
    }
    if (inHours > 0) {
      return minutes > 0 ? '${inHours}h ${minutes}m' : '${inHours}h';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return '${seconds}s';
  }

  /// Returns a long formatted string like "1 hour, 45 minutes".
  String toLongString() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    final parts = <String>[];
    if (hours > 0) {
      parts.add('$hours ${hours == 1 ? 'hour' : 'hours'}');
    }
    if (minutes > 0) {
      parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
    }
    if (parts.isEmpty) {
      parts.add('$seconds ${seconds == 1 ? 'second' : 'seconds'}');
    }
    return parts.join(', ');
  }
}
