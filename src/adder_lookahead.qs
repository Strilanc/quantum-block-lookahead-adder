namespace CG {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    /// Performs target += input.
    ///
    /// Assumes:
    ///     Length(target) == Length(input)
    ///
    /// Budget:
    ///     Toffoli Count: 7*n
    ///     Reaction Depth: 4*lg(n) + O(1)
    ///     Additional Workspace: 4*n + O(1)
    ///     where n = Length(target)
    operation add_into_using_carry_lookahead(
            input: LittleEndian,
            target: LittleEndian) : Unit is Adj {
        add_into_using(init_sum_using_carry_lookahead, input, target);
    }

    /// Initializes out_c to equal a+b, in logarithmic depth.
    ///
    /// Assumes:
    ///     Length(a) == Length(b)
    ///     Length(a) == Length(out_c)
    ///     MeasureLE(out_c) == 0L
    ///
    /// Budget:
    ///     Additional Workspace: 3*n + O(1)
    ///     Reaction Depth: 2*lg(n) + O(1)
    ///     Toffoli Count: 4*n
    ///     Toffoli Count (uncomputing): 3*n
    ///     where n = Length(a)
    operation init_sum_using_carry_lookahead(
            a: LittleEndian,
            b: LittleEndian,
            out_c: LittleEndian) : Unit is Adj {
        let n = Length(a!);
        using (unit_carries = Qubit[n]) {
            within {
                for (k in 0..(n-1)) {
                    // Init unit length range carry data.
                    init_and(a![k], b![k], unit_carries[k]);
                    // Init unit length range threshold data (into b).
                    CNOT(a![k], b![k]);
                }
            } apply {
                _init_propagated_carries(unit_carries, b!, out_c!);
            }

            for (k in 0..(n-1)) {
                CNOT(a![k], out_c![k]);
                CNOT(b![k], out_c![k]);
            }
        }
    }

    /// Propagates local carries and thresholds into final carries in logarithmic depth.
    ///
    /// Args:
    ///     unit_carries: Whether or not each bit position produced a carry. The bitwise AND of
    ///         the two inputs to add.
    ///     unit_thresholds: Whether or not each bit position will produce a new carry if a
    ///         carry propagates into that position. The bitwise XOR of the two inputs to add.
    ///     out_propagated_carries: A zero'd register to write the final fully-propagated
    ///         carry data into. This value will end up equal to A xor B xor (A + B).
    ///
    /// Assumes:
    ///     Length(unit_carries) == Length(unit_thresholds)
    ///     Length(unit_carries) == Length(out_propagated_carries)
    ///     MeasureLE(out_propagated_carries) == 0L
    ///
    /// Budget:
    ///     Additional Workspace: 2*n + O(1)
    ///     Reaction Depth: 2*lg(n) + O(1)
    ///     Toffoli Count: 3*n
    ///     Toffoli Count (uncomputing): 2*n
    ///     where n = Length(unit_carries)
    operation _init_propagated_carries(
            unit_carries: Qubit[],
            unit_thresholds: Qubit[],
            out_propagated_carries: Qubit[]) : Unit is Adj {
        let n = Length(unit_carries);
        using (centered_thresholds = Qubit[n]) {
            using (centered_carries = Qubit[n]) {
                within {
                    // Note: the uncomputation of this block can be almost entirely overlapped
                    // with the apply body. This lowers the reaction depth by ~33%.
                    _init_centered_range_data(
                        unit_carries,
                        unit_thresholds,
                        centered_carries,
                        centered_thresholds);
                } apply {
                    for (t in CeilLg2(n)-1..-1..0) {
                        let step = 1 <<< t;
                        for (a in 0..step*2..n-step-1) {
                            let b = a + step;
                            let c_a2b = _mux(a, b, unit_carries, centered_carries);
                            let t_a2b = _mux(a, b, unit_thresholds, centered_thresholds);
                            init_and(t_a2b, out_propagated_carries[a], out_propagated_carries[b]);
                            CNOT(c_a2b, out_propagated_carries[b]);
                        }
                    }
                }
            }
        }
    }

    /// Initializes range data about centered ranges.
    /// (See definitions in documentation of _mux)
    ///
    /// Args:
    ///     unit_carries: Carry data for unit length ranges.
    ///     unit_thresholds: Threshold data for unit length ranges.
    ///     out_centered_carries: Location to store carry data for centered ranges.
    ///     out_centered_thresholds: Location to store threshold data for centered ranges.
    ///
    /// Assumes:
    ///     Length(unit_carries) == Length(unit_thresholds)
    ///     Length(unit_carries) == Length(out_centered_carries)
    ///     Length(unit_carries) == Length(out_centered_thresholds)
    ///     MeasureLE(out_centered_carries) == 0L
    ///     MeasureLE(out_centered_thresholds) == 0L
    ///
    /// Budget:
    ///     Additional Workspace: O(1)
    ///     Reaction Depth: lg(n)
    ///     Toffoli Count: 2*n
    ///     Toffoli Count (uncomputing): 0
    ///     where n = Length(unit_carries)
    operation _init_centered_range_data(
            unit_carries: Qubit[],
            unit_thresholds: Qubit[],
            out_centered_carries: Qubit[],
            out_centered_thresholds: Qubit[]) : Unit is Adj {
        let n = Length(unit_thresholds);
        let p = CeilLg2(n);
        for (t in 0..CeilLg2(n)-2) {
            let step = 1 <<< t;
            for (a in 0..step * 2..n-step * 2 - 1) {
                _init_centered_datum_by_fusing(
                    a,
                    a + step,
                    a + step * 2,
                    unit_carries,
                    unit_thresholds,
                    out_centered_carries,
                    out_centered_thresholds);
            }
        }
    }

    /// Combines range data about `a..b` and `b..c` to create range data about `a..c`.
    ///
    /// Args:
    ///     a: The start of the first range.
    ///     b: The end of the first range and also the start of the second range.
    ///     c: The end of the second range.
    ///     unit_carries: Carry data for unit length ranges.
    ///     unit_thresholds: Threshold data for unit length ranges.
    ///     centered_carries: Carry data for centered ranges.
    ///     centered_thresholds: Threshold data for centered ranges.
    ///
    /// Assumes:
    ///     Length(initial) == Length(mid)
    ///     a..b is a unit length range or a centered range
    ///     b..c is a unit length range or a centered range
    ///     a..c is a centered range
    ///     (See definitions in documentation of _mux)
    ///
    /// Budget:
    ///     Additional Workspace: O(1)
    ///     Reaction Depth: 1
    ///     Toffoli Count: 2
    ///     Toffoli Count (uncomputing): 0
    operation _init_centered_datum_by_fusing(
            a: Int,
            b: Int,
            c: Int,
            unit_carries: Qubit[],
            unit_thresholds: Qubit[],
            centered_carries: Qubit[],
            centered_thresholds: Qubit[]) : Unit is Adj {
        let c_a2b = _mux(a, b, unit_carries, centered_carries);
        let t_a2b = _mux(a, b, unit_thresholds, centered_thresholds);
        let c_b2c = _mux(b, c, unit_carries, centered_carries);
        let t_b2c = _mux(b, c, unit_thresholds, centered_thresholds);
        init_and(t_b2c, c_a2b, centered_carries[b]);
        init_and(t_b2c, t_a2b, centered_thresholds[b]);
        CNOT(c_b2c, centered_carries[b]);
    }

    /// Helper method for reading data about a range.
    ///
    /// Definitions:
    ///     Unit length range: A range of the form `a..a+1`.
    ///     Centered range: A range of the form `m-s..m+s` where `s` is the largest
    ///         power of 2 that divides `m`. In arrays, data about the centered range
    ///         `m-s..m+s` is stored at offset `m`.
    ///
    /// Args:
    ///     start: The inclusive start of the range.
    ///     end: The inclusive end of the range.
    ///     unit_data: Data for unit length ranges.
    ///     centered_data: Data for centered ranges.
    ///
    /// Assumes:
    ///     Length(initial) == Length(mid)
    ///     start..end is a unit length range or a centered range.
    function _mux(start: Int, end: Int, unit_data: Qubit[], centered_data: Qubit[]) : Qubit {
        if (end == start + 1) {
            return unit_data[start];
        }
        return centered_data[(start + end) / 2];
    }
}
