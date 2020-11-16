namespace CG {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    /// Initializes `target` to equal `a & b`.
    ///
    /// Assumes:
    ///     M(target) == Zero
    ///
    /// Budget:
    ///     Reaction depth: 1
    ///     Toffoli count: 1
    ///     Toffoli count (uncomputing): 0
    ///     Additional Workspace: 0
    operation init_and(a: Qubit, b: Qubit, target: Qubit) : Unit is Adj {
        // Uncomment this when using Toffoli simulator.
        CCNOT(a, b, target);

        // Uncomment this when doing resource estimates.
        // body(...) {
        //     CCNOT(a, b, target);
        // }
        // adjoint(...) {
        //     H(target);
        //     if (M(target) == One) {
        //         CZ(a, b);
        //     }
        // }
    }

    // Xors `a` into `target`.
    operation ApplyXorInPlaceL(a: BigInt, target: LittleEndian) : Unit {
        for (k in 0..Length(target!)-1) {
            if (RightShiftedL(a, k) % 2L == 1L) {
                X(target![k]);
            }
        }
    }

    // Measure the little-endian value of `a` as a BigInt.
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

    // Returns int(ceil(log_2(n))).
    function CeilLg2(n: Int) : Int {
        mutable r = 0;
        while (LeftShiftedI(1, r) < n) {
            set r += 1;
        }
        return r;
    }

    // Creates a random bit string as a `BigInt`.
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
}
