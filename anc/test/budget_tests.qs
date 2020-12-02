namespace BlockAdder.Tests {
    
    open BlockAdder;
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Diagnostics;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    @Test("ResourcesEstimator")
    operation run_tests_one_by_one() : Unit {
        // Works around https://github.com/microsoft/QuantumLibraries/issues/386
        check_budget_init_and();
        for (n in [5, 10, 100]) {
            check_budget_init_choose(n);
            check_budget_init_sum_using_two_block(n);
            check_budget_init_sum_using_carry_lookahead(n);
            check_budget_prop_gen(n);
            check_budget_init_sum_using_ripple_carry(n);
            check_budget_init_sum_using_square_root_blocks(n);
            for (b in [1, 2, 6]) {
                check_budget_init_sum_using_blocks(n, b);
            }
        }
    }

    operation check_budget_init_and() : Unit {
        let max_tofs = 1;
        let max_unc_tofs = 0;
        let max_work = 0;

        using ((a, b, c) = (Qubit(), Qubit(), Qubit())) {
            within {
                AllowAtMostNCallsCA(max_tofs, CCNOT, "Tofs");
                AllowAtMostNQubits(max_work, "Workspace");
            } apply {
                init_and(a, b, c);
            }

            within {
                AllowAtMostNCallsCA(max_unc_tofs, CCNOT, "Tofs (adj)");
                AllowAtMostNQubits(max_work, "Workspace (adj)");
            } apply {
                Adjoint init_and(a, b, c);
            }
        }
    }

    operation check_budget_init_choose(n: Int) : Unit {
        let max_tofs = n;
        let max_unc_tofs = 0;
        let max_work = 0;

        using ((a, b, c, d) = (Qubit(), Qubit[n], Qubit[n], Qubit[n])) {
            within {
                AllowAtMostNCallsCA(max_tofs, CCNOT, "Tofs");
                AllowAtMostNQubits(max_work, "Workspace");
            } apply {
                init_choose(a, b, c, d);
            }

            within {
                AllowAtMostNCallsCA(max_unc_tofs, CCNOT, "Tofs (adj)");
                AllowAtMostNQubits(max_work, "Workspace (adj)");
            } apply {
                Adjoint init_choose(a, b, c, d);
            }
        }
    }

    operation check_budget_init_sum_using_two_block(n: Int) : Unit {
        let max_tofs = 2*n;
        let max_unc_tofs = n;
        let max_work = n;

        using ((a, b, c) = (Qubit[n], Qubit[n], Qubit[n])) {
            let na = LittleEndian(a);
            let nb = LittleEndian(b);
            let nc = LittleEndian(c);
            within {
                AllowAtMostNCallsCA(max_tofs, CCNOT, "Tofs");
                AllowAtMostNQubits(max_work, "Workspace");
            } apply {
                init_sum_using_two_block(na, nb,  nc);
            }

            within {
                AllowAtMostNCallsCA(max_unc_tofs, CCNOT, "Tofs (adj)");
                AllowAtMostNQubits(max_work, "Workspace (adj)");
            } apply {
                Adjoint init_sum_using_two_block(na, nb, nc);
            }
        }
    }

    operation check_budget_init_sum_using_ripple_carry(n: Int) : Unit {
        let max_tofs = n;
        let max_unc_tofs = 0;
        let max_work = n;

        using ((a, b, c) = (Qubit[n], Qubit[n], Qubit[n])) {
            let na = LittleEndian(a);
            let nb = LittleEndian(b);
            let nc = LittleEndian(c);
            within {
                AllowAtMostNCallsCA(max_tofs, CCNOT, "Tofs");
                AllowAtMostNQubits(max_work, "Workspace");
            } apply {
                init_sum_using_ripple_carry(na, nb,  nc);
            }

            within {
                AllowAtMostNCallsCA(max_unc_tofs, CCNOT, "Tofs (adj)");
                AllowAtMostNQubits(max_work, "Workspace (adj)");
            } apply {
                Adjoint init_sum_using_ripple_carry(na, nb, nc);
            }
        }
    }

    operation check_budget_prop_gen(n: Int) : Unit {
        let max_tofs = 3*n;
        let max_unc_tofs = 3*n;
        let max_work = n;

        using ((a, b) = (Qubit[n], Qubit[n])) {
            within {
                AllowAtMostNCallsCA(max_tofs, CCNOT, "Tofs");
                AllowAtMostNQubits(max_work, "Workspace");
            } apply {
                _prop_gen(a, b);
            }

            within {
                AllowAtMostNCallsCA(max_unc_tofs, CCNOT, "Tofs (adj)");
                AllowAtMostNQubits(max_work, "Workspace (adj)");
            } apply {
                Adjoint _prop_gen(a, b);
            }
        }
    }

    operation check_budget_init_sum_using_carry_lookahead(n: Int) : Unit {
        let max_tofs = 4*n;
        let max_unc_tofs = 3*n;
        let max_work = n;

        using ((a, b, c) = (Qubit[n], Qubit[n], Qubit[n])) {
            let na = LittleEndian(a);
            let nb = LittleEndian(b);
            let nc = LittleEndian(c);
            within {
                AllowAtMostNCallsCA(max_tofs, CCNOT, "Tofs");
                AllowAtMostNQubits(max_work, "Workspace");
            } apply {
                init_sum_using_carry_lookahead(na, nb,  nc);
            }

            within {
                AllowAtMostNCallsCA(max_unc_tofs, CCNOT, "Tofs (adj)");
                AllowAtMostNQubits(max_work, "Workspace (adj)");
            } apply {
                Adjoint init_sum_using_carry_lookahead(na, nb, nc);
            }
        }
    }

    operation check_budget_init_sum_using_blocks(n: Int, block: Int) : Unit {
        let m = (n + block - 1) / block;
        let max_tofs = 3*n - 2*block + 5*m;
        let max_unc_tofs = 2*n - 2*block + 3*m;
        let max_work = 2*n + 3*m;

        using ((a, b, c) = (Qubit[n], Qubit[n], Qubit[n])) {
            let na = LittleEndian(a);
            let nb = LittleEndian(b);
            let nc = LittleEndian(c);
            within {
                AllowAtMostNCallsCA(max_tofs, CCNOT, "Tofs");
                AllowAtMostNQubits(max_work, "Workspace");
            } apply {
                init_sum_using_blocks(block, na, nb,  nc);
            }

            within {
                AllowAtMostNCallsCA(max_unc_tofs, CCNOT, "Tofs (adj)");
                AllowAtMostNQubits(max_work, "Workspace (adj)");
            } apply {
                Adjoint init_sum_using_blocks(block, na, nb, nc);
            }
        }
    }

    operation check_budget_init_sum_using_square_root_blocks(n: Int) : Unit {
        let m = CeilSqrt(n);
        let max_tofs = 3*n + 3*m;
        let max_unc_tofs = 2*n + m;
        let max_work = 2*n + 3*m;

        using ((a, b, c) = (Qubit[n], Qubit[n], Qubit[n])) {
            let na = LittleEndian(a);
            let nb = LittleEndian(b);
            let nc = LittleEndian(c);
            within {
                AllowAtMostNCallsCA(max_tofs, CCNOT, "Tofs");
                AllowAtMostNQubits(max_work, "Workspace");
            } apply {
                init_sum_using_square_root_blocks(na, nb,  nc);
            }

            within {
                AllowAtMostNCallsCA(max_unc_tofs, CCNOT, "Tofs (adj)");
                AllowAtMostNQubits(max_work, "Workspace (adj)");
            } apply {
                Adjoint init_sum_using_square_root_blocks(na, nb, nc);
            }
        }
    }
}
