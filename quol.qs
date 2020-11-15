namespace CG {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    operation init_and(a: Qubit, b: Qubit, target: Qubit) : Unit is Adj {
        CCNOT(a, b, target);
        // body(...) {
        //     CCNOT(a, b, target);
        // }
        // adjoint(...) {
        //     H(target);
        //     let d = M(target);
        //     if (d == One) {
        //         CZ(a, b);
        //     }
        // }
    }

    operation ApplyXorInPlaceL(a: BigInt, target: LittleEndian) : Unit {
        for (k in 0..Length(target!)-1) {
            if (RightShiftedL(a, k) % 2L == 1L) {
                X(target![k]);
            }
        }
    }

    operation MeasureLE(a: LittleEndian) : BigInt {
        mutable r = 0L;
        for (k in Length(a!)-1..-1..0) {
            set r *= 2L;
            if (M(a![k]) == One) {
                set r += 1L;
            }
        }
        return r;
    }

    operation DrawRandomBitString(n: Int) : BigInt {
        mutable r = 0L;
        for (k in 0..n-1) {
            set r *= 2L;
            if (DrawRandomBool(0.5)) {
                set r += 1L;
            }
        }
        return r;
    }

    function BitLen(n: Int) : Int {
        mutable r = 0;
        while (LeftShiftedI(1, r) < n) {
            set r += 1;
        }
        return r;
    }
}
