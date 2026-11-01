import 'dart:typed_data';

import 'byte_reader.dart';
import 'm4b_info.dart';

/// Header of an MP4 atom (box). Offsets are absolute positions in the file.
class Atom {
  const Atom(this.type, this.offset, this.headerSize, this.size);

  /// Four characters, decoded as Latin-1 so `©nam` keeps its `©`.
  final String type;
  final int offset;
  final int headerSize;
  final int size;

  int get dataOffset => offset + headerSize;
  int get dataSize => size - headerSize;
  int get end => offset + size;

  @override
  String toString() => 'Atom($type @$offset, $size bytes)';
}

/// Walks atoms by reading only their headers, so a multi-hundred-MB `mdat`
/// is skipped without being read.
class AtomReader {
  AtomReader(this._reader);

  /// Upper bound for reading a single atom's payload into memory. Protects
  /// against corrupt sizes; real metadata atoms are far smaller.
  static const maxDataSize = 32 * 1024 * 1024;

  final ByteReader _reader;

  int get length => _reader.length;

  /// Atoms laid out between [start] and [end]. Stops at the first header that
  /// doesn't make sense (truncated file); an atom that claims to extend past
  /// [end] is clamped to it.
  Future<List<Atom>> children(int start, int end) async {
    final atoms = <Atom>[];
    var pos = start;
    while (pos + 8 <= end) {
      final header = await _reader.read(pos, 16);
      if (header.length < 8) break;
      final data = ByteData.sublistView(header);
      var size = data.getUint32(0);
      final type = String.fromCharCodes(header, 4, 8);
      var headerSize = 8;
      if (size == 1) {
        if (header.length < 16) break;
        size = data.getUint64(8);
        headerSize = 16;
      } else if (size == 0) {
        size = end - pos;
      }
      if (size < headerSize) break;
      if (pos + size > end) size = end - pos;
      atoms.add(Atom(type, pos, headerSize, size));
      pos += size;
    }
    return atoms;
  }

  Future<List<Atom>> childrenOf(Atom parent, {int skip = 0}) =>
      children(parent.dataOffset + skip, parent.end);

  /// First child of [parent] of the given [type], or `null`.
  Future<Atom?> child(Atom parent, String type, {int skip = 0}) async {
    for (final atom in await childrenOf(parent, skip: skip)) {
      if (atom.type == type) return atom;
    }
    return null;
  }

  /// Follows a path of child types, e.g. `['udta', 'meta', 'ilst']`. Handles
  /// `meta` being either a full box (ISO) or a plain box (QuickTime).
  Future<Atom?> path(Atom parent, List<String> types) async {
    Atom? current = parent;
    for (final type in types) {
      if (current == null) return null;
      final skip = current.type == 'meta' ? await _metaSkip(current) : 0;
      current = await child(current, type, skip: skip);
    }
    return current;
  }

  /// Payload of [atom] (everything after its header).
  Future<Uint8List> data(Atom atom) {
    if (atom.dataSize > maxDataSize) {
      throw M4bParseException('Atom ${atom.type} too large: ${atom.size}');
    }
    return _reader.read(atom.dataOffset, atom.dataSize);
  }

  Future<Uint8List> read(int offset, int count) => _reader.read(offset, count);

  Future<int> _metaSkip(Atom meta) async {
    // ISO `meta` has 4 bytes of version/flags before its children; the
    // QuickTime variant starts straight with a child atom (usually `hdlr`),
    // so its type sits right after the first size field.
    final peek = await _reader.read(meta.dataOffset + 4, 4);
    return String.fromCharCodes(peek) == 'hdlr' ? 0 : 4;
  }
}

/// Sequential big-endian reader over a byte buffer. Throws
/// [M4bParseException] instead of [RangeError] when data runs out.
class ByteCursor {
  ByteCursor(this._bytes) : _data = ByteData.sublistView(_bytes);

  final Uint8List _bytes;
  final ByteData _data;
  int position = 0;

  int get remaining => _bytes.length - position;

  int u8() {
    _require(1);
    return _data.getUint8(position++);
  }

  int u16() {
    _require(2);
    final v = _data.getUint16(position);
    position += 2;
    return v;
  }

  int u32() {
    _require(4);
    final v = _data.getUint32(position);
    position += 4;
    return v;
  }

  int u64() {
    _require(8);
    final v = _data.getUint64(position);
    position += 8;
    return v;
  }

  Uint8List bytes(int count) {
    _require(count);
    final v = Uint8List.sublistView(_bytes, position, position + count);
    position += count;
    return v;
  }

  void skip(int count) {
    _require(count);
    position += count;
  }

  void _require(int count) {
    if (count < 0 || position + count > _bytes.length) {
      throw const M4bParseException('Unexpected end of atom data');
    }
  }
}

/// Converts [ticks] in a track/movie [timescale] to a [Duration] without
/// overflowing on long books.
Duration ticksToDuration(int ticks, int timescale) {
  if (timescale <= 0) return Duration.zero;
  final whole = ticks ~/ timescale;
  final rest = ticks % timescale;
  return Duration(
    microseconds:
        whole * Duration.microsecondsPerSecond +
        rest * Duration.microsecondsPerSecond ~/ timescale,
  );
}
