namespace CG {
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Random;

    /// Initializes out_c to equal a+b, in blocksize + log(n/block_size) depth.
    ///
    /// Assumes:
    ///     blocksize > 0 or Length(a) == 0
    ///     Length(a) == Length(b)
    ///     Length(a) == Length(out_c)
    ///     MeasureLE(out_c) == 0L
    ///
    /// Budget:
    ///     Toffoli Count: 3*n - 2*b + 5*n/b + O(1)
    ///     Toffoli Count (uncomputing): 2*n - 2*b + 5*n/b + O(1)
    ///     Reaction Depth: 3*b + 4*lg(n/b) + O(1)
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

    /// Initializes out_c to equal a+b, in blocksize + log(n/block_size) depth.
    ///
    /// Assumes:
    ///     Length(a) == Length(b)
    ///     Length(a) == Length(out_c)
    ///     MeasureLE(out_c) == 0L
    ///
    /// Budget:
    ///     Toffoli Count: 3*n + 3*sqrt(n) + O(1)
    ///     Toffoli Count (uncomputing): 2*n + 3*sqrt(n) + O(1)
    ///     Reaction Depth: 3*sqrt(n) + 2*lg(n) + O(1)
    ///     Workspace: 2*n + 3*sqrt(n) + O(1)
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
    ///     Toffoli Count (uncomputing): 2*n - 2*b + 5*n/b + O(1)
    ///     Reaction Depth: 3*b + 4*lg(n/b) + O(1)
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
            let mux_blocks_0 = [new Qubit[0]] + Chunks(block_size, mux_0);
            let mux_blocks_1 = [new Qubit[0]] + Chunks(block_size, mux_1);

            // Only one low block case. Computed in parallel with the high cases.
            init_sum_using_ripple_carry(
                LittleEndian(a_blocks[0]),
                LittleEndian(b_blocks[0]),
                LittleEndian(c_blocks[0] + [carries_0[0]]));
            within {
                // Set carry-in.
                for (k in 1..Length(mux_blocks_1)-1) {
                    X(mux_blocks_1[k][0]);
                }

                // Compute carry-in and not-carry-in cases in parallel.
                for (k in 1..m-1) {
                    let stop = k == m - 1 ? -1 | 0;
                    mutable m0 = mux_blocks_0[k] + [carries_0[k]][...stop];
                    mutable m1 = mux_blocks_1[k] + [carries_1[k]][...stop];
                    for (t in [m0, m1]) {
                        init_sum_using_ripple_carry(
                            LittleEndian(a_blocks[k]),
                            LittleEndian(b_blocks[k]),
                            LittleEndian(t));
                    }
                }
                
                // Convert carries_1 from carry-out-if-carry-in to on-carry-threshold.
                for (k in 1..m-1) {
                    CNOT(carries_0[k], carries_1[k]);
                }

                // Determine propagated carries using carry-lookahead.
                let gen = carries_0;
                let prop = carries_1;
                _prop_gen(prop[1...] + prop[...0], gen);
            } apply {
                for (k in 1..m-1) {
                    init_choose(
                        carries_0[k - 1],
                        mux_blocks_0[k], 
                        mux_blocks_1[k], 
                        c_blocks[k]);
                }
            }

            // Uncompute carries_0[0] while keeping the rest of the sum.
            Adjoint init_full_adder_step(
                a_blocks[0][block_size-1],
                b_blocks[0][block_size-1],
                c_blocks[0][block_size-1],
                carries_0[0]);
            CNOT(a_blocks[0][block_size-1], c_blocks[0][block_size-1]);
            CNOT(b_blocks[0][block_size-1], c_blocks[0][block_size-1]);
        }
    }
}
