﻿namespace BlockAdder.Tests {
    
    open BlockAdder;
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Diagnostics;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    @Test("ToffoliSimulator")
    operation test_add_into_using_carry_lookahead() : Unit {
        FuzzTestInPlaceAddition(add_into_using_carry_lookahead);
    }

    @Test("ToffoliSimulator")
    operation test_init_sum_using_carry_lookahead() : Unit {
        FuzzTestInitAddition(init_sum_using_carry_lookahead);
    }

    @Test("ToffoliSimulator")
    operation test_init_sum_using_two_block() : Unit {
        FuzzTestInitAddition(init_sum_using_two_block);
    }

    @Test("ToffoliSimulator")
    operation test_init_sum_using_blocks() : Unit {
        FuzzTestInitAddition(init_sum_using_blocks(1, _, _, _));
        FuzzTestInitAddition(init_sum_using_blocks(2, _, _, _));
        FuzzTestInitAddition(init_sum_using_blocks(5, _, _, _));
        FuzzTestInitAddition(init_sum_using_blocks(10, _, _, _));
        FuzzTestInitAddition(init_sum_using_blocks(16, _, _, _));
    }

    @Test("ToffoliSimulator")
    operation test_prop_gen() : Unit {
        let n = 19;
        let a = 0b0000010001000000100;
        let b = 0b0001110001000100000;
        let e = 0b0011110011000000100L;
        using ((qg, qp) = (Qubit[n], Qubit[n])) {
            let g = LittleEndian(qg);
            let p = LittleEndian(qp);
            within {
                ApplyXorInPlace(a, g);
                ApplyXorInPlace(b, p);
                _prop_gen(p!, g!);
            } apply {
                let m = MeasureLE(g);
                if (m != e) {
                    fail $"{m} != {e}";
                }
            }
        }
    }

    @Test("ToffoliSimulator")
    operation test_init_sum_using_ripple_carry() : Unit {
        FuzzTestInitAddition(init_sum_using_ripple_carry);
    }

    @Test("ToffoliSimulator")
    operation test_init_sum_using_square_root_blocks() : Unit {
        FuzzTestInitAddition(init_sum_using_square_root_blocks);
    }

    operation FuzzTestInitAddition(
            adder: ((LittleEndian, LittleEndian, LittleEndian) => Unit)) : Unit {
        FuzzTestInitAdditionLength(adder, 0, 1);
        FuzzTestInitAdditionLength(adder, 1, 2);
        FuzzTestInitAdditionLength(adder, 2, 2);
        FuzzTestInitAdditionLength(adder, 3, 2);
        FuzzTestInitAdditionLength(adder, 4, 2);
        FuzzTestInitAdditionLength(adder, 100, 5);
        FuzzTestInitAdditionLength(adder, 127, 5);
        FuzzTestInitAdditionLength(adder, 128, 5);
        FuzzTestInitAdditionLength(adder, 129, 5);
    }

    operation FuzzTestInPlaceAddition(
            adder: ((LittleEndian, LittleEndian) => Unit)) : Unit {
        FuzzTestInPlaceAdditionLength(adder, 0, 1);
        FuzzTestInPlaceAdditionLength(adder, 1, 2);
        FuzzTestInPlaceAdditionLength(adder, 2, 2);
        FuzzTestInPlaceAdditionLength(adder, 3, 2);
        FuzzTestInPlaceAdditionLength(adder, 4, 2);
        FuzzTestInPlaceAdditionLength(adder, 100, 5);
        FuzzTestInPlaceAdditionLength(adder, 127, 5);
        FuzzTestInPlaceAdditionLength(adder, 128, 5);
        FuzzTestInPlaceAdditionLength(adder, 129, 5);
    }

    operation FuzzTestInitAdditionLength(
            adder: ((LittleEndian, LittleEndian, LittleEndian) => Unit),
            n: Int, attempts: Int) : Unit {
        for (k in 1..attempts) {
            let a = DrawRandomBitString(n);
            let b = DrawRandomBitString(n);
            CheckInitAdditionCase(adder, n, a, b);
        }
    }

    operation FuzzTestInPlaceAdditionLength(
            adder: ((LittleEndian, LittleEndian) => Unit),
            n: Int, attempts: Int) : Unit {
        for (k in 1..attempts) {
            let a = DrawRandomBitString(n);
            let b = DrawRandomBitString(n);
            CheckInPlaceAdditionCase(adder, n, a, b);
        }
    }

    operation CheckInitAdditionCase(
            adder: ((LittleEndian, LittleEndian, LittleEndian) => Unit),
            n: Int,
            a: BigInt,
            b: BigInt) : Unit {
        let m = 1L <<< n;
        using (data = Qubit[3*n]) {
            let qa = LittleEndian(data[...n-1]);
            let qb = LittleEndian(data[n..2*n-1]);
            ApplyXorInPlaceL(a, qa);
            ApplyXorInPlaceL(b, qb);

            let qsum = LittleEndian(data[2*n...]);
            adder(qa, qb, qsum);
            let actual = MeasureLE(qsum);
            let expected = (a + b) % m;
            if (actual != expected) {
                fail $"Wrong sum. n={n} a={a}, b={b}, actual={actual}, expected={expected}";
            }

            ApplyXorInPlaceL(a, qa);
            ApplyXorInPlaceL(b, qb);
            ApplyXorInPlaceL(actual, qsum);
        }
    }

    operation CheckInPlaceAdditionCase(
            adder: ((LittleEndian, LittleEndian) => Unit),
            n: Int,
            input: BigInt,
            target: BigInt) : Unit {
        let m = 1L <<< n;
        using (data = Qubit[2*n]) {
            let qinput = LittleEndian(data[...n-1]);
            let qtarget = LittleEndian(data[n...]);
            ApplyXorInPlaceL(input, qinput);
            ApplyXorInPlaceL(target, qtarget);

            adder(qinput, qtarget);
            let actual = MeasureLE(qtarget);
            let expected = (input + target) % m;
            if (actual != expected) {
                fail $"Wrong sum. n={n} input={input}, target={target}, actual={actual}, expected={expected}";
            }

            ApplyXorInPlaceL(input, qinput);
            ApplyXorInPlaceL(actual, qtarget);
        }
    }
}