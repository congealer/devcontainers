import 'dart:async';
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:${templateOption:projectName}/counter.dart';
import 'package:test/test.dart';

/// Where waveforms go when they are enabled.
const _wavesDir = 'build/waves';

/// Ceiling on simulated time, in the clock generator's units. Generous -- the
/// longest test here spans about 150 -- since it exists to turn a hang into a
/// failure, not to schedule anything.
const _maxSimTime = 10000;

/// Set `WAVES=1` to dump one waveform per test into [_wavesDir], e.g.
/// `WAVES=1 dart test`. Off by default so tests stay fast and leave no files
/// behind.
///
/// An environment variable rather than a flag because `dart test` has no way to
/// pass custom values through to test code — it rejects `--define`.
final _dumpWaves = Platform.environment['WAVES'] != null;

/// A transaction-level testbench for [Counter].
///
/// Each method is one transaction: it describes intent ("count for 6 cycles,
/// stalling on 1, 2 and 4") rather than poking signals at hand-computed
/// timestamps. Named arguments carry what a UVM sequence item's fields would.
///
/// Stimulus is driven on the negative edge, so values are stable across the
/// positive edge that samples them. That keeps waveforms readable and avoids
/// `Sequential`'s deliberate `X` on a trigger/non-trigger race, without any
/// magic numbers in the tests.
class CounterBench {
  final Logic _en = Logic(name: 'en');
  final Logic _reset = Logic(name: 'reset');
  final Logic _clk = SimpleClockGenerator(10).clk;

  late final Counter dut;

  CounterBench({int width = 8}) {
    dut = Counter(_en, _reset, _clk, width: width);
  }

  /// The counter's current value.
  int get val => dut.val.value.toInt();

  /// Whether the counter is holding a defined value (not `x`/`z`).
  bool get isValid => dut.val.value.isValid;

  /// Builds the DUT, then runs [sequence] against it under the simulator.
  ///
  /// [name] labels the waveform file when `WAVES` is set.
  static Future<void> run(
    Future<void> Function(CounterBench b) sequence, {
    required String name,
    int width = 8,
  }) async {
    final b = CounterBench(width: width);
    await b.dut.build();

    if (_dumpWaves) {
      WaveDumper(b.dut, outputPath: '$_wavesDir/$name.vcd');
    }

    // Idle is the resting state; every transaction returns to it.
    b._en.inject(0);
    b._reset.inject(0);

    // The simulator runs unawaited, not the stimulus. That keeps [sequence] in
    // the test's own async flow, so a failed `expect` -- or an `AssertionError`
    // from this class's own asserts -- reaches the test framework directly.
    // Driving it the other way round means catching every error just to
    // rethrow it once the simulator has stopped.
    //
    // The ceiling is a runaway guard, not a schedule. A stuck sequence is
    // reported by the test framework's own timeout either way; what this stops
    // is the simulator, which would otherwise keep ticking forever -- the clock
    // generator never runs out of events -- long after the test gave up.
    Simulator.setMaxSimTime(_maxSimTime);
    unawaited(Simulator.run());

    await sequence(b);

    await Simulator.endSimulation();
  }

  /// Advances one cycle with the given input values.
  Future<void> _step({required int en, required int reset}) async {
    await _clk.nextNegedge;
    _en.put(en);
    _reset.put(reset);
    await _clk.nextPosedge;
  }

  /// Asserts reset for [duration] cycles, then idles for [settle] more.
  Future<void> reset({int duration = 1, int settle = 0}) async {
    for (var i = 0; i < duration; i++) {
      await _step(en: 0, reset: 1);
    }
    for (var i = 0; i < settle; i++) {
      await _step(en: 0, reset: 0);
    }
  }

  /// Counts for [duration] cycles, holding instead of incrementing on the
  /// cycles listed in [stall].
  ///
  /// [stall] entries are cycle indices within this window, so the counter
  /// advances by `duration - stall.length`.
  Future<void> count({
    required int duration,
    List<int> stall = const [],
  }) async {
    assert(stall.every((c) => c >= 0 && c < duration),
        'stall cycles must fall within 0..${duration - 1}, but got $stall.');

    for (var i = 0; i < duration; i++) {
      await _step(en: stall.contains(i) ? 0 : 1, reset: 0);
    }
  }

  /// Idles for [duration] cycles, driving nothing.
  Future<void> wait({required int duration}) async {
    for (var i = 0; i < duration; i++) {
      await _step(en: 0, reset: 0);
    }
  }
}

void main() {
  setUp(Simulator.reset);
  tearDown(Simulator.reset);

  test('reset holds the counter at zero', () async {
    await CounterBench.run(name: 'reset', (b) async {
      await b.reset(duration: 4);
      expect(b.val, 0);
    });
  });

  test('counts one per enabled cycle', () async {
    await CounterBench.run(name: 'count', (b) async {
      await b.reset(duration: 2, settle: 1);
      await b.count(duration: 5);
      expect(b.val, 5);
    });
  });

  test('stalled cycles do not increment', () async {
    await CounterBench.run(name: 'stall', (b) async {
      await b.reset(duration: 2, settle: 1);
      await b.count(duration: 6, stall: [1, 2, 4]);
      expect(b.val, 3); // 6 cycles - 3 stalls
    });
  });

  test('holds its value while idle, then resumes', () async {
    await CounterBench.run(name: 'idle_resume', (b) async {
      await b.reset(duration: 2);
      await b.count(duration: 3);
      expect(b.val, 3);

      await b.wait(duration: 4);
      expect(b.val, 3, reason: 'must not drift while disabled');

      await b.count(duration: 2);
      expect(b.val, 5, reason: 'must resume from where it stopped');
    });
  });

  test('reset mid-count returns to zero', () async {
    await CounterBench.run(name: 'reset_midcount', (b) async {
      await b.reset(duration: 1);
      await b.count(duration: 4);
      expect(b.val, 4);

      await b.reset(duration: 1);
      expect(b.val, 0);
    });
  });

  test('wraps around at its width', () async {
    await CounterBench.run(name: 'wraparound', width: 2, (b) async {
      await b.reset(duration: 1);
      await b.count(duration: 4); // 0,1,2,3 -> wraps to 0
      expect(b.val, 0);

      await b.count(duration: 1);
      expect(b.val, 1);
    });
  });

  test('never goes X', () async {
    await CounterBench.run(name: 'no_x', (b) async {
      await b.reset(duration: 2, settle: 1);
      for (var i = 0; i < 5; i++) {
        await b.count(duration: 1);
        expect(b.isValid, isTrue, reason: 'went X after $i counts');
      }
    });
  });

  test('generated SystemVerilog inlines the increment', () async {
    final b = CounterBench();
    await b.dut.build();

    final sv = SynthBuilder(b.dut, SystemVerilogSynthesizer())
        .getSynthFileContents()
        .map((f) => f.contents)
        .join('\n');

    // The increment lands inside always_ff, not in a separate assign.
    expect(sv, contains('val <= (val + '));
    expect(sv, isNot(contains('assign')));
    expect(sv, isNot(contains('carry')));
  });
}
