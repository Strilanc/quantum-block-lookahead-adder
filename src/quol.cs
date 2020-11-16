#nullable enable

using System;
using Microsoft.Quantum.Simulation.Core;
using Microsoft.Quantum.Simulation.Simulators;

namespace CG {
    public partial class init_and {
        public class Native : init_and {
            private bool use_classical_adjoint;

            public Native(IOperationFactory m) : base(m) {
                use_classical_adjoint = m is ToffoliSimulator;
            }

            public override Func<(Qubit, Qubit, Qubit), QVoid> __AdjointBody__ {
                get {
                    if (use_classical_adjoint) {
                        return base.__Body__;
                    }
                    return base.__AdjointBody__;
                }
            }

        }
    }
}
