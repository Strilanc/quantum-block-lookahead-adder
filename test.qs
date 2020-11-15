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
                let a = DrawRandomBitString(n);
                let b = DrawRandomBitString(n);
                let A = LittleEndian(data[0..n-1]);
                let B = LittleEndian(data[n..2*n-1]);
                let C = LittleEndian(data[2*n..3*n-1]);
                ApplyXorInPlaceL(a, A);
                ApplyXorInPlaceL(b, B);
                init_add(A, B, C);
                let actual = MeasureLE(C);
                let expected = (a + b) % m;
                Message($"TESTING A={a}, B={b}, a+b={actual}, pass={actual == expected}");
                ApplyXorInPlaceL(a, A);
                ApplyXorInPlaceL(b, B);
                ApplyXorInPlaceL(expected, C);
            }
        }
        Message("Passed.");
    }
}
