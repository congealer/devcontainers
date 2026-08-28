import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_patches/rohd_synth.dart';
import 'package:test/test.dart';

/// Counts module *definitions*, not the `endmodule` lines that also contain
/// the substring "module ".
int _moduleCount(String sv) =>
    RegExp(r'^module ', multiLine: true).allMatches(sv).length;

/// A trivial two-module hierarchy, so multi-file output has something to split.
class _Leaf extends Module {
  _Leaf(Logic a) : super(name: 'leaf', definitionName: 'Leaf') {
    a = addInput('a', a, width: 8);
    addOutput('o', width: 8) <= ~a;
  }
}

class _Top extends Module {
  _Top(Logic a) : super(name: 'top', definitionName: 'Top') {
    a = addInput('a', a, width: 8);
    addOutput('o', width: 8) <= _Leaf(a).output('o');
  }
}

Future<_Top> _buildTop() async {
  final m = _Top(Logic(name: 'a', width: 8));
  await m.build();
  return m;
}

void main() {
  late Directory tmp;

  // `async` so the reset is awaited. A synchronous callback returns `void`,
  // and `setUp`/`tearDown` have nothing to wait on -- the next test could start
  // before the simulator finished resetting.
  setUp(() async {
    await Simulator.reset();
    tmp = Directory.systemTemp.createTempSync('rohd_synth_test');
  });

  tearDown(() async {
    tmp.deleteSync(recursive: true);
    await Simulator.reset();
  });

  group('generateSynthWith', () {
    test('emits no header by default', () async {
      final m = await _buildTop();
      expect(m.generateSynthWith(), startsWith('module '));
    });

    test('emits the given header verbatim', () async {
      final m = await _buildTop();
      expect(m.generateSynthWith(header: '// hi\n\n'),
          startsWith('// hi\n\nmodule '));
    });

    test('body is identical to stock generateSynth', () async {
      final m = await _buildTop();
      final stock = m.generateSynth();
      final stockBody = stock.substring(stock.indexOf('module '));

      expect(m.generateSynthWith(), stockBody);
    });

    test('is reproducible, unlike stock generateSynth', () async {
      final m = await _buildTop();

      // The whole point of the patch: no timestamp, so output is stable and
      // generated RTL can be diffed or checked in.
      expect(m.generateSynthWith(), m.generateSynthWith());

      // Stock embeds a generation time, so its header differs run to run. Only
      // the header should differ — prove the instability lives there.
      final a = m.generateSynth(), b = m.generateSynth();
      expect(a.substring(a.indexOf('module ')),
          b.substring(b.indexOf('module ')),
          reason: 'stock bodies should still match');
    });

    test('separates module definitions', () async {
      final m = await _buildTop();
      final sv = m.generateSynthWith(separator: '\n//--CUT--\n');

      expect(sv, contains('//--CUT--'));
      expect(_moduleCount(sv), 2);
    });
  });

  group('writeSynthFile', () {
    test('writes the design to one file', () async {
      final m = await _buildTop();
      final path = '${tmp.path}/out/design.sv';

      final file = m.writeSynthFile(path, header: '// hdr\n\n');

      expect(file.path, path);
      expect(file.readAsStringSync(), m.generateSynthWith(header: '// hdr\n\n'));
    });

    test('creates missing parent directories', () async {
      final m = await _buildTop();
      final file = m.writeSynthFile('${tmp.path}/a/b/c/design.sv');
      expect(file.existsSync(), isTrue);
    });

    test('rewriting produces an identical file', () async {
      final m = await _buildTop();
      final path = '${tmp.path}/design.sv';

      final first = m.writeSynthFile(path).readAsStringSync();
      final second = m.writeSynthFile(path).readAsStringSync();

      expect(second, first);
    });
  });

  group('writeSynthFiles', () {
    test('writes one file per module, named after it', () async {
      final m = await _buildTop();

      final files = m.writeSynthFiles(tmp.path);

      final names = files.map((f) => f.uri.pathSegments.last).toSet();
      expect(names, {'Top.sv', 'Leaf.sv'});
      expect(files.every((f) => f.existsSync()), isTrue);
    });

    test('each file holds only its own module', () async {
      final m = await _buildTop();

      final files = m.writeSynthFiles(tmp.path);
      for (final f in files) {
        final contents = f.readAsStringSync();
        expect(_moduleCount(contents), 1,
            reason: '${f.path} should hold exactly one module');
      }
    });

    test('applies the header to every file', () async {
      final m = await _buildTop();

      final files = m.writeSynthFiles(tmp.path, header: '// hdr\n\n');

      expect(files.map((f) => f.readAsStringSync()),
          everyElement(startsWith('// hdr\n\n')));
    });
  });
}
