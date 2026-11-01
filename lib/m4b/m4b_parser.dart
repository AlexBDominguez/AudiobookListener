import 'atom_reader.dart';
import 'buffered_byte_reader.dart';
import 'byte_reader.dart';
import 'chapter_parser.dart';
import 'm4b_info.dart';
import 'metadata_parser.dart';

/// Reads duration, metadata, cover and chapters from an .m4b file.
class M4bParser {
  const M4bParser({this.narratorKeys = const ['©nrt', '©wrt']});

  /// `ilst` keys tried, in order, for the narrator. Tools disagree on where
  /// to put it; `©wrt` (composer) is the most common.
  final List<String> narratorKeys;

  /// Parses [reader]. Throws [M4bParseException] if the file has no usable
  /// `moov`/`mvhd`. Broken metadata or chapters are tolerated: they come back
  /// empty, and a book without chapters gets a single one titled after the
  /// book (or [fallbackTitle] when it has no title either).
  Future<M4bInfo> parse(ByteReader reader, {String fallbackTitle = ''}) async {
    final atoms = AtomReader(
      reader is BufferedByteReader ? reader : BufferedByteReader(reader),
    );

    Atom? moov;
    for (final atom in await atoms.children(0, atoms.length)) {
      if (atom.type == 'moov') moov = atom;
    }
    if (moov == null) throw const M4bParseException('No moov atom');

    final mvhd = await atoms.child(moov, 'mvhd');
    if (mvhd == null) throw const M4bParseException('No mvhd atom');
    final duration = await _readDuration(atoms, mvhd);

    var metadata = const Metadata();
    try {
      metadata = await parseMetadata(atoms, moov, narratorKeys: narratorKeys);
    } on M4bParseException {
      // Keep the book playable without its tags.
    }

    final marks = await _readChapters(atoms, moov);
    final chapters = marks == null || marks.isEmpty
        ? [
            Chapter(
              title: metadata.title ?? fallbackTitle,
              start: Duration.zero,
              end: duration,
            ),
          ]
        : buildChapters(marks, duration);

    return M4bInfo(
      duration: duration,
      chapters: chapters,
      title: metadata.title,
      author: metadata.author,
      narrator: metadata.narrator,
      year: metadata.year,
      description: metadata.description,
      genre: metadata.genre,
      cover: metadata.cover,
    );
  }

  Future<Duration> _readDuration(AtomReader atoms, Atom mvhd) async {
    final cursor = ByteCursor(await atoms.data(mvhd));
    final version = cursor.u8();
    cursor.skip(3); // flags
    if (version == 1) {
      cursor.skip(16); // creation, modification
      final timescale = cursor.u32();
      return ticksToDuration(cursor.u64(), timescale);
    }
    cursor.skip(8);
    final timescale = cursor.u32();
    return ticksToDuration(cursor.u32(), timescale);
  }

  /// QuickTime chapters win over Nero ones; if one format is broken the other
  /// is still tried.
  Future<List<ChapterMark>?> _readChapters(AtomReader atoms, Atom moov) async {
    for (final read in [readQuickTimeChapters, readNeroChapters]) {
      try {
        final marks = await read(atoms, moov);
        if (marks != null && marks.isNotEmpty) return marks;
      } on M4bParseException {
        continue;
      }
    }
    return null;
  }
}
