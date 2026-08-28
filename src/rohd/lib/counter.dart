import 'package:rohd/rohd.dart';

// `.inl` makes `+` emit inlineable SystemVerilog instead of going through
// ROHD's `Add` (which always spills a separate top-level
// `assign {carry, sum} = ...;`). See `rohd_inline.dart` for why.
//
// The patch is contained to the one expression that uses it: `val` stays an
// ordinary `Logic` port, so nothing about this module's interface changes and
// consumers need not import the patch.
import 'package:rohd_patches/rohd_inline.dart';

/// A width-configurable counter.
///
/// Holds its value while [Counter.new]'s `en` is low, and returns to zero while
/// `reset` is high. Wraps around at [width] bits.
class Counter extends Module {
  /// The current count.
  Logic get val => output('val');

  /// The width of [val]; determined at run time.
  final int width;

  Counter(
    Logic en,
    Logic reset,
    Logic clk, {
    this.width = 8,
    super.name = 'counter',
  }) {
    // Register inputs and outputs of the module in the constructor. Module
    // logic must consume registered inputs and output to registered outputs.
    en = addInput('en', en);
    reset = addInput('reset', reset);
    clk = addInput('clk', clk);

    final val = addOutput('val', width: width);

    // `Sequential` is like SystemVerilog's always_ff, here triggered on the
    // positive edge of clk.
    Sequential(clk, [
      // `If` is a conditional if statement, like `if` in a SystemVerilog
      // always block.
      If(
        reset,
        // the '<' operator is a conditional assignment
        then: [val < 0],
        orElse: [
          // `.inl` routes this `+` through an inlineable adder, so the addition
          // lands inside the `always_ff` block rather than in a separate
          // top-level `assign`.
          If(en, then: [val < val.inl + 1]),
        ],
      ),
    ]);
  }
}
