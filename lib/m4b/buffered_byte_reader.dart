import 'dart:collection';
import 'dart:typed_data';

import 'byte_reader.dart';

/// Wraps a [ByteReader] and fetches whole aligned blocks (64 KB by default),
/// so many small reads (atom headers, tiny boxes) turn into few large ones.
/// Each read on a SAF reader is a platform-channel call, which is costly.
///
/// Keeps the most recently used [maxCachedBlocks] blocks in memory.
class BufferedByteReader implements ByteReader {
  BufferedByteReader(
    this._inner, {
    this.blockSize = 64 * 1024,
    this.maxCachedBlocks = 32,
  }) : assert(blockSize > 0),
       assert(maxCachedBlocks > 0);

  final ByteReader _inner;
  final int blockSize;
  final int maxCachedBlocks;

  // Insertion-ordered: the first key is the least recently used block.
  final LinkedHashMap<int, Uint8List> _blocks = LinkedHashMap();

  @override
  int get length => _inner.length;

  @override
  Future<Uint8List> read(int offset, int count) async {
    final (start, end) = clampRange(offset, count, length);
    if (start == end) return Uint8List(0);

    final firstBlock = start ~/ blockSize;
    final lastBlock = (end - 1) ~/ blockSize;
    if (firstBlock == lastBlock) {
      final block = await _block(firstBlock);
      final base = firstBlock * blockSize;
      return Uint8List.sublistView(block, start - base, end - base);
    }

    final result = Uint8List(end - start);
    for (var i = firstBlock; i <= lastBlock; i++) {
      final block = await _block(i);
      final base = i * blockSize;
      final from = (start - base).clamp(0, block.length);
      final to = (end - base).clamp(0, block.length);
      result.setRange(base + from - start, base + to - start, block, from);
    }
    return result;
  }

  Future<Uint8List> _block(int index) async {
    final cached = _blocks.remove(index);
    if (cached != null) {
      _blocks[index] = cached;
      return cached;
    }
    final block = await _inner.read(index * blockSize, blockSize);
    _blocks[index] = block;
    if (_blocks.length > maxCachedBlocks) {
      _blocks.remove(_blocks.keys.first);
    }
    return block;
  }
}
