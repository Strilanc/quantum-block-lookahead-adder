namespace CG {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    function BigIntBitString(a: BigInt, len: Int) : String {
        mutable result = "";
        mutable a2 = a;
        for (i in 0..len-1) {
            if (i > 0 and i % 8 == 0) {
                set result += " ";
            }
            if (a2 % 2L == 0L) {
                set result += "_";
            } else {
                set result += "1";
            }
            set a2 /= 2L;
        }
        if (a2 > 0L) {
            set result += "...";
        }
        return result;
    }

    operation Debug(s: String) : Unit is Adj {
        body(...) {
            Message(s);
        }
        adjoint(...) {
            Message(s);
        }
    }

    operation DebugLE(prefix: String, q: LittleEndian) : Unit is Adj {
        body(...) {
            let r = MeasureLE(q);
            Message($"{r}");
        }
        adjoint(...) {
            let r = MeasureLE(q);
            Message($"{r}");
        }
    }

    operation DebugQubits(prefix: String, q: Qubit[]) : Unit is Adj {
        body(...) {
            let r = BigIntBitString(MeasureLE(LittleEndian(q)), Length(q));
            Message($"{prefix}{r}");
        }
        adjoint(...) {
            let r = BigIntBitString(MeasureLE(LittleEndian(q)), Length(q));
            Message($"{prefix}{r}");
        }
    }

    operation DebugQubit(prefix: String, q: Qubit) : Unit is Adj {
        body(...) {
            if (M(q) == One) {
                Message($"{prefix}1");
            } else {
                Message($"{prefix}0");
            }
        }
        adjoint(...) {
            if (M(q) == One) {
                Message($"{prefix}1");
            } else {
                Message($"{prefix}0");
            }
        }
    }
}
