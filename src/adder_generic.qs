namespace CG {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    /// Performs target += input using a target := input1 + input2 helper.
    ///
    /// Assumes:
    ///     Length(target) == Length(input)
    ///
    /// Budget:
    ///     One call to init_sum and one call to Adjoint init_sum.
    operation add_into_using(
            init_sum: ((LittleEndian, LittleEndian, LittleEndian) => Unit is Adj),
            input: LittleEndian,
            target: LittleEndian) : Unit is Adj {
        let n = Length(input!);
        using (spare = Qubit[n]) {
            init_sum(input, target, LittleEndian(spare));
            for (k in 0..n-1) {
                SWAP(target![k], spare[k]);
                X(target![k]);
                X(spare[k]);
            }
            Adjoint init_sum(input, target, LittleEndian(spare));
            for (k in 0..n-1) {
                X(target![k]);
            }
        }
    }
}
