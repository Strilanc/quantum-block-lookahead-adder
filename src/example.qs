namespace CG {
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

        // Perform carry lookahead addition using quantum operations.
        using (data = Qubit[register_size*2]) {
            // Prepare inputs.
            let qa = LittleEndian(data[...register_size-1]);
            let qb = LittleEndian(data[register_size...]);
            ApplyXorInPlaceL(a, qa);
            ApplyXorInPlaceL(b, qb);

            // Compute sum.
            add_into_using_carry_lookahead(qa, qb);

            // Check the result.
            let actual_sum = MeasureLE(qb);
            Message($"  actual_sum={actual_sum}");
            if (actual_sum != expected_sum) {
                fail "Adder returned the wrong answer!";
            }

            // Zero registers before deallocating.
            ApplyXorInPlaceL(a, qa);
            ApplyXorInPlaceL(actual_sum, qb);
        }
    }
}
