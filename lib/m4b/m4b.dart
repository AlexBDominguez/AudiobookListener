/// Pure-Dart .m4b parser. No Flutter, no `dart:io`: bytes come through a
/// [ByteReader].
library;

export 'buffered_byte_reader.dart';
export 'byte_reader.dart' show ByteReader, MemoryByteReader;
export 'm4b_info.dart';
export 'm4b_parser.dart';
