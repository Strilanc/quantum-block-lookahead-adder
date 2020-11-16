namespace CG.Tests {
    
    open CG;
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Diagnostics;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    @Test("ToffoliSimulator")
    operation FuzzTestAddition() : Unit {
        FuzzTestAdditionLength(0, 1);
        FuzzTestAdditionLength(1, 2);
        FuzzTestAdditionLength(2, 2);
        FuzzTestAdditionLength(3, 2);
        FuzzTestAdditionLength(4, 2);
        FuzzTestAdditionLength(100, 5);
        FuzzTestAdditionLength(127, 5);
        FuzzTestAdditionLength(128, 5);
        FuzzTestAdditionLength(129, 5);
    }

    operation FuzzTestAdditionLength(n: Int, attempts: Int) : Unit {
        for (k in 1..attempts) {
            let a = DrawRandomBitString(n);
            let b = DrawRandomBitString(n);
            CheckAdditionCase(n, a, b);
        }
    }

    operation CheckAdditionCase(n: Int, a: BigInt, b: BigInt) : Unit {
        let m = LeftShiftedL(1L, n);
        using (data = Qubit[3*n]) {
            let qa = LittleEndian(data[0..n-1]);
            let qb = LittleEndian(data[n..2*n-1]);
            ApplyXorInPlaceL(a, qa);
            ApplyXorInPlaceL(b, qb);

            let qsum = LittleEndian(data[2*n..3*n-1]);
            init_sum_using_carry_lookahead(qa, qb, qsum);
            let actual = MeasureLE(qsum);
            let expected = (a + b) % m;
            if (actual != expected) {
                fail $"Wrong sum. actual {actual} != expected {expected}";
            }

            ApplyXorInPlaceL(a, qa);
            ApplyXorInPlaceL(b, qb);
            ApplyXorInPlaceL(actual, qsum);
        }
    }
}