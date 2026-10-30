/// Formats a [Duration] as `m:ss` or `h:mm:ss`. Negative values get a
/// leading `-` (used for "remaining" times).
String formatDuration(Duration d) {
  final negative = d.isNegative;
  final abs = d.abs();
  final hours = abs.inHours;
  final minutes = abs.inMinutes.remainder(60);
  final seconds = abs.inSeconds.remainder(60);
  final ss = seconds.toString().padLeft(2, '0');
  final body = hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$ss'
      : '$minutes:$ss';
  return negative ? '-$body' : body;
}
