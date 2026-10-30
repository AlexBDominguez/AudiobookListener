import 'package:audiobook_listener/core/duration_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats under an hour as m:ss', () {
    expect(formatDuration(Duration.zero), '0:00');
    expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
  });

  test('formats an hour or more as h:mm:ss', () {
    expect(
      formatDuration(const Duration(hours: 12, minutes: 5, seconds: 9)),
      '12:05:09',
    );
  });

  test('prefixes negative durations with a minus sign', () {
    expect(formatDuration(const Duration(minutes: -1, seconds: -30)), '-1:30');
  });

  test('truncates sub-second precision', () {
    expect(
      formatDuration(const Duration(seconds: 59, milliseconds: 999)),
      '0:59',
    );
  });
}
