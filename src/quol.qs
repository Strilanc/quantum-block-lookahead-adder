namespace CG {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Random;

    operation check_is_zero(qubit: Qubit) : Unit is Adj {
        body (...) {
            if (M(qubit) != Zero) {
                fail "Check failed. M(qubit) != Zero.";
            }
        }
        adjoint (...) {
            if (M(qubit) != Zero) {
                fail "Check failed. M(qubit) != Zero.";
            }
        }
    }

    operation is_toffoli_simulator() : Bool {
        // HACK: magic happens in `quol.cs` native override.
        return false;
    }

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
        body(...) {
            if (is_toffoli_simulator()) {
                check_is_zero(target);
            }
            CCNOT(a, b, target);
        }
        adjoint(...) {
            if (is_toffoli_simulator()) {
                CCNOT(a, b, target);
                check_is_zero(target);
            } else {
                H(target);
                if (M(target) == One) {
                    CZ(a, b);
                }
            }
        }
    }

    // Xors `a` into `target`.
    operation ApplyXorInPlaceL(a: BigInt, target: LittleEndian) : Unit is Adj {
        for (k in 0..Length(target!)-1) {
            if ((a >>> k) % 2L == 1L) {
                X(target![k]);
            }
        }
    }

    /// Initializes out_target := control ? option1 | option0.
    ///
    /// Budget:
    ///     Toffoli count: n
    ///     Toffoli count (uncomputing):  0
    ///     Reaction Depth: n (could be lg(n) if control was duplicated)
    ///     Workspace: 0
    ///     where n = length(option1)
    ///
    /// Assumes:
    ///     MeasureLE(out_target) == 0
    ///     Length(out_target) == Length(option0)
    ///     Length(out_target) == Length(option1)
    operation init_choose(control: Qubit, option0: Qubit[], option1: Qubit[], out_target: Qubit[]) : Unit is Adj {
        let n = Length(option0);
        for (k in 0..n-1) {
            CNOT(option1[k], option0[k]);
            init_and(control, option0[k], out_target[k]);
            CNOT(option1[k], option0[k]);
            CNOT(option0[k], out_target[k]);
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
        while (1 <<< r < n) {
            set r += 1;
        }
        return r;
    }

    function PowersOfTwoBelow(n: Int) : Int[] {
        mutable result = new Int[0];
        mutable k = 1;
        while (k < n) {
            set result += [k];
            set k <<<= 1;
        }
        return result;
    }

    // Returns int(ceil(log_2(n))).
    function FloorLg2(n: Int) : Int {
        mutable r = 0;
        while (2 <<< r <= n) {
            set r += 1;
        }
        return r;
    }

    // Returns int(ceil(sqrt(n))).
    function CeilSqrt(n: Int) : Int {
        return Ceiling(Sqrt(IntAsDouble(n)));
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

    // Determines how many times `n` is divisible by 2.
    function PowerOfTwoness(n: Int) : Int {
        mutable k = n;
        mutable r = 0;
        while (k != 0 and k % 2 == 0) {
            set k >>>= 1;
            set r += 1;
        }
        return r;
    }
}
