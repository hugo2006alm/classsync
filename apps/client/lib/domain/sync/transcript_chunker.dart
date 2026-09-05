class TranscriptChunker {
  const TranscriptChunker({
    this.maxCharacters = 48000,
    this.maxInputCharacters = 1200000,
    this.maxChunks = 25,
  });

  final int maxCharacters;
  final int maxInputCharacters;
  final int maxChunks;

  List<String> chunk(String input) {
    if (input.length > maxInputCharacters) {
      throw FormatException(
        'Transcript is too large (${input.length} characters). '
        'The supported limit is $maxInputCharacters characters.',
      );
    }
    if (input.length <= maxCharacters) return [input];
    final lines = input.split('\n');
    final chunks = <String>[];
    var buffer = StringBuffer();
    for (final line in lines) {
      if (buffer.length + line.length + 1 > maxCharacters &&
          buffer.isNotEmpty) {
        chunks.add(buffer.toString());
        buffer = StringBuffer();
      }
      if (line.length <= maxCharacters) {
        buffer.writeln(line);
        continue;
      }
      if (buffer.isNotEmpty) {
        chunks.add(buffer.toString());
        buffer = StringBuffer();
      }
      for (var offset = 0; offset < line.length; offset += maxCharacters) {
        final end = (offset + maxCharacters).clamp(0, line.length);
        chunks.add(line.substring(offset, end));
      }
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString());
    if (chunks.length > maxChunks) {
      throw FormatException(
        'Transcript needs ${chunks.length} AI chunks; the safe limit is '
        '$maxChunks. Split this recording before importing it.',
      );
    }
    return chunks;
  }
}
