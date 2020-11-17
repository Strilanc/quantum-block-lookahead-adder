namespace CG {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    /// Initializes out_sum to equal a+b, in slightly better linear depth.
    ///
    /// Assumes:
    ///     Length(a) == Length(b)
    ///     Length(a) <= Length(out_sum) <= Length(a) + 1
    ///     MeasureLE(out_sum) == 0L
    ///
    /// Budget:
    ///     Additional Workspace: n
    ///     Reaction Depth: n + O(1)
    ///     Toffoli Count: 2*n
    ///     Toffoli Count (uncomputing): n
    ///     where n = Length(a)
    operation init_sum_using_two_block(
            a: LittleEndian,
            b: LittleEndian,
            out_c: LittleEndian) : Unit is Adj {
        let n = Length(a!);
        let h = (n + 1) / 2;
        let h2 = n - h;
        let a_low = LittleEndian(a![...h-1]);
        let b_low = LittleEndian(b![...h-1]);
        let c_low = LittleEndian(out_c![...h-1]);
        let a_high = LittleEndian(a![h...]);
        let b_high = LittleEndian(b![h...]);
        let c_high = LittleEndian(out_c![h...]);

        using (c_low_carry = Qubit()) {
            using (tmp = Qubit[h2*2]) {
                let tmp_high0 = LittleEndian(tmp[...h2 - 1]);
                let tmp_high1 = LittleEndian(tmp[h2...]);
                if (h2 > 0) {
                    X(tmp_high1![0]);
                }

                // Compute the low case and the two high cases in parallel.
                init_sum_using_ripple_carry(a_low, b_low, LittleEndian(c_low! + [c_low_carry]));
                init_sum_using_ripple_carry(a_high, b_high, tmp_high0);
                init_sum_using_ripple_carry(a_high, b_high, tmp_high1);

                // Choose between the two high cases using the carry output of the low case.
                // In parallel, uncompute the high cases.
                for (k in h2-1..-1..0) {
                    CNOT(tmp_high1![k], tmp_high0![k]);
                    init_and(c_low_carry, tmp_high0![k], c_high![k]);
                    CNOT(tmp_high1![k], tmp_high0![k]);
                    CNOT(tmp_high0![k], c_high![k]);
                }
                Adjoint init_sum_using_ripple_carry(a_high, b_high, tmp_high0);
                Adjoint init_sum_using_ripple_carry(a_high, b_high, tmp_high1);

                // Uncompute c_low_carry.
                if (h > 0) {
                    Adjoint init_full_adder_step(
                        a_low![h-1],
                        b_low![h-1],
                        c_low![h-1],
                        c_low_carry);
                    CNOT(a_low![h-1], c_low![h-1]);
                    CNOT(b_low![h-1], c_low![h-1]);
                }
                if (h2 > 0) {
                    X(tmp_high1![0]);
                }
            }
        }
    }
}
