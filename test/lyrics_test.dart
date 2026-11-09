import 'package:flutter_test/flutter_test.dart';
import 'package:auralis_player/lyrics.dart';

void main() {
  test('parses multiple LRC timestamps and sorts them', () {
    final lines = LrcLyrics.parse('[00:02.50]Second\n[00:01.00]First');
    expect(lines.length, 2);
    expect(lines.first.text, 'First');
    expect(lines.first.time.inMilliseconds, 1000);
    expect(lines.last.text, 'Second');
    expect(lines.last.time.inMilliseconds, 2500);
  });

  test('finds the active lyric line', () {
    final lines = LrcLyrics.parse('[00:01.00]One\n[00:03.00]Two');
    expect(LrcLyrics.activeIndex(lines, const Duration(milliseconds: 500)), -1);
    expect(LrcLyrics.activeIndex(lines, const Duration(seconds: 2)), 0);
    expect(LrcLyrics.activeIndex(lines, const Duration(seconds: 4)), 1);
  });
}
