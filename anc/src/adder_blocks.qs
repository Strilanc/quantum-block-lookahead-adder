namespace BlockAdder {
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Random;

    /// Perform `out_c := a+b` in O(block_size + lg(n)) depth.
    ///
    /// Assumes:
    ///     blocksize > 0 or Length(a) == 0
    ///     Length(a) == Length(b)
    ///     Length(a) == Length(out_c)
    ///     MeasureLE(out_c) == 0L
    ///
    /// Budget:
    ///     Toffoli Count: 3*n - 2*b + 5*n/b + O(1)
    ///     Toffoli Count (uncomputing): 2*n - 2*b + 3*n/b + O(1)
    ///     Reaction Depth: 3*b + 2*lg(n/b) + O(1)
    ///     Workspace: 2*n + 3*n/b + O(1)
    ///     where n = Length(a)
    ///     where b = block_size
    operation init_sum_using_blocks(
            block_size: Int,
            a: LittleEndian,
            b: LittleEndian,
            out_c: LittleEndian) : Unit is Adj {
        if (Length(a!) <= block_size) {
            init_sum_using_ripple_carry(a, b, out_c);
        } else {
            _init_sum_using_blocks_helper(block_size, a, b, out_c);
        }
    }

    /// Perform `out_c := a+b` in O(sqrt(n)) depth.
    ///
    /// Assumes:
    ///     Length(a) == Length(b)
    ///     Length(a) == Length(out_c)
    ///     MeasureLE(out_c) == 0L
    ///
    /// Budget:
    ///     Toffoli Count: 3*n + 3*sqrt(n)
    ///     Toffoli Count (uncomputing): 2*n + sqrt(n)
    ///     Reaction Depth: 3*sqrt(n) + lg(n) + O(1)
    ///     Workspace: 2*n + 3*sqrt(n)
    ///     where n = Length(a)
    operation init_sum_using_square_root_blocks(
            a: LittleEndian,
            b: LittleEndian,
            out_c: LittleEndian) : Unit is Adj {
        let block_size = CeilSqrt(Length(a!));
        init_sum_using_blocks(block_size, a, b, out_c);
    }

    /// Budget:
    ///     Toffoli Count: 3*n - 2*b + 5*n/b + O(1)
    ///     Toffoli Count (uncomputing): 2*n - 2*b + 3*n/b + O(1)
    ///     Reaction Depth: 3*b + 2*lg(n/b) + O(1)
    ///     Workspace: 2*n + 3*n/b + O(1)
    ///     where n = Length(a)
    ///     where b = block_size
    operation _init_sum_using_blocks_helper(
            block_size: Int,
            a: LittleEndian,
            b: LittleEndian,
            out_c: LittleEndian) : Unit is Adj {
        let a_blocks = Chunks(block_size, a!);
        let b_blocks = Chunks(block_size, b!);
        let c_blocks = Chunks(block_size, out_c!);
        let n = Length(a!);
        let m = Length(a_blocks);

        using ((carries_0, carries_1, mux_0, mux_1) = (
                Qubit[m], 
                Qubit[m], 
                Qubit[n - block_size], 
                Qubit[n - block_size])) {
            let case_blocks_0 = [new Qubit[0]] + Chunks(block_size, mux_0);
            let case_blocks_1 = [new Qubit[0]] + Chunks(block_size, mux_1);

            // Only one low block case. Compute in parallel with the high cases.
            init_sum_using_ripple_carry(
                LittleEndian(a_blocks[0]),
                LittleEndian(b_blocks[0]),
                LittleEndian(c_blocks[0] + [carries_0[0]]));
            within {
                // Set the carry-in bits of case_blocks_1.
                for (k in 1..Length(case_blocks_1)-1) {
                    X(case_blocks_1[k][0]);
                }

                // Compute carry-in-cleared and carry-in-set cases in parallel.
                for (k in 1..m-1) {
                    let stop = k == m - 1 ? -1 | 0;
                    mutable m0 = case_blocks_0[k] + [carries_0[k]][...stop];
                    mutable m1 = case_blocks_1[k] + [carries_1[k]][...stop];
                    for (t in [m0, m1]) {
                        init_sum_using_ripple_carry(
                            LittleEndian(a_blocks[k]),
                            LittleEndian(b_blocks[k]),
                            LittleEndian(t));
                    }
                }
                
                // Currently carries_0 is local `generate` signals.
                // Convert carries_1 into local `propagate` signals.
                for (k in 1..m-1) {
                    CNOT(carries_0[k], carries_1[k]);
                }
            } apply {
                // Determine propagated carries using carry-lookahead strategy.
                _prop_gen(carries_1[1...] + carries_1[...0], carries_0);

                // Use propagated carries to pick which blocks to keep.
                for (k in 1..m-1) {
                    init_choose(
                        carries_0[k - 1],
                        case_blocks_0[k],
                        case_blocks_1[k],
                        c_blocks[k]);
                }

                // Clear propagated carries.
                for (k in 1..m-1) {
                    CNOT(a_blocks[k][0], carries_0[k-1]);
                    CNOT(b_blocks[k][0], carries_0[k-1]);
                    CNOT(c_blocks[k][0], carries_0[k-1]);
                }

                // Restore carries_0 (except for carries_0[0] left zero).
                for (k in 1..m-2) {
                    let af = Last(a_blocks[k]);
                    let bf = Last(b_blocks[k]);
                    let cf = Last(case_blocks_0[k]);
                    let tf = carries_0[k];
                    within {
                        X(cf);
                        CNOT(af, bf);
                        CNOT(af, cf);
                    } apply {
                        init_and(bf, cf, tf);
                        CNOT(af, tf);
                    }
                }
            }
        }
    }
}
