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
                Message($"TESTING A={a}, B={b}");
                let c = (a + b) % m;
                let A = LittleEndian(data[0..n-1]);
                let B = LittleEndian(data[n..2*n-1]);
                let C = LittleEndian(data[2*n..3*n-1]);
                ApplyXorInPlaceL(a, A);
                ApplyXorInPlaceL(b, B);
                init_add(A, B, C);
                let c2 = MeasureBigInt(C);
                if (c2 != c) {
                    Message("GOT");
                    Message(bitstring(c2));
                    Message("EXPECTED");
                    Message(bitstring(c));
                }

                ApplyXorInPlaceL(a, A);
                ApplyXorInPlaceL(b, B);
                ApplyXorInPlaceL(c, C);
            }
        }
        Message("Passed.");
    }

    operation ApplyXorInPlaceL(a: BigInt, target: LittleEndian) : Unit {
        for (k in 0..Length(target!)-1) {
            if (RightShiftedL(a, k) % 2L == 1L) {
                X(target![k]);
            }
        }
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

    operation MeasureBigInt(a: LittleEndian) : BigInt {
        mutable r = 0L;
        for (k in Length(a!)-1..-1..0) {
            set r *= 2L;
            if (M(a![k]) == One) {
                set r += 1L;
            }
        }
        return r;
    }

    function bitstring(a: BigInt) : String {
        mutable result = "";
        mutable a2 = a;
        mutable i = 0;
        while (a2 > 0L) {
            if (i > 0 and i % 8 == 0) {
                set result += " ";
            }
            set i += 1;
            if (a2 % 2L == 0L) {
                set result += "_";
            } else {
                set result += "1";
            }
            set a2 /= 2L;
        }
        return result;
    }

    operation measure_bitstring(a: LittleEndian) : String {
        return bitstring(MeasureBigInt(a));
    }

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

    function read_c(start: Int, end: Int, initial_carries: Qubit[], mid_carries: Qubit[]) : Qubit {
        if (end == start + 1) {
            return initial_carries[start];
        }
        return mid_carries[(start + end) / 2];
    }

    operation cross(a: Int, b: Int, c: Int, initial_carries: Qubit[], initial_thresholds: Qubit[], mid_carries: Qubit[], mid_thresholds: Qubit[]) : Unit is Adj {
        let c_a2b = read_c(a, b, initial_carries, mid_carries);
        let t_a2b = read_c(a, b, initial_thresholds, mid_thresholds);
        let c_b2c = read_c(b, c, initial_carries, mid_carries);
        let t_b2c = read_c(b, c, initial_thresholds, mid_thresholds);
        init_and(t_b2c, c_a2b, mid_carries[b]);
        init_and(t_b2c, t_a2b, mid_thresholds[b]);
        CNOT(c_b2c, mid_carries[b]);
    }

    function BitLen(n: Int) : Int {
        mutable r = 0;
        while (LeftShiftedI(1, r) < n) {
            set r += 1;
        }
        return r;
    }

    operation MessageForward(s: String) : Unit is Adj {
        body(...) {
            Message(s);
        }
        adjoint(...) {
        }
    }
    operation MessageBitStringForward(q: Qubit[]) : Unit is Adj {
        body(...) {
            MessageForward(measure_bitstring(LittleEndian(q)));
        }
        adjoint(...) {
        }
    }
    operation MessageBitForward(text: String, q: Qubit) : Unit is Adj {
        body(...) {
            if (M(q) == One) {
                MessageForward($"{text}1");
            } else {
                MessageForward($"{text}0");
            }
        }
        adjoint(...) {
        }
    }
    
    operation init_internal(initial_carries: Qubit[], initial_thresholds: Qubit[], mid_carries: Qubit[], mid_thresholds: Qubit[]) : Unit is Adj {
        let n = Length(initial_thresholds);
        let p = BitLen(n);
        for (t in 0..BitLen(n)-2) {
            let step = LeftShiftedI(1, t);
            for (a in 0..step * 2..n-step * 2 - 1) {
                cross(a, a + step, a + step * 2, initial_carries, initial_thresholds, mid_carries, mid_thresholds);
            }
        }
    }

    operation brett_kung_adder(initial_carries: Qubit[], initial_thresholds: Qubit[], final_carries: Qubit[]) : Unit {
        let n = Length(initial_carries);
        using (mid_thresholds = Qubit[n]) {
            using (mid_carries = Qubit[n]) {
                init_internal(initial_carries, initial_thresholds, mid_carries, mid_thresholds);

                for (t in BitLen(n)-1..-1..0) {
                    let step = LeftShiftedI(1, t);
                    for (a in 0..step*2..n-step-1) {
                        let b = a + step;
                        let c_a2b = read_c(a, b, initial_carries, mid_carries);
                        let t_a2b = read_c(a, b, initial_thresholds, mid_thresholds);
                        init_and(t_a2b, final_carries[a], final_carries[b]);
                        CNOT(c_a2b, final_carries[b]);
                    }
                }

                Adjoint init_internal(initial_carries, initial_thresholds, mid_carries, mid_thresholds);
            }
        }
    }

    operation init_add(a: LittleEndian, b: LittleEndian, c: LittleEndian) : Unit {
        let n = Length(a!);
        // assert Length(b!) == n
        // assert Length(c!) == n
        // assert c == 0
        using (initial_carries = Qubit[n]) {
            for (k in 0..(n-1)) {
                init_and(a![k], b![k], initial_carries[k]);
            }
            for (k in 0..(n-1)) {
                CNOT(a![k], b![k]);
            }

            brett_kung_adder(initial_carries, b!, c!);

            for (k in 0..(n-1)) {
                CNOT(b![k], c![k]);
            }
            for (k in 0..(n-1)) {
                CNOT(a![k], b![k]);
            }
            for (k in 0..(n-1)) {
                Adjoint init_and(a![k], b![k], initial_carries[k]);
            }
        }
    }
}
