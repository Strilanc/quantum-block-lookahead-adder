namespace BlockAdder {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    @EntryPoint()
    operation ExampleAdderUsage() : Unit {
        // Note: have to run this using the Toffoli simulator.

        // Pick the problem.
        let register_size = 100;
        let a = 314159265358979323846264338L;
        let b = 271828182845904523536028747L;
        Message($"           a={a}");
        Message($"           b={b}");

        // Sanity checks.
        let mod = 1L <<< register_size;
        if (a >= mod or b >= mod) {
            fail "register_size is too small.";
        }
        let expected_sum = (a + b) % mod;
        Message($"expected_sum={expected_sum}");

        using ((qa_raw, qb_raw, qsum_raw) = (
            // Allocate registers.
                Qubit[register_size],
                Qubit[register_size],
                Qubit[register_size])) {
            let qa = LittleEndian(qa_raw);
            let qb = LittleEndian(qb_raw);
            let qsum = LittleEndian(qsum_raw);

            within {
                // Prepare inputs.
                ApplyXorInPlaceL(a, qa);
                ApplyXorInPlaceL(b, qb);

                // Compute the sum.
                init_sum_using_blocks(4, qa, qb, qsum);
            } apply {
                // Check the result.
                let actual_sum = MeasureLE(qsum);
                Message($"  actual_sum={actual_sum}");
                Message($"       match={actual_sum == expected_sum}");
            }
        }
    }
}
