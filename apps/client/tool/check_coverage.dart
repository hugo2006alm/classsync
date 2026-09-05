import 'dart:io';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln('Usage: check_coverage.dart <lcov.info> <minimum-percent>');
    exitCode = 64;
    return;
  }
  final minimum = double.parse(arguments[1]);
  var found = 0;
  var hit = 0;
  var include = false;
  for (final line in File(arguments[0]).readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      final path = line.substring(3).replaceAll('\\', '/');
      include =
          (path.startsWith('lib/') || path.contains('/lib/')) &&
          !path.endsWith('.g.dart');
    } else if (include && line.startsWith('DA:')) {
      found += 1;
      final count = int.parse(line.split(',')[1]);
      if (count > 0) hit += 1;
    }
  }
  final percent = found == 0 ? 0 : hit * 100 / found;
  stdout.writeln('Handwritten line coverage: ${percent.toStringAsFixed(1)}%');
  if (percent < minimum) {
    stderr.writeln('Coverage below ${minimum.toStringAsFixed(1)}% gate.');
    exitCode = 1;
  }
}
