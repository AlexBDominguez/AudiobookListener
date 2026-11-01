import 'dart:convert';
import 'dart:typed_data';

import 'package:audiobook_listener/m4b/m4b.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/atom_builder.dart';

Future<M4bInfo> _parse(
  Uint8List bytes, {
  M4bParser parser = const M4bParser(),
  String fallbackTitle = '',
}) => parser.parse(MemoryByteReader(bytes), fallbackTitle: fallbackTitle);

const _marks = <Mark>[
  (title: 'Uno', start: Duration.zero),
  (title: 'Dos', start: Duration(minutes: 3)),
  (title: 'Tres', start: Duration(minutes: 7, milliseconds: 500)),
];

const _expected = [
  Chapter(title: 'Uno', start: Duration.zero, end: Duration(minutes: 3)),
  Chapter(
    title: 'Dos',
    start: Duration(minutes: 3),
    end: Duration(minutes: 7, milliseconds: 500),
  ),
  Chapter(
    title: 'Tres',
    start: Duration(minutes: 7, milliseconds: 500),
    end: Duration(minutes: 10),
  ),
];

final _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3];

void main() {
  group('chapters', () {
    test('QuickTime chapter track', () async {
      final info = await _parse(buildM4b(quickTimeChapters: _marks));
      expect(info.chapters, _expected);
    });

    test('QuickTime with every sample in a single chunk (stsc)', () async {
      final info = await _parse(
        buildM4b(quickTimeChapters: _marks, oneChunk: true),
      );
      expect(info.chapters, _expected);
    });

    test('co64, 64-bit atom size and mvhd version 1', () async {
      final info = await _parse(
        buildM4b(
          quickTimeChapters: _marks,
          co64: true,
          largeMdat: true,
          mvhdVersion1: true,
        ),
      );
      expect(info.duration, const Duration(minutes: 10));
      expect(info.chapters, _expected);
    });

    test('Nero chpl only', () async {
      final info = await _parse(buildM4b(neroChapters: _marks));
      expect(info.chapters, _expected);
    });

    test('prefers QuickTime over Nero when both exist', () async {
      final info = await _parse(
        buildM4b(
          quickTimeChapters: _marks,
          neroChapters: const [(title: 'Nero', start: Duration.zero)],
        ),
      );
      expect(info.chapters, _expected);
    });

    test('sorts chapters by start', () async {
      final info = await _parse(
        buildM4b(neroChapters: _marks.reversed.toList()),
      );
      expect(info.chapters, _expected);
    });

    test('no chapters: one chapter titled after the book', () async {
      final info = await _parse(
        buildM4b(tags: [tag('©nam', utf8.encode('Mi libro'))]),
        fallbackTitle: 'archivo',
      );
      expect(info.chapters, const [
        Chapter(
          title: 'Mi libro',
          start: Duration.zero,
          end: Duration(minutes: 10),
        ),
      ]);
    });

    test('no chapters nor title: uses the fallback title', () async {
      final info = await _parse(buildM4b(), fallbackTitle: 'archivo');
      expect(info.chapters.single.title, 'archivo');
    });
  });

  group('metadata', () {
    test('prefers ©nrt over ©wrt for the narrator by default', () async {
      final info = await _parse(
        buildM4b(
          tags: [
            tag('©wrt', utf8.encode('Compositor')),
            tag('©nrt', utf8.encode('Narradora')),
          ],
        ),
      );
      expect(info.narrator, 'Narradora');
    });

    test('narrator keys are configurable', () async {
      final info = await _parse(
        buildM4b(
          tags: [
            tag('©wrt', utf8.encode('Compositor')),
            tag('©nrt', utf8.encode('Narradora')),
          ],
        ),
        parser: const M4bParser(narratorKeys: ['©wrt']),
      );
      expect(info.narrator, 'Compositor');
    });

    test('falls back to aART and ©cmt', () async {
      final info = await _parse(
        buildM4b(
          tags: [
            tag('aART', utf8.encode('Autor del álbum')),
            tag('©cmt', utf8.encode('Comentario')),
          ],
        ),
      );
      expect(info.author, 'Autor del álbum');
      expect(info.description, 'Comentario');
    });

    test('reads Latin-1 text that is not valid UTF-8', () async {
      final info = await _parse(
        buildM4b(tags: [tag('©nam', latin1.encode('Canción'))]),
      );
      expect(info.title, 'Canción');
    });

    test('reads UTF-16 text (data type 2)', () async {
      final utf16be = [
        for (final unit in 'Ñu'.codeUnits) ...[unit >> 8, unit & 0xFF],
      ];
      final info = await _parse(
        buildM4b(tags: [tag('©nam', utf16be, type: 2)]),
      );
      expect(info.title, 'Ñu');
    });

    test('reads a PNG cover', () async {
      final info = await _parse(buildM4b(tags: [tag('covr', _png, type: 14)]));
      expect(info.cover!.format, CoverFormat.png);
      expect(info.cover!.bytes, _png);
    });

    test('detects the cover format when the type is missing', () async {
      final info = await _parse(buildM4b(tags: [tag('covr', _png, type: 0)]));
      expect(info.cover!.format, CoverFormat.png);
    });
  });

  group('robustness', () {
    test('does not read the audio data', () async {
      final bytes = buildM4b(
        quickTimeChapters: _marks,
        mdatPadding: 4 * 1024 * 1024,
      );
      final counting = CountingByteReader(MemoryByteReader(bytes));
      await const M4bParser().parse(counting);
      expect(counting.bytesRead, lessThan(256 * 1024));
    });

    test('a truncated file still yields duration and chapters', () async {
      final bytes = buildM4b(
        quickTimeChapters: _marks,
        tags: [tag('©nam', utf8.encode('Mi libro'))],
      );
      // Cuts into udta/meta, at the end of moov.
      final info = await _parse(
        Uint8List.sublistView(bytes, 0, bytes.length - 10),
      );
      expect(info.duration, const Duration(minutes: 10));
      expect(info.chapters, _expected);
    });

    test('a broken chapter track falls back to Nero chapters', () async {
      final bytes = buildM4b(
        quickTimeChapters: _marks,
        neroChapters: const [(title: 'Nero', start: Duration.zero)],
      );
      // Corrupt the stts entry count so the table runs out of data.
      final stts = _indexOf(bytes, fourcc('stts'));
      ByteData.sublistView(bytes).setUint32(stts + 8, 0xFFFF);
      final info = await _parse(bytes);
      expect(info.chapters.single.title, 'Nero');
    });

    test('throws M4bParseException for a non-MP4 file', () async {
      final notMp4 = Uint8List.fromList(utf8.encode('esto no es un m4b ' * 20));
      expect(_parse(notMp4), throwsA(isA<M4bParseException>()));
    });

    test('throws M4bParseException for an empty file', () async {
      expect(_parse(Uint8List(0)), throwsA(isA<M4bParseException>()));
    });
  });
}

int _indexOf(Uint8List haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length && match; j++) {
      match = haystack[i + j] == needle[j];
    }
    if (match) return i;
  }
  throw StateError('not found');
}
