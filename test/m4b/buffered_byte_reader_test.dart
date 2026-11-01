import 'dart:typed_data';

import 'package:audiobook_listener/m4b/m4b.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/atom_builder.dart';

void main() {
  final data = Uint8List.fromList(List.generate(100, (i) => i));

  test('returns the same bytes as the underlying reader', () async {
    final plain = MemoryByteReader(data);
    final buffered = BufferedByteReader(plain, blockSize: 16);
    for (final (offset, count) in [
      (0, 10),
      (10, 6), // ends on a block boundary
      (14, 4), // crosses one boundary
      (5, 60), // spans several blocks
      (90, 50), // runs past the end
      (100, 4), // starts at the end
      (150, 4), // starts past the end
      (20, 0),
      (20, -3),
    ]) {
      expect(
        await buffered.read(offset, count),
        await plain.read(offset, count),
        reason: 'read($offset, $count)',
      );
    }
  });

  test(
    'serves reads within a cached block without hitting the source',
    () async {
      final source = CountingByteReader(MemoryByteReader(data));
      final buffered = BufferedByteReader(source, blockSize: 32);
      await buffered.read(0, 8);
      await buffered.read(8, 8);
      await buffered.read(24, 8);
      expect(source.calls, 1);
      await buffered.read(30, 4); // needs block 1 too
      expect(source.calls, 2);
    },
  );

  test('evicts the least recently used block', () async {
    final source = CountingByteReader(MemoryByteReader(data));
    final buffered = BufferedByteReader(
      source,
      blockSize: 16,
      maxCachedBlocks: 2,
    );
    await buffered.read(0, 1); // block 0
    await buffered.read(16, 1); // block 1
    await buffered.read(0, 1); // block 0 again: cached, now most recent
    await buffered.read(32, 1); // block 2: evicts block 1
    expect(source.calls, 3);
    await buffered.read(0, 1);
    expect(source.calls, 3);
    await buffered.read(16, 1);
    expect(source.calls, 4);
  });
}
