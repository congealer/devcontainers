import 'package:rohd/rohd.dart';
import 'package:rohd_patches/rohd_inline.dart';
import 'package:test/test.dart';

/// Builds a module from [body] and returns its generated SystemVerilog.
Future<String> synth(void Function(Module m, Logic a, Logic b) body,
    {int wa = 8, int wb = 8}) async {
  final m = _Harness(Logic(name: 'a', width: wa), Logic(name: 'b', width: wb),
      body: body);
  await m.build();
  return SynthBuilder(m, SystemVerilogSynthesizer())
      .getSynthFileContents()
      .map((f) => f.contents)
      .join('\n');
}

class _Harness extends Module {
  _Harness(Logic a, Logic b,
      {required void Function(Module, Logic, Logic) body}) {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    body(this, a, b);
  }
}

/// Evaluates [op] on concrete values and returns the result as an int.
int eval(Logic Function(Logic a, Logic b) op, int av, int bv,
    {int wa = 8, int wb = 8}) {
  final a = Logic(width: wa)..put(av);
  final b = Logic(width: wb)..put(bv);
  return op(a, b).value.toInt();
}

void main() {
  group('add (drop-in for +)', () {
    test('wraps at the operand width, like Add.sum', () {
      expect(eval((a, b) => a.add(b), 3, 4), 7);
      expect(eval((a, b) => a.add(b), 200, 100), 44); // 300 & 0xFF
      expect(eval((a, b) => a.add(b), 255, 1), 0);
    });

    test('matches stock + numerically', () {
      for (final v in [0, 1, 127, 200, 255]) {
        expect(eval((a, b) => a.add(b), v, 37),
            eval((a, b) => a + b, v, 37),
            reason: 'mismatch at $v');
      }
    });

    test('rejects mismatched widths, like stock', () {
      expect(() => eval((a, b) => a.add(b), 1, 1, wa: 8, wb: 4),
          throwsA(isA<PortWidthMismatchException>()));
    });

    test('generates no carry wire and inlines', () async {
      final sv = await synth((m, a, b) => m.addOutput('o', width: 8) <= a.add(b));
      expect(sv, contains('assign o = a + b'));
      expect(sv, isNot(contains('carry')));
    });

    test('stock + does spill a carry wire (the bug being patched)', () async {
      final sv = await synth((m, a, b) => m.addOutput('o', width: 8) <= a + b);
      expect(sv, contains('carry'));
    });
  });

  group('addWide', () {
    test('keeps the carry as the top bit', () {
      expect(eval((a, b) => a.addWide(b), 255, 1), 256);
      expect(eval((a, b) => a.addWide(b), 200, 100), 300);
      expect(eval((a, b) => a.addWide(b), 3, 4), 7);
    });

    test('result is one bit wider than the widest operand', () {
      final a = Logic(width: 8), b = Logic(width: 4);
      expect(a.addWide(b).width, 9);
      expect(b.addWide(a).width, 9);
    });

    test('accepts mismatched widths, zero-extending', () {
      expect(eval((a, b) => a.addWide(b), 255, 15, wa: 8, wb: 4), 270);
    });

    test('inlines', () async {
      final sv =
          await synth((m, a, b) => m.addOutput('o', width: 9) <= a.addWide(b));
      expect(sv, contains('assign o = a + b'));
    });
  });

  group('mulWide', () {
    test('keeps the full product', () {
      expect(eval((a, b) => a.mulWide(b), 255, 255), 65025);
      expect(eval((a, b) => a.mulWide(b), 16, 16), 256);
    });

    test('stock * truncates the same product', () {
      expect(eval((a, b) => a * b, 16, 16), 0); // 256 & 0xFF
    });

    test('result width is the sum of operand widths', () {
      expect(Logic(width: 8).mulWide(Logic(width: 4)).width, 12);
    });

    test('is not wrapped in {} (which would defeat widening)', () async {
      final sv = await synth(
          (m, a, b) => m.addOutput('o', width: 16) <= a.mulWide(b));
      expect(sv, contains('assign o = a * b'));
      expect(sv, isNot(contains('{a * b}')));
    });
  });

  group('InlineLogic chaining', () {
    test('a + b + c stays inlined (no fallback to Add)', () async {
      final sv = await synth((m, a, b) =>
          m.addOutput('o', width: 8) <= a.inl + b + 2 + 3);
      expect(sv, isNot(contains('carry')));
    });

    test('survives a trip through * and back into +', () async {
      final sv = await synth(
          (m, a, b) => m.addOutput('o', width: 8) <= (a.inl + 1) * 3 + 4);
      expect(sv, isNot(contains('carry')));
    });

    test('survives slicing', () async {
      final sv = await synth((m, a, b) =>
          m.addOutput('o', width: 4) <= (a.inl + 1).getRange(0, 4) + 1);
      expect(sv, isNot(contains('carry')));
    });

    test('fixes ROHD internals built on overridden operators (abs)', () async {
      // Logic.abs() is `mux(this[-1], ~this + 1, this)`; the `+` inside it
      // reaches us because `~` returns an InlineLogic.
      final sv =
          await synth((m, a, b) => m.addOutput('o', width: 8) <= a.inl.abs());
      expect(sv, isNot(contains('carry')));
    });

    test('stock abs() does spill a carry wire', () async {
      final sv = await synth((m, a, b) => m.addOutput('o', width: 8) <= a.abs());
      expect(sv, contains('carry'));
    });
  });

  group('wrapping is free', () {
    test('.inl leaves no trace in generated SystemVerilog', () async {
      final wrapped =
          await synth((m, a, b) => m.addOutput('o', width: 8) <= a.inl + b);
      final direct =
          await synth((m, a, b) => m.addOutput('o', width: 8) <= a.add(b));
      expect(wrapped, direct);
    });

    test('.inl on an InlineLogic is a no-op', () {
      final x = InlineLogic(width: 8);
      expect(identical(x.inl, x), isTrue);
    });
  });

  group('constant on the left', () {
    test('1.inl + val equals val + 1, width taken from the right', () {
      final v = Logic(width: 8)..put(41);
      final r = 1.inl + v;
      expect(r.width, 8);
      expect(r.value.toInt(), 42);
    });

    test('inlines', () async {
      final sv =
          await synth((m, a, b) => m.addOutput('o', width: 8) <= 1.inl + a);
      expect(sv, contains("assign o = 8'h1 + a"));
      expect(sv, isNot(contains('carry')));
    });
  });

  group('constant width checking', () {
    test('rejects a constant too wide for the operand', () {
      final a = Logic(width: 8);
      expect(() => a.add(300), throwsA(isA<AssertionError>()));
    });

    test('accepts negative constants as two\'s complement', () {
      expect(eval((a, b) => a.add(-1), 5, 0), 4);
    });
  });

  group('containment', () {
    test('an InlineLogic result assigns to a plain Logic port', () async {
      // The patch must not force port types to change: assignment checks
      // width, not type.
      final sv = await synth((m, a, b) {
        final o = m.addOutput('o', width: 8); // stock port type
        o <= a.inl + 1;
      });
      expect(sv, contains('assign o = a + '));
      expect(sv, isNot(contains('carry')));
    });

    test('a reusable wrapper serves many operations', () async {
      final sv = await synth((m, a, b) {
        final v = a.inl; // wrap once
        m.addOutput('o1', width: 8) <= v + 1;
        m.addOutput('o2', width: 8) <= v + b;
        m.addOutput('o3', width: 8) <= v + 3;
      });
      expect(sv, isNot(contains('carry')));
    });
  });

  group('prefix spellings', () {
    test('match the method forms', () {
      expect(eval((a, b) => inlineAdd(a, b), 3, 4),
          eval((a, b) => a.add(b), 3, 4));
      expect(eval((a, b) => inlineAddWide(a, b), 255, 1),
          eval((a, b) => a.addWide(b), 255, 1));
      expect(eval((a, b) => inlineMulWide(a, b), 200, 200),
          eval((a, b) => a.mulWide(b), 200, 200));
    });
  });
}
