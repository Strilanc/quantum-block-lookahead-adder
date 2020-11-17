namespace CG {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    /// Initializes out_sum to equal a+b, in linear depth.
    ///
    /// To set an input carry, adjust the first qubit of `out_sum` before calling.
    /// To get an output carry, increase the length of `out_sum` by 1.
    ///
    /// Assumes:
    ///     Length(a) == Length(b)
    ///     Length(a) <= Length(out_sum) <= Length(a) + 1
    ///     MeasureLE(out_sum[1...]) == 0L
    ///
    /// Budget:
    ///     Additional Workspace: 0
    ///     Reaction Depth: 2*n
    ///     Toffoli Count: n
    ///     Toffoli Count (uncomputing): 0
    ///     where n = Length(a)
    operation init_sum_using_ripple_carry(
            a: LittleEndian,
            b: LittleEndian,
            out_sum: LittleEndian) : Unit is Adj {
        let n = Length(a!);
        if (Length(b!) != n) {
            fail "Length(b!) != Length(a!)";
        }
        if (Length(out_sum!) != n and Length(out_sum!) != n + 1) {
            fail "Length(out_sum!) != Length(a!) and Length(out_sum!) != Length(a!) + 1";
        }
        for (k in 0..Length(out_sum!)-2) {
            init_full_adder_step(a![k], b![k], out_sum![k], out_sum![k+1]);
        }
        if (n > 0 and n == Length(out_sum!)) {
            CNOT(a![n - 1], out_sum![n - 1]);
            CNOT(b![n - 1], out_sum![n - 1]);
        }
    }

    // Performs LittleEndian([mut_c_to_out_1, out_2]) := a + b + mut_c_to_out_1
    operation init_full_adder_step(a: Qubit, b: Qubit, mut_c_to_out_1: Qubit, out_2: Qubit) : Unit is Adj {
        CNOT(a, b);
        CNOT(a, mut_c_to_out_1);
        init_and(b, mut_c_to_out_1, out_2);
        CNOT(a, b);
        CNOT(a, out_2);
        CNOT(b, mut_c_to_out_1);
    }
}
