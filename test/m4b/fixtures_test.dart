import 'package:audiobook_listener/core/file_byte_reader.dart';
import 'package:audiobook_listener/m4b/atom_reader.dart';
import 'package:audiobook_listener/m4b/chapter_parser.dart';
import 'package:audiobook_listener/m4b/m4b.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/atom_builder.dart';

// Expected values come from `ffprobe -show_chapters -show_format` on the
// fixtures (see test/fixtures/generate_fixtures.ps1).
const _withChapters = 'test/fixtures/with_chapters.m4b';
const _noChapters = 'test/fixtures/no_chapters.m4b';

Future<T> _withReader<T>(String path, Future<T> Function(ByteReader) f) async {
  final reader = await FileByteReader.open(path);
  try {
    return await f(reader);
  } finally {
    await reader.close();
  }
}

void main() {
  group('with_chapters.m4b', () {
    late M4bInfo info;

    setUpAll(() async {
      info = await _withReader(_withChapters, const M4bParser().parse);
    });

    test('reads duration from mvhd', () {
      expect(info.duration, const Duration(seconds: 90));
    });

    test('reads metadata', () {
      expect(info.title, 'Libro de prueba');
      expect(info.author, 'Autora Ejemplo');
      expect(info.narrator, 'Narrador Ejemplo');
      expect(info.year, '2024');
      expect(info.genre, 'Audiolibro');
      expect(
        info.description,
        'Descripción con acentos: canción, pingüino, ñandú.',
      );
    });

    test('reads the JPEG cover', () {
      final cover = info.cover!;
      expect(cover.format, CoverFormat.jpeg);
      expect(cover.bytes.length, 247);
      expect(cover.bytes.sublist(0, 2), [0xFF, 0xD8]);
    });

    test('reads the three chapters', () {
      expect(info.chapters, const [
        Chapter(
          title: 'Capítulo uno',
          start: Duration.zero,
          end: Duration(seconds: 30),
        ),
        Chapter(
          title: 'Capítulo dos: el viaje',
          start: Duration(seconds: 30),
          end: Duration(seconds: 65),
        ),
        Chapter(
          title: 'Epílogo',
          start: Duration(seconds: 65),
          end: Duration(seconds: 90),
        ),
      ]);
    });

    test('QuickTime and Nero chapters agree', () async {
      final (qt, nero) = await _withReader(_withChapters, (reader) async {
        final atoms = AtomReader(BufferedByteReader(reader));
        final moov = (await atoms.children(
          0,
          atoms.length,
        )).firstWhere((a) => a.type == 'moov');
        return (
          await readQuickTimeChapters(atoms, moov),
          await readNeroChapters(atoms, moov),
        );
      });
      expect(qt, hasLength(3));
      expect(nero, qt);
    });

    test('skips mdat: moov is at the end of the file', () async {
      final counting = await _withReader(_withChapters, (reader) async {
        final counting = CountingByteReader(reader);
        await const M4bParser().parse(counting);
        return counting;
      });
      expect(counting.bytesRead, lessThan(counting.length ~/ 2));
    });
  });

  group('no_chapters.m4b', () {
    late M4bInfo info;

    setUpAll(() async {
      info = await _withReader(
        _noChapters,
        (r) => const M4bParser().parse(r, fallbackTitle: 'no_chapters'),
      );
    });

    test('reads duration', () {
      expect(info.duration, const Duration(seconds: 30));
    });

    test('has no metadata nor cover', () {
      expect(info.title, isNull);
      expect(info.author, isNull);
      expect(info.narrator, isNull);
      expect(info.cover, isNull);
    });

    test('gets a single chapter spanning the whole book', () {
      expect(info.chapters, const [
        Chapter(
          title: 'no_chapters',
          start: Duration.zero,
          end: Duration(seconds: 30),
        ),
      ]);
    });
  });
}
