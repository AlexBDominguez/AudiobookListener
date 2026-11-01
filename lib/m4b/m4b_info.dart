import 'dart:typed_data';

/// Everything the app needs from an .m4b file.
class M4bInfo {
  const M4bInfo({
    required this.duration,
    required this.chapters,
    this.title,
    this.author,
    this.narrator,
    this.year,
    this.description,
    this.genre,
    this.cover,
  });

  final Duration duration;

  /// Sorted by [Chapter.start]; never empty.
  final List<Chapter> chapters;

  final String? title;
  final String? author;
  final String? narrator;
  final String? year;
  final String? description;
  final String? genre;
  final CoverImage? cover;
}

class Chapter {
  const Chapter({required this.title, required this.start, required this.end});

  final String title;
  final Duration start;

  /// Start of the next chapter, or the book duration for the last one.
  final Duration end;

  Duration get duration => end - start;

  @override
  bool operator ==(Object other) =>
      other is Chapter &&
      other.title == title &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(title, start, end);

  @override
  String toString() => 'Chapter($title, $start - $end)';
}

enum CoverFormat { jpeg, png }

class CoverImage {
  const CoverImage(this.bytes, this.format);

  final Uint8List bytes;
  final CoverFormat format;
}

/// The file is not a readable MP4/m4b (no `moov`, no `mvhd`, garbage, ...).
class M4bParseException implements Exception {
  const M4bParseException(this.message);

  final String message;

  @override
  String toString() => 'M4bParseException: $message';
}
