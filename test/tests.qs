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
    operation FuzzTestInitAddition() : Unit {
        FuzzTestInitAdditionLength(0, 1);
        FuzzTestInitAdditionLength(1, 2);
        FuzzTestInitAdditionLength(2, 2);
        FuzzTestInitAdditionLength(3, 2);
        FuzzTestInitAdditionLength(4, 2);
        FuzzTestInitAdditionLength(100, 5);
        FuzzTestInitAdditionLength(127, 5);
        FuzzTestInitAdditionLength(128, 5);
        FuzzTestInitAdditionLength(129, 5);
    }

    @Test("ToffoliSimulator")
    operation FuzzTestInPlaceAddition() : Unit {
        FuzzTestInPlaceAdditionLength(0, 1);
        FuzzTestInPlaceAdditionLength(1, 2);
        FuzzTestInPlaceAdditionLength(2, 2);
        FuzzTestInPlaceAdditionLength(3, 2);
        FuzzTestInPlaceAdditionLength(4, 2);
        FuzzTestInPlaceAdditionLength(100, 5);
        FuzzTestInPlaceAdditionLength(127, 5);
        FuzzTestInPlaceAdditionLength(128, 5);
        FuzzTestInPlaceAdditionLength(129, 5);
    }

    operation FuzzTestInitAdditionLength(n: Int, attempts: Int) : Unit {
        for (k in 1..attempts) {
            let a = DrawRandomBitString(n);
            let b = DrawRandomBitString(n);
            CheckInitAdditionCase(n, a, b);
        }
    }

    operation FuzzTestInPlaceAdditionLength(n: Int, attempts: Int) : Unit {
        for (k in 1..attempts) {
            let a = DrawRandomBitString(n);
            let b = DrawRandomBitString(n);
            CheckInPlaceAdditionCase(n, a, b);
        }
    }

    operation CheckInitAdditionCase(n: Int, a: BigInt, b: BigInt) : Unit {
        let m = LeftShiftedL(1L, n);
        using (data = Qubit[3*n]) {
            let qa = LittleEndian(data[...n-1]);
            let qb = LittleEndian(data[n..2*n-1]);
            ApplyXorInPlaceL(a, qa);
            ApplyXorInPlaceL(b, qb);

            let qsum = LittleEndian(data[2*n...]);
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

    operation CheckInPlaceAdditionCase(n: Int, input: BigInt, target: BigInt) : Unit {
        let m = LeftShiftedL(1L, n);
        using (data = Qubit[2*n]) {
            let qinput = LittleEndian(data[...n-1]);
            let qtarget = LittleEndian(data[n...]);
            ApplyXorInPlaceL(input, qinput);
            ApplyXorInPlaceL(target, qtarget);

            add_into_using_carry_lookahead(qinput, qtarget);
            let actual = MeasureLE(qtarget);
            let expected = (input + target) % m;
            if (actual != expected) {
                fail $"Wrong sum. actual {actual} != expected {expected}";
            }

            ApplyXorInPlaceL(input, qinput);
            ApplyXorInPlaceL(actual, qtarget);
        }
    }
}