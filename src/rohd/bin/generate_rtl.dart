// ignore_for_file: avoid_print

import 'package:rohd/rohd.dart';
// `writeSynthFile` replaces ROHD's fixed comment header (which embeds a
// timestamp, so the output would differ on every run) and writes the result to
// a file, which `generateSynth()` cannot do on its own.
import 'package:rohd_patches/rohd_synth.dart';
import 'package:${templateOption:projectName}/counter.dart';

/// Where generated RTL lands. Gitignored.
const _outputDir = 'build';

const _header = '''
// Counter module
// Auto-generated SystemVerilog - do not edit by hand.

''';

/// Generates the design's SystemVerilog.
///
/// This is the project's only entry point: behavior is verified in `test/`, so
/// there is nothing to simulate here. To eyeball a waveform, run the tests with
/// `WAVES=1 dart test` — they already drive the interesting stimulus.
Future<void> main() async {
  final counter = Counter(
    Logic(name: 'en'),
    Logic(name: 'reset'),
    SimpleClockGenerator(10).clk,
  );

  // A module must be built before it can be synthesized.
  await counter.build();

  final file = counter.writeSynthFile('$_outputDir/counter.sv', header: _header);
  print('Wrote ${file.path}');
}
