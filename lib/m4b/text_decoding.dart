import 'dart:convert';
import 'dart:typed_data';

/// Decodes a metadata or chapter string. Honours UTF-16 byte order marks,
/// tries UTF-8 and falls back to Latin-1 for files written by sloppy tools.
/// Trailing NULs and surrounding whitespace are removed.
String decodeText(Uint8List bytes, {bool utf16 = false}) {
  var end = bytes.length;
  while (end > 0 && bytes[end - 1] == 0) {
    end--;
  }
  final b = Uint8List.sublistView(bytes, 0, end);

  if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) {
    return _utf16(b, 2, bigEndian: true).trim();
  }
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) {
    return _utf16(b, 2, bigEndian: false).trim();
  }
  if (utf16) return _utf16(b, 0, bigEndian: true).trim();

  try {
    return utf8.decode(b).trim();
  } on FormatException {
    return latin1.decode(b).trim();
  }
}

String _utf16(Uint8List b, int start, {required bool bigEndian}) {
  final units = <int>[];
  for (var i = start; i + 1 < b.length; i += 2) {
    units.add(bigEndian ? (b[i] << 8) | b[i + 1] : (b[i + 1] << 8) | b[i]);
  }
  return String.fromCharCodes(units);
}
