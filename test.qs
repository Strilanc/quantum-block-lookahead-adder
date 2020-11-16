namespace CG {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    @EntryPoint()
    operation TestAdder() : Unit {
        let n = 100;
        let m = LeftShiftedL(1L, n);
        for (attempt in 0..10) {
            using (data = Qubit[3*n]) {
                Message($"TESTING");

                let a = DrawRandomBitString(n);
                let A = LittleEndian(data[0..n-1]);
                ApplyXorInPlaceL(a, A);
                Message($"A={a}");

                let b = DrawRandomBitString(n);
                let B = LittleEndian(data[n..2*n-1]);
                ApplyXorInPlaceL(b, B);
                Message($"B={b}");

                let OUT = LittleEndian(data[2*n..3*n-1]);
                init_add(A, B, OUT);
                let actual = MeasureLE(OUT);
                let expected = (a + b) % m;
                Message($"expected a+b={expected}");
                Message($"actual a+b  ={actual}");
                Message($"pass={actual == expected}");

                ApplyXorInPlaceL(a, A);
                ApplyXorInPlaceL(b, B);
                ApplyXorInPlaceL(expected, OUT);
            }
        }
        Message("Passed.");
    }
}
