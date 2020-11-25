namespace CG {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    /// Performs `target += input` in logarithmic depth.
    ///
    /// Assumes:
    ///     Length(target) == Length(input)
    ///
    /// Budget:
    ///     Toffoli Count: 7*n
    ///     Reaction Depth: 4*lg(n) + O(1)
    ///     Workspace: 2*n + O(1)
    ///     where n = Length(target)
    ///
    /// Reference:
    ///     "T-count and Qubit Optimized Quantum Circuit Designs of Carry
    ///          Lookahead Adder"
    ///     Himanshu Thapliyal, Edgard Muñoz-Coreas, Vladislav Khalus
    ///     https://arxiv.org/abs/2004.01826
    operation add_into_using_carry_lookahead(
            input: LittleEndian,
            target: LittleEndian) : Unit is Adj {
        add_into_using(init_sum_using_carry_lookahead, input, target);
    }

    /// Performs `out_c := a+b` in logarithmic depth.
    ///
    /// Assumes:
    ///     Length(a) == Length(b)
    ///     Length(a) == Length(out_c)
    ///     MeasureLE(out_c) == 0L
    ///
    /// Budget:
    ///     Toffoli Count: 4*n
    ///     Toffoli Count (uncomputing): 3*n
    ///     Reaction Depth: 2*lg(n) + O(1)
    ///     Workspace: n + O(1)
    ///     where n = Length(a)
    ///
    /// Reference:
    ///     "T-count and Qubit Optimized Quantum Circuit Designs of Carry
    ///          Lookahead Adder"
    ///     Himanshu Thapliyal, Edgard Muñoz-Coreas, Vladislav Khalus
    ///     https://arxiv.org/abs/2004.01826
    operation init_sum_using_carry_lookahead(
            a: LittleEndian,
            b: LittleEndian,
            out_c: LittleEndian) : Unit is Adj {
        let n = Length(a!);

        // Create initial `generate` and `propagate` values.
        for (k in 0..n-1) {
            if (k + 1 < Length(out_c!)) {
                init_and(a![k], b![k], out_c![k + 1]);
            }
            CNOT(a![k], b![k]);
        }

        // Fuse `generate` and `propagate` values into the final carries.
        _prop_gen(b!, out_c!);

        // Finish off the sum and restore b.
        for (k in 0..n-1) {
            CNOT(b![k], out_c![k]);
            CNOT(a![k], b![k]);
        }
    }

    /// Finds the `propagate` qubit for the given range.
    function _range_p_storage(ps: Qubit[], range: Range) : Qubit {
        let start = RangeStart(range);
        let end = RangeEnd(range);
        if (end == start + 1) {
            return ps[start];
        }
        return ps[(Length(ps) + start + end) / 2];
    }

    /// Finds the `generate` qubit for the given range.
    /// Note qubits are re-used for multiple ranges.
    function _range_g_storage(out_c: Qubit[], range: Range) : Qubit {
        let start = RangeStart(range);
        let end = RangeEnd(range);
        if (end == start + 1) {
            return out_c[end];
        }
        mutable i = (start + end) / 2;
        for (v in PowerOfTwoness(i)-1..-1..0) {
            let m = 1 <<< v;
            if (i + m < Length(out_c)) {
                set i += m;
            }
        }
        return out_c[i + 1];
    }

    /// Propagates local `generate` values into global `generate` values.
    ///
    /// Example:
    ///       propagates = ...111...1...1.....
    ///      mut_gs (in) = .....1...1......1..
    ///     mut_gs (out) = ..1111..11......1..
    ///
    /// Arguments:
    ///     propagates: Local `propagate` values. If the bit at index i is set,
    ///         then a `generate` signal at bit index i should propagate up to
    ///         bit index i + 1.
    ///     mut_gs: Initial local `generate` values, which will be mutated into
    ///         the global propagated `generate` values. If the bit at index i
    ///         is set at input time, that means the carry-out of the range
    ///         i-1..i is 1 regardless of its carry-in. If the bit at index i
    ///         is set at output time, that means the carry-out of the range
    ///         0..i is set regarldess of its carry-in.
    ///
    /// Assumes:
    ///     Length(mut_gs) == Length(propagates)
    ///     ((Measure(propagates) <<< 1) &&& Measure(mut_gs)) == 0
    ///
    /// Budget:
    ///     Toffoli Count: 3*n
    ///     Reaction Depth: 2*lg(n) + O(1)
    ///     Workspace: n
    ///     where n = Length(mut_gs)
    ///
    /// Reference:
    ///     "T-count and Qubit Optimized Quantum Circuit Designs of Carry
    ///          Lookahead Adder"
    ///     Himanshu Thapliyal, Edgard Muñoz-Coreas, Vladislav Khalus
    ///     https://arxiv.org/abs/2004.01826
    operation _prop_gen(propagates: Qubit[], mut_gs: Qubit[]) : Unit is Adj {
        let n = Length(propagates);
        using (workspace = Qubit[n]) {
            let p = _range_p_storage(propagates + workspace, _);
            let g = _range_g_storage(mut_gs, _);
            for (step in PowersOfTwoBelow(n)) {
                for (i in 0..2*step..n) {
                    let j = i + step;
                    let k = j + step;
                    if (k < n) {
                        init_and(p(i..j), p(j..k), p(i..k));
                        CCNOT(g(i..j), p(j..k), g(i..k));
                    }
                }
            }
            for (step in (PowersOfTwoBelow(n))[...-1...]) {
                for (i in 0..2*step..n) {
                    let j = i + step;
                    let k = j + step;
                    if (k < n) {
                        Adjoint init_and(p(i..j), p(j..k), p(i..k));
                    }
                    if (j < n) {
                        CCNOT(g(i-1..i), p(i..j), g(i..j));
                    }
                }
            }
        }
    }
}
