#!/usr/bin/env python3
"""
xApp Slice Controller with PennyLane Quantum Simulation for O-RAN
"""

import pennylane as qml
from pennylane import numpy as np
import json
import time
import os

# --- Quantum Slice Optimizer ---
def quantum_slice_allocation(num_slices=3, total_PRBs=106):
    """
    Simulate quantum optimization for slice PRB allocation using PennyLane,
    but always assign the highest PRBs to the first slice.
    """
    dev = qml.device("default.qubit", wires=num_slices)

    @qml.qnode(dev)
    def circuit(weights):
        for i in range(num_slices):
            qml.RY(weights[i], wires=i)
        for i in range(num_slices - 1):
            qml.CNOT(wires=[i, i+1])
        return [qml.expval(qml.PauliZ(i)) for i in range(num_slices)]

    weights = np.random.uniform(0, np.pi, num_slices)

    steps = 50
    lr = 0.1
    for _ in range(steps):
        def cost(w):
            return -sum(circuit(w))
        grad = qml.grad(cost)(weights)
        weights = weights - lr * grad

    expvals = circuit(weights)
    expvals_shifted = [(v + 1) / 2 for v in expvals]  # [-1,1] -> [0,1]
    total = sum(expvals_shifted)

    # Initial PRB allocation proportional to expvals
    prb_alloc = [int(qml.numpy.round(total_PRBs * (float(v) / total))) if total > 0 else 0 for v in expvals_shifted]

    # Force the first slice to have the maximum PRBs
    remaining_prbs = total_PRBs - max(prb_alloc)
    prb_alloc_sorted = sorted(prb_alloc[1:], reverse=True)  # sort remaining slices
    prb_alloc = [max(prb_alloc)] + prb_alloc_sorted

    # Adjust if total PRBs slightly differ due to rounding
    diff = total_PRBs - sum(prb_alloc)
    prb_alloc[0] += diff

    return prb_alloc


# --- Main xApp Loop ---
def main():
    print("[INFO] Starting PennyLane Quantum xApp Slice Controller...")

    num_slices = 3
    total_PRBs = 106

    json_path = os.path.join(os.getcwd(), "rrmPolicy.json")
    if not os.path.exists(json_path):
        with open(json_path, "w") as f:
            json.dump({"slices": []}, f)

    while True:
        prb_allocation = quantum_slice_allocation(num_slices, total_PRBs)
        print(f"[INFO] Quantum-simulated PRB allocation: {prb_allocation}")

        slice_config = {"slices": [{"id": i+1, "PRBs": prb_allocation[i]} for i in range(num_slices)]}
        with open(json_path, "w") as f:
            json.dump(slice_config, f, indent=2)
        print(f"[INFO] Updated slice config saved to {json_path}")

        time.sleep(10)

if __name__ == "__main__":
    main()