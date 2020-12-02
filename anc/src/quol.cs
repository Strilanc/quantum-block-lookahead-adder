#nullable enable

using System;
using Microsoft.Quantum.Simulation.Core;
using Microsoft.Quantum.Simulation.Simulators;

namespace BlockAdder {
    public partial class is_toffoli_simulator {
        public class Native : is_toffoli_simulator {
            private Func<QVoid, bool> _body;

            public Native(IOperationFactory m) : base(m) {
                var b = m is ToffoliSimulator;
                _body = args => b;
            }

            public override Func<QVoid, bool> __Body__ => _body;
        }
    }
}
