import 'atom_reader.dart';
import 'm4b_info.dart';
import 'text_decoding.dart';

/// A chapter marker before its end is known.
typedef ChapterMark = ({String title, Duration start});

/// Sanity limit: no real audiobook has this many chapters, but a corrupt
/// sample table could claim it.
const _maxChapters = 10000;

/// A chapter title sample is a few bytes; don't trust a bigger size.
const _maxSampleRead = 64 * 1024;

/// QuickTime chapters: a text track referenced via `tref/chap` from another
/// track. Each sample is one chapter (u16 length + text); its start time comes
/// from `stts` and its position in the file from `stsc` + `stsz` + `stco`/`co64`.
/// Returns `null` when the file has no such track.
Future<List<ChapterMark>?> readQuickTimeChapters(
  AtomReader atoms,
  Atom moov,
) async {
  final tracks = <int, Atom>{};
  final chapterTrackIds = <int>[];
  for (final trak in await atoms.childrenOf(moov)) {
    if (trak.type != 'trak') continue;
    final tkhd = await atoms.child(trak, 'tkhd');
    if (tkhd == null) continue;
    final cursor = ByteCursor(await atoms.data(tkhd));
    final version = cursor.u8();
    cursor.skip(3 + (version == 1 ? 16 : 8)); // flags, creation, modification
    tracks[cursor.u32()] = trak;

    final chap = await atoms.path(trak, ['tref', 'chap']);
    if (chap != null) {
      final ids = ByteCursor(await atoms.data(chap));
      while (ids.remaining >= 4) {
        chapterTrackIds.add(ids.u32());
      }
    }
  }

  for (final id in chapterTrackIds) {
    final trak = tracks[id];
    if (trak != null) return _readTextTrack(atoms, trak);
  }
  return null;
}

Future<List<ChapterMark>?> _readTextTrack(AtomReader atoms, Atom trak) async {
  final mdhd = await atoms.path(trak, ['mdia', 'mdhd']);
  final stbl = await atoms.path(trak, ['mdia', 'minf', 'stbl']);
  if (mdhd == null || stbl == null) return null;

  final mdhdCursor = ByteCursor(await atoms.data(mdhd));
  final version = mdhdCursor.u8();
  mdhdCursor.skip(3 + (version == 1 ? 16 : 8));
  final timescale = mdhdCursor.u32();

  final tables = {
    for (final atom in await atoms.childrenOf(stbl)) atom.type: atom,
  };
  final stts = tables['stts'];
  final stsc = tables['stsc'];
  final stsz = tables['stsz'];
  final chunkOffsetsAtom = tables['co64'] ?? tables['stco'];
  if (stts == null || stsc == null || stsz == null) return null;
  if (chunkOffsetsAtom == null) return null;

  // Sample start times.
  final starts = <int>[];
  final sttsCursor = ByteCursor(await atoms.data(stts))..skip(4);
  var time = 0;
  for (var n = sttsCursor.u32(); n > 0; n--) {
    final count = sttsCursor.u32();
    final delta = sttsCursor.u32();
    for (var i = 0; i < count && starts.length < _maxChapters; i++) {
      starts.add(time);
      time += delta;
    }
  }

  // Sample sizes.
  final stszCursor = ByteCursor(await atoms.data(stsz))..skip(4);
  final constantSize = stszCursor.u32();
  final sampleCount = stszCursor.u32();
  if (sampleCount > _maxChapters) {
    throw M4bParseException('Too many chapter samples: $sampleCount');
  }
  final sizes = [
    for (var i = 0; i < sampleCount; i++)
      constantSize != 0 ? constantSize : stszCursor.u32(),
  ];

  // Chunk offsets.
  final is64 = chunkOffsetsAtom.type == 'co64';
  final chunkCursor = ByteCursor(await atoms.data(chunkOffsetsAtom))..skip(4);
  final chunkCount = chunkCursor.u32();
  if (chunkCount > _maxChapters) {
    throw M4bParseException('Too many chapter chunks: $chunkCount');
  }
  final chunkOffsets = [
    for (var i = 0; i < chunkCount; i++)
      is64 ? chunkCursor.u64() : chunkCursor.u32(),
  ];

  // Sample-to-chunk runs: (first chunk, 1-based; samples per chunk).
  final stscCursor = ByteCursor(await atoms.data(stsc))..skip(4);
  final runs = <(int, int)>[];
  for (var n = stscCursor.u32(); n > 0; n--) {
    final firstChunk = stscCursor.u32();
    final samplesPerChunk = stscCursor.u32();
    stscCursor.skip(4); // sample description index
    runs.add((firstChunk, samplesPerChunk));
  }

  // File offset of every sample.
  final offsets = <int>[];
  var run = 0;
  for (var chunk = 0; chunk < chunkCount; chunk++) {
    while (run + 1 < runs.length && runs[run + 1].$1 - 1 <= chunk) {
      run++;
    }
    final perChunk = runs.isEmpty ? 1 : runs[run].$2;
    var pos = chunkOffsets[chunk];
    for (var s = 0; s < perChunk && offsets.length < sampleCount; s++) {
      offsets.add(pos);
      pos += sizes[offsets.length - 1];
    }
  }

  final count = [starts.length, offsets.length].reduce((a, b) => a < b ? a : b);
  final marks = <ChapterMark>[];
  for (var i = 0; i < count; i++) {
    final readSize = sizes[i] < _maxSampleRead ? sizes[i] : _maxSampleRead;
    final sample = ByteCursor(await atoms.read(offsets[i], readSize));
    final textLength = sample.u16();
    final title = decodeText(
      sample.bytes(textLength.clamp(0, sample.remaining)),
    );
    marks.add((title: title, start: ticksToDuration(starts[i], timescale)));
  }
  return marks;
}

/// Nero chapters: `moov/udta/chpl`, with starts in 100 ns units.
/// Returns `null` when the file has no such atom.
Future<List<ChapterMark>?> readNeroChapters(AtomReader atoms, Atom moov) async {
  final chpl = await atoms.path(moov, ['udta', 'chpl']);
  if (chpl == null) return null;

  final cursor = ByteCursor(await atoms.data(chpl));
  final version = cursor.u8();
  cursor.skip(3); // flags
  if (version == 1) cursor.skip(4); // reserved (as read by ffmpeg)
  final count = cursor.u8();
  final marks = <ChapterMark>[];
  for (var i = 0; i < count; i++) {
    final start = cursor.u64();
    final title = decodeText(cursor.bytes(cursor.u8()));
    marks.add((title: title, start: Duration(microseconds: start ~/ 10)));
  }
  return marks;
}

/// Sorts [marks] by start and turns them into chapters that tile the book:
/// each one ends where the next starts, and the last one at [total].
List<Chapter> buildChapters(List<ChapterMark> marks, Duration total) {
  final sorted = [...marks]..sort((a, b) => a.start.compareTo(b.start));
  return [
    for (var i = 0; i < sorted.length; i++)
      Chapter(
        title: sorted[i].title,
        start: sorted[i].start,
        end: _later(
          sorted[i].start,
          i + 1 < sorted.length ? sorted[i + 1].start : total,
        ),
      ),
  ];
}

// Guards against a corrupt duration shorter than the last chapter's start.
Duration _later(Duration a, Duration b) => a > b ? a : b;
