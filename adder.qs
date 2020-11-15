namespace CG {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

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
