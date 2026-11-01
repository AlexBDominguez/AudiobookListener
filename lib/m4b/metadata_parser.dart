import 'dart:typed_data';

import 'atom_reader.dart';
import 'm4b_info.dart';
import 'text_decoding.dart';

/// Tags read from `moov/udta/meta/ilst`.
class Metadata {
  const Metadata({
    this.title,
    this.author,
    this.narrator,
    this.year,
    this.description,
    this.genre,
    this.cover,
  });

  final String? title;
  final String? author;
  final String? narrator;
  final String? year;
  final String? description;
  final String? genre;
  final CoverImage? cover;
}

// `data` atom type indicators (well-known types from the iTunes spec).
const _typeUtf8 = 1;
const _typeUtf16 = 2;
const _typeJpeg = 13;
const _typePng = 14;

/// Reads the iTunes-style tags of [moov]. Returns empty [Metadata] when there
/// is no `ilst`. [narratorKeys] are tried in order.
Future<Metadata> parseMetadata(
  AtomReader atoms,
  Atom moov, {
  required List<String> narratorKeys,
}) async {
  final ilst = await atoms.path(moov, ['udta', 'meta', 'ilst']);
  if (ilst == null) return const Metadata();

  const textKeys = {'©nam', '©ART', 'aART', '©day', 'desc', '©cmt', '©gen'};
  final wanted = {...textKeys, ...narratorKeys};
  final texts = <String, String>{};
  CoverImage? cover;

  for (final item in await atoms.childrenOf(ilst)) {
    if (!wanted.contains(item.type) && item.type != 'covr') continue;
    final dataAtom = await atoms.child(item, 'data');
    if (dataAtom == null) continue;
    try {
      final cursor = ByteCursor(await atoms.data(dataAtom));
      final type = cursor.u32() & 0xFFFFFF;
      cursor.skip(4); // locale
      final value = cursor.bytes(cursor.remaining);
      if (item.type == 'covr') {
        cover ??= _cover(value, type);
      } else if (type == _typeUtf8 || type == _typeUtf16 || type == 0) {
        final text = decodeText(value, utf16: type == _typeUtf16);
        if (text.isNotEmpty) texts.putIfAbsent(item.type, () => text);
      }
    } on M4bParseException {
      // A broken tag shouldn't lose the rest of the metadata.
      continue;
    }
  }

  String? first(Iterable<String> keys) {
    for (final key in keys) {
      final value = texts[key];
      if (value != null) return value;
    }
    return null;
  }

  return Metadata(
    title: texts['©nam'],
    author: first(['©ART', 'aART']),
    narrator: first(narratorKeys),
    year: texts['©day'],
    description: first(['desc', '©cmt']),
    genre: texts['©gen'],
    cover: cover,
  );
}

CoverImage? _cover(Uint8List bytes, int type) {
  if (bytes.isEmpty) return null;
  // Copy so the image doesn't keep the reader's 64 KB block alive.
  final copy = Uint8List.fromList(bytes);
  if (type == _typeJpeg) return CoverImage(copy, CoverFormat.jpeg);
  if (type == _typePng) return CoverImage(copy, CoverFormat.png);
  // Untyped or mislabelled: sniff the magic number.
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return CoverImage(copy, CoverFormat.jpeg);
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return CoverImage(copy, CoverFormat.png);
  }
  return null;
}
