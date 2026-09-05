import 'package:classsync/domain/sync/transcript_chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not silently truncate long lines', () {
    const chunker = TranscriptChunker(maxCharacters: 20);
    final source = 'a' * 57;

    final chunks = chunker.chunk(source);

    expect(chunks.join(), source);
    expect(chunks.every((chunk) => chunk.length <= 20), isTrue);
  });

  test('prefers transcript line boundaries', () {
    const chunker = TranscriptChunker(maxCharacters: 14);
    final chunks = chunker.chunk('first\nsecond\nthird');

    expect(chunks.length, 2);
    expect(chunks.join().replaceAll('\n', ''), 'firstsecondthird');
  });

  test('rejects input above explicit cost bound', () {
    const chunker = TranscriptChunker(
      maxCharacters: 10,
      maxInputCharacters: 20,
      maxChunks: 2,
    );
    expect(() => chunker.chunk('xxxxxxxxxxxxxxxxxxxxx'), throwsFormatException);
  });
}
