class TranscriptChunker {
  const TranscriptChunker({this.maxCharacters = 48000});

  final int maxCharacters;

  List<String> chunk(String input) {
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
    return chunks;
  }
}
