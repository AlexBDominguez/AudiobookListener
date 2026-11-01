import 'dart:convert';
import 'dart:typed_data';

import 'package:audiobook_listener/m4b/m4b.dart';

/// Big-endian byte writer for building atoms by hand.
class Bytes {
  final _b = BytesBuilder(copy: false);

  int get length => _b.length;

  void u8(int v) => _b.addByte(v & 0xFF);
  void u16(int v) => _b.add([(v >> 8) & 0xFF, v & 0xFF]);
  void u32(int v) =>
      _b.add((ByteData(4)..setUint32(0, v)).buffer.asUint8List());
  void u64(int v) =>
      _b.add((ByteData(8)..setUint64(0, v)).buffer.asUint8List());
  void add(List<int> bytes) => _b.add(bytes);
  void zeros(int n) => _b.add(Uint8List(n));

  Uint8List take() => _b.takeBytes();
}

List<int> fourcc(String type) => latin1.encode(type);

Uint8List atom(String type, List<int> payload) =>
    (Bytes()
          ..u32(8 + payload.length)
          ..add(fourcc(type))
          ..add(payload))
        .take();

/// Atom with a 64-bit size (`size == 1`).
Uint8List atom64(String type, List<int> payload) =>
    (Bytes()
          ..u32(1)
          ..add(fourcc(type))
          ..u64(16 + payload.length)
          ..add(payload))
        .take();

Uint8List fullAtom(
  String type,
  List<int> payload, {
  int version = 0,
  int flags = 0,
}) => atom(type, [
  version,
  (flags >> 16) & 0xFF,
  (flags >> 8) & 0xFF,
  flags & 0xFF,
  ...payload,
]);

Uint8List concat(List<List<int>> parts) =>
    Uint8List.fromList([for (final p in parts) ...p]);

/// iTunes `ilst` item: `key > data(type, locale, value)`.
Uint8List tag(String key, List<int> value, {int type = 1}) => atom(
  key,
  atom(
    'data',
    (Bytes()
          ..u32(type)
          ..u32(0)
          ..add(value))
        .take(),
  ),
);

typedef Mark = ({String title, Duration start});

/// Builds a minimal but structurally real .m4b: `ftyp`, `mdat` (padding plus
/// the chapter text samples) and `moov` at the end, like ffmpeg writes it.
Uint8List buildM4b({
  Duration duration = const Duration(minutes: 10),
  int timescale = 1000,
  List<Uint8List> tags = const [],
  List<Mark>? quickTimeChapters,
  List<Mark>? neroChapters,
  bool co64 = false,
  bool largeMdat = false,
  bool oneChunk = false,
  bool mvhdVersion1 = false,
  int mdatPadding = 256,
}) {
  int ticks(Duration d) => d.inMicroseconds * timescale ~/ 1000000;

  final ftyp = atom('ftyp', [...fourcc('M4A '), 0, 0, 2, 0, ...fourcc('M4A ')]);

  // Chapter samples: u16 length + UTF-8 text + `encd` atom (as ffmpeg does).
  final samples = [
    for (final c in quickTimeChapters ?? const <Mark>[])
      concat([
        (Bytes()..u16(utf8.encode(c.title).length)).take(),
        utf8.encode(c.title),
        atom('encd', [0, 0, 1, 0]),
      ]),
  ];
  final mdatHeader = largeMdat ? 16 : 8;
  final firstSample = ftyp.length + mdatHeader + mdatPadding;
  final mdatPayload = concat([Uint8List(mdatPadding), ...samples]);
  final mdat = largeMdat
      ? atom64('mdat', mdatPayload)
      : atom('mdat', mdatPayload);

  final sampleOffsets = <int>[];
  var pos = firstSample;
  for (final s in samples) {
    sampleOffsets.add(pos);
    pos += s.length;
  }

  final mvhd = mvhdVersion1
      ? fullAtom(
          'mvhd',
          version: 1,
          (Bytes()
                ..u64(0)
                ..u64(0)
                ..u32(timescale)
                ..u64(ticks(duration))
                ..zeros(80))
              .take(),
        )
      : fullAtom(
          'mvhd',
          (Bytes()
                ..u32(0)
                ..u32(0)
                ..u32(timescale)
                ..u32(ticks(duration))
                ..zeros(80))
              .take(),
        );

  Uint8List tkhd(int id) => fullAtom(
    'tkhd',
    (Bytes()
          ..u32(0)
          ..u32(0)
          ..u32(id)
          ..u32(0)
          ..u32(ticks(duration))
          ..zeros(60))
        .take(),
  );

  Uint8List mdhd() => fullAtom(
    'mdhd',
    (Bytes()
          ..u32(0)
          ..u32(0)
          ..u32(timescale)
          ..u32(ticks(duration))
          ..u16(0x55C4)
          ..u16(0))
        .take(),
  );

  Uint8List hdlr(String handler) =>
      fullAtom('hdlr', [0, 0, 0, 0, ...fourcc(handler), ...Uint8List(12), 0]);

  final hasQt = quickTimeChapters != null;
  final audioTrak = atom(
    'trak',
    concat([
      tkhd(1),
      if (hasQt) atom('tref', atom('chap', (Bytes()..u32(2)).take())),
      atom('mdia', concat([mdhd(), hdlr('soun')])),
    ]),
  );

  Uint8List? textTrak;
  if (hasQt) {
    final marks = quickTimeChapters;
    final stts = Bytes()..u32(marks.length);
    for (var i = 0; i < marks.length; i++) {
      final next = i + 1 < marks.length ? marks[i + 1].start : duration;
      stts
        ..u32(1)
        ..u32(ticks(next) - ticks(marks[i].start));
    }
    final stsz = Bytes()
      ..u32(0)
      ..u32(samples.length);
    for (final s in samples) {
      stsz.u32(s.length);
    }
    final chunkOffsets = oneChunk ? [sampleOffsets.first] : sampleOffsets;
    final stsc = Bytes()
      ..u32(1)
      ..u32(1)
      ..u32(oneChunk ? samples.length : 1)
      ..u32(1);
    final stco = Bytes()..u32(chunkOffsets.length);
    for (final o in chunkOffsets) {
      co64 ? stco.u64(o) : stco.u32(o);
    }
    textTrak = atom(
      'trak',
      concat([
        tkhd(2),
        atom(
          'mdia',
          concat([
            mdhd(),
            hdlr('text'),
            atom(
              'minf',
              atom(
                'stbl',
                concat([
                  fullAtom('stts', stts.take()),
                  fullAtom('stsc', stsc.take()),
                  fullAtom('stsz', stsz.take()),
                  fullAtom(co64 ? 'co64' : 'stco', stco.take()),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Uint8List? chpl;
  if (neroChapters != null) {
    final b = Bytes()
      ..u32(0) // reserved (version 1)
      ..u8(neroChapters.length);
    for (final c in neroChapters) {
      final title = utf8.encode(c.title);
      b
        ..u64(c.start.inMicroseconds * 10)
        ..u8(title.length)
        ..add(title);
    }
    chpl = fullAtom('chpl', version: 1, b.take());
  }

  final udta = atom(
    'udta',
    concat([
      if (tags.isNotEmpty)
        fullAtom('meta', concat([hdlr('mdir'), atom('ilst', concat(tags))])),
      ?chpl,
    ]),
  );

  final moov = atom('moov', concat([mvhd, audioTrak, ?textTrak, udta]));
  return concat([ftyp, mdat, moov]);
}

/// Counts what the parser asks from the underlying reader.
class CountingByteReader implements ByteReader {
  CountingByteReader(this._inner);

  final ByteReader _inner;
  int calls = 0;
  int bytesRead = 0;

  @override
  int get length => _inner.length;

  @override
  Future<Uint8List> read(int offset, int count) async {
    final bytes = await _inner.read(offset, count);
    calls++;
    bytesRead += bytes.length;
    return bytes;
  }
}
