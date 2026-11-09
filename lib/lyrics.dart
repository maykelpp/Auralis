class LyricLine {
  const LyricLine(this.time, this.text);
  final Duration time;
  final String text;
}

class LrcLyrics {
  static final _stamp = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
  static List<LyricLine> parse(String source) {
    final result = <LyricLine>[];
    for (final line in source.split(RegExp(r'\r?\n'))) {
      final matches = _stamp.allMatches(line).toList();
      if (matches.isEmpty) continue;
      final text = line.substring(matches.last.end).trim();
      for (final match in matches) {
        final minutes = int.tryParse(match.group(1)!) ?? 0;
        final seconds = int.tryParse(match.group(2)!) ?? 0;
        final fraction = (match.group(3) ?? '0').padRight(3, '0');
        final millis = int.tryParse(fraction) ?? 0;
        result.add(LyricLine(
          Duration(minutes: minutes, seconds: seconds, milliseconds: millis), text));
      }
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  static int activeIndex(List<LyricLine> lines, Duration position) {
    var index = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= position) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }
}
