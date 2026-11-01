import 'dart:typed_data';

/// Random-access source of bytes. The parser only talks to this interface, so
/// it doesn't know whether bytes come from SAF, `dart:io` or memory.
abstract interface class ByteReader {
  /// Total number of bytes available.
  int get length;

  /// Reads up to [count] bytes starting at [offset]. Returns fewer bytes only
  /// when the end of the source is reached, and an empty list past the end.
  Future<Uint8List> read(int offset, int count);
}

/// [ByteReader] over an in-memory buffer. Mainly for tests.
class MemoryByteReader implements ByteReader {
  MemoryByteReader(this._bytes);

  final Uint8List _bytes;

  @override
  int get length => _bytes.length;

  @override
  Future<Uint8List> read(int offset, int count) async {
    final (start, end) = clampRange(offset, count, length);
    return Uint8List.sublistView(_bytes, start, end);
  }
}

/// Clamps the range `[offset, offset + count)` to `[0, length)`.
(int, int) clampRange(int offset, int count, int length) {
  final start = offset.clamp(0, length);
  final end = (offset + (count < 0 ? 0 : count)).clamp(start, length);
  return (start, end);
}
