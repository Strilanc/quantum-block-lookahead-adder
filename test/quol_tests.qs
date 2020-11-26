namespace BlockAdder.Tests {
    
    open BlockAdder;
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Bitwise;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Diagnostics;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Random;

    operation assert(b: Bool) : Unit {
        if (!b) {
            fail "assert";
        }
    }

    @Test("ToffoliSimulator")
    operation test_FloorLg2() : Unit {
        assert(FloorLg2(1) == 0);
        assert(FloorLg2(2) == 1);
        assert(FloorLg2(3) == 1);
        assert(FloorLg2(4) == 2);
        assert(FloorLg2(5) == 2);
        assert(FloorLg2(6) == 2);
        assert(FloorLg2(127) == 6);
        assert(FloorLg2(128) == 7);
        assert(FloorLg2(129) == 7);
    }

    @Test("ToffoliSimulator")
    operation test_CeilLg2() : Unit {
        assert(CeilLg2(1) == 0);
        assert(CeilLg2(2) == 1);
        assert(CeilLg2(3) == 2);
        assert(CeilLg2(4) == 2);
        assert(CeilLg2(5) == 3);
        assert(CeilLg2(6) == 3);
        assert(CeilLg2(127) == 7);
        assert(CeilLg2(128) == 7);
        assert(CeilLg2(129) == 8);
    }

    @Test("ToffoliSimulator")
    operation test_FactorsOf2() : Unit {
        assert(FactorsOf2(0) == 0);
        assert(FactorsOf2(1) == 0);
        assert(FactorsOf2(2) == 1);
        assert(FactorsOf2(3) == 0);
        assert(FactorsOf2(4) == 2);
        assert(FactorsOf2(5) == 0);
        assert(FactorsOf2(6) == 1);
        assert(FactorsOf2(7) == 0);
        assert(FactorsOf2(8) == 3);
        assert(FactorsOf2(9) == 0);
        assert(FactorsOf2(10) == 1);
    }

    @Test("ToffoliSimulator")
    operation test_CeilSqrt() : Unit {
        assert(CeilSqrt(0) == 0);
        assert(CeilSqrt(1) == 1);
        assert(CeilSqrt(2) == 2);
        assert(CeilSqrt(3) == 2);
        assert(CeilSqrt(4) == 2);
        assert(CeilSqrt(5) == 3);
        assert(CeilSqrt(6) == 3);
        assert(CeilSqrt(143) == 12);
        assert(CeilSqrt(144) == 12);
        assert(CeilSqrt(145) == 13);
    }
}