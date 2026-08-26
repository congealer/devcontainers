// rohd_inline — inlineable arithmetic for ROHD.
//
// ## Why this exists
//
// ROHD's `+` operator instantiates the library's `Add` module, which has *two*
// outputs (sum and carry). ROHD's SystemVerilog synthesizer can only inline
// modules with a single output, so every addition spills a separate top-level
// `assign {carry, sum} = ...;` outside of any `always_ff`/`always_comb` block,
// along with a carry wire nobody reads.
//
// Every other arithmetic module in ROHD (`Subtract`, `Multiply`, `Divide`,
// `Modulo`) has one output and inlines fine. `Add` became the lone exception in
// intel/rohd#478, purely to dodge a SystemVerilog lint warning about implicit
// width expansion.
//
// This library provides a carry-free adder that inlines, plus the widening
// operations ROHD lacks entirely (`Multiply` silently discards the upper half
// of a product).
//
// ## Contract
//
// `add` is a drop-in for `+`: same width, same wraparound, same rejection of
// mismatched operand widths. Only the generated SystemVerilog differs.
//
// `addWide`/`mulWide` are new operations with no stock equivalent, so they are
// lossless and accept mismatched widths (zero-extending, since [LogicValue] is
// unsigned by definition).
//
// Truncation is not wrapped: use ROHD's own `getRange`/`slice`.

import 'package:rohd/rohd.dart';

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

/// Shared plumbing for the inlineable arithmetic modules.
abstract class _InlineOp extends Module with InlineSystemVerilog {
  static const _a = 'a', _b = 'b', _result = 'result';

  /// The operator to emit in generated SystemVerilog, e.g. `+`.
  String get _opStr;

  /// The result of the operation.
  InlineLogic get result => output(_result) as InlineLogic;

  _InlineOp(Logic in0, Logic in1, int resultWidth, {required super.name}) {
    addInput(_a, in0, width: in0.width);
    addInput(_b, in1, width: in1.width);

    // Typed so that chained operations (`a + b + c`, which parses as
    // `(a + b) + c`) keep dispatching to this library rather than falling back
    // to ROHD's `Add` on the second operation.
    addTypedOutput<InlineLogic>(
      _result,
      ({String name = ''}) => InlineLogic(name: name, width: resultWidth),
    );

    void execute() => result.put(_eval(input(_a).value, input(_b).value));
    execute();
    input(_a).glitch.listen((_) => execute());
    input(_b).glitch.listen((_) => execute());
  }

  /// Computes the simulation value of this operation.
  LogicValue _eval(LogicValue a, LogicValue b);

  @override
  String inlineVerilog(Map<String, String> inputs) =>
      '${inputs[_a]} $_opStr ${inputs[_b]}';
}

/// Addition that discards the carry, so it can be inlined.
///
/// Equivalent to `Add(a, b).sum`: same width, same wraparound.
class _InlineAdd extends _InlineOp {
  _InlineAdd(Logic in0, Logic in1)
      : super(in0, in1, in0.width, name: 'inline_add');

  @override
  String get _opStr => '+';

  @override
  LogicValue _eval(LogicValue a, LogicValue b) => a + b;
}

/// Addition that keeps the carry as the most significant bit of the result.
///
/// The result is one bit wider than the widest operand, so no information is
/// lost. This is what ROHD's `Add` expresses as two separate output ports.
class _InlineAddWide extends _InlineOp {
  final int _w;

  _InlineAddWide(Logic in0, Logic in1)
      : _w = _widthOf(in0, in1),
        super(in0, in1, _widthOf(in0, in1), name: 'inline_add_wide');

  static int _widthOf(Logic a, Logic b) =>
      (a.width > b.width ? a.width : b.width) + 1;

  @override
  String get _opStr => '+';

  @override
  LogicValue _eval(LogicValue a, LogicValue b) =>
      a.zeroExtend(_w) + b.zeroExtend(_w);
}

/// Multiplication that keeps the full product.
///
/// The result is `a.width + b.width` wide. ROHD's `Multiply` truncates to the
/// input width, discarding the upper half.
class _InlineMulWide extends _InlineOp {
  final int _w;

  _InlineMulWide(Logic in0, Logic in1)
      : _w = in0.width + in1.width,
        super(in0, in1, in0.width + in1.width, name: 'inline_mul_wide');

  @override
  String get _opStr => '*';

  @override
  LogicValue _eval(LogicValue a, LogicValue b) =>
      a.zeroExtend(_w) * b.zeroExtend(_w);

  // NOTE: deliberately *not* wrapping the expression in `{}`. That would force
  // SystemVerilog to treat it as self-determined, computing at the operand
  // width and then extending — which is exactly why ROHD's `Multiply` cannot
  // produce a full-width product.
}

// ---------------------------------------------------------------------------
// The signal type
// ---------------------------------------------------------------------------

/// A [Logic] whose arithmetic emits inlineable SystemVerilog.
///
/// `operator +` is an instance method, so overriding it here is ordinary
/// polymorphism: whenever an [InlineLogic] is the left-hand operand, `a + b`
/// dispatches here and never reaches ROHD's `Add`.
///
/// The other operators are overridden only to *return* an [InlineLogic], so
/// that a chain stays in this family. Two consequences:
///
///  * `(a + b) * c + d` keeps inlining all the way through, instead of falling
///    back to `Add` at the second `+`.
///  * ROHD methods implemented in terms of these operators get fixed too. For
///    example `Logic.abs()` is `mux(this[-1], ~this + 1, this)`; because `~`
///    returns an [InlineLogic], the `+` inside it dispatches here as well.
class InlineLogic extends Logic {
  InlineLogic({super.name, super.width});

  @override
  InlineLogic clone({String? name}) =>
      InlineLogic(name: name ?? this.name, width: width);

  @override
  InlineLogic operator +(dynamic other) => add(other);

  // Below: stock behavior, re-wrapped to keep the chain in this family.

  @override
  InlineLogic operator -(dynamic other) => (super - other).inl;

  @override
  InlineLogic operator *(dynamic other) => (super * other).inl;

  @override
  InlineLogic operator ~() => NotGate(this).out.inl;

  @override
  InlineLogic operator &(Logic other) => (super & other).inl;

  @override
  InlineLogic operator |(Logic other) => (super | other).inl;

  @override
  InlineLogic operator ^(Logic other) => (super ^ other).inl;

  @override
  InlineLogic operator <<(dynamic other) => (super << other).inl;

  @override
  InlineLogic operator >>(dynamic other) => (super >> other).inl;

  @override
  InlineLogic operator >>>(dynamic other) => (super >>> other).inl;

  @override
  InlineLogic operator [](dynamic index) => super[index].inl;

  @override
  InlineLogic slice(int endIndex, int startIndex) =>
      super.slice(endIndex, startIndex).inl;

  @override
  InlineLogic getRange(int startIndex, [int? endIndex]) =>
      super.getRange(startIndex, endIndex).inl;

  @override
  InlineLogic zeroExtend(int newWidth) => super.zeroExtend(newWidth).inl;

  @override
  InlineLogic signExtend(int newWidth) => super.signExtend(newWidth).inl;
}

// ---------------------------------------------------------------------------
// Operations
// ---------------------------------------------------------------------------

/// Inlineable arithmetic, available on any [Logic].
///
/// These do not require the receiver to be an [InlineLogic] — the module is
/// selected by the call, not by the operand's type.
extension InlineOps on Logic {
  /// Reinterprets this signal as an [InlineLogic].
  ///
  /// Free: the wrapper is an unnamed (mergeable) signal, so it collapses into
  /// its source and leaves no trace in the generated SystemVerilog.
  InlineLogic get inl {
    final self = this;
    return self is InlineLogic
        ? self
        : (InlineLogic(width: width)..gets(self));
  }

  /// `this + other`, discarding the carry. Drop-in for ROHD's `+`.
  ///
  /// [other] may be a [Logic] of equal width, or a constant.
  InlineLogic add(dynamic other) =>
      _InlineAdd(this, _operand(other, width)).result;

  /// `this + other` keeping the carry as the most significant result bit.
  ///
  /// Result width is `max(this.width, other.width) + 1`.
  InlineLogic addWide(dynamic other) =>
      _InlineAddWide(this, _operand(other, width, strictWidth: false)).result;

  /// `this * other` keeping the full product.
  ///
  /// Result width is `this.width + other.width`.
  InlineLogic mulWide(dynamic other) =>
      _InlineMulWide(this, _operand(other, width, strictWidth: false)).result;
}

/// Coerces an operand to a [Logic], applying ROHD's own width rules.
Logic _operand(dynamic other, int width, {bool strictWidth = true}) {
  if (other is Logic) {
    if (strictWidth && other.width != width) {
      // Match stock ROHD: refuse to guess how to align mismatched widths,
      // because `Logic` carries no signedness.
      throw PortWidthMismatchException.equalWidth(
          Logic(width: width), other);
    }
    return other;
  }

  assert(
    _fitsIn(other, width),
    'Constant $other does not fit in $width bits;'
    ' it would be silently truncated.',
  );
  return Const(other, width: width);
}

bool _fitsIn(dynamic value, int width) {
  if (value is! int) {
    return true; // LogicValue and friends carry their own width.
  }
  final limit = BigInt.one << width;
  final v = BigInt.from(value);
  // Accept both unsigned [0, 2^w) and two's-complement [-2^(w-1), 2^(w-1)).
  return (v >= BigInt.zero && v < limit) || (v < BigInt.zero && -v <= limit);
}

/// Prefix spellings of [InlineOps], for when neither operand should read as
/// privileged.
InlineLogic inlineAdd(Logic a, dynamic b) => a.add(b);

/// See [InlineOps.addWide].
InlineLogic inlineAddWide(Logic a, dynamic b) => a.addWide(b);

/// See [InlineOps.mulWide].
InlineLogic inlineMulWide(Logic a, dynamic b) => a.mulWide(b);

// ---------------------------------------------------------------------------
// Constants on the left
// ---------------------------------------------------------------------------

/// A constant awaiting a right-hand operand to determine its width.
///
/// Dart cannot dispatch `1 + someLogic` to us — `int.operator +` already exists
/// and only accepts `num`, and an extension may not shadow an existing member.
/// So the constant is deferred until it meets a [Logic].
class InlineConst {
  final Object _value;
  const InlineConst(this._value);

  /// The constant stays on the left in the generated SystemVerilog too, which
  /// is the whole point of writing it there.
  InlineLogic operator +(Logic other) =>
      Const(_value, width: other.width).add(other);
}

/// Lets a constant sit on the left of `+`, taking its width from the right.
extension InlineOnInt on int {
  /// `1.inl + val` — equivalent to `val + 1`, but with the constant written
  /// first.
  InlineConst get inl => InlineConst(this);
}
