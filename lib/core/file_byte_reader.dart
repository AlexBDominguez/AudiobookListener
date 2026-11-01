import 'dart:io';
import 'dart:typed_data';

import '../m4b/m4b.dart';

/// [ByteReader] over a local file (Windows and tests). Lives outside
/// `lib/m4b/` because that module must not depend on `dart:io`.
class FileByteReader implements ByteReader {
  FileByteReader._(this._file, this.length);

  static Future<FileByteReader> open(String path) async {
    final file = await File(path).open();
    return FileByteReader._(file, await file.length());
  }

  final RandomAccessFile _file;

  @override
  final int length;

  /// Reads are sequential: [RandomAccessFile] doesn't allow overlapping
  /// operations, and the parser always awaits each read.
  @override
  Future<Uint8List> read(int offset, int count) async {
    if (offset >= length || count <= 0) return Uint8List(0);
    final start = offset < 0 ? 0 : offset;
    final available = length - start;
    await _file.setPosition(start);
    return _file.read(count < available ? count : available);
  }

  Future<void> close() => _file.close();
}
