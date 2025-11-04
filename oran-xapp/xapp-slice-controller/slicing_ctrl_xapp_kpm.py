#!/usr/bin/env python3
"""
Dynamic Quantum xApp Slice Controller with CLI-based Device Management
"""

import pennylane as qml
from pennylane import numpy as np
import json
import time
import os
import threading

devices = []  # Active device list
total_PRBs = 106
json_path = os.path.join(os.getcwd(), "rrmPolicy.json")
stop_flag = False


# --- Quantum Slice Allocator ---
def quantum_slice_allocation(num_slices, total_PRBs):
    """Quantum-inspired proportional PRB allocation for given slices."""
    dev = qml.device("default.qubit", wires=num_slices)

    @qml.qnode(dev)
    def circuit(weights):
        for i in range(num_slices):
            qml.RY(weights[i], wires=i)
        for i in range(num_slices - 1):
            qml.CNOT(wires=[i, i + 1])
        return [qml.expval(qml.PauliZ(i)) for i in range(num_slices)]

    weights = np.random.uniform(0, np.pi, num_slices)
    lr = 0.1
    steps = 30

    for _ in range(steps):
        def cost(w):
            return -sum(circuit(w))
        grad = qml.grad(cost)(weights)
        weights = weights - lr * grad

    expvals = circuit(weights)
    expvals_shifted = [(v + 1) / 2 for v in expvals]  # normalize to [0,1]
    total = sum(expvals_shifted)

    if total == 0:
        prb_alloc = [0] * num_slices
    else:
        prb_alloc = [int(total_PRBs * (float(v) / total)) for v in expvals_shifted]

    diff = total_PRBs - sum(prb_alloc)
    if diff != 0:
        prb_alloc[0] += diff  # fix rounding drift

    return prb_alloc


# --- Background Slice Controller ---
def slice_controller():
    global stop_flag

    while not stop_flag:
        num_devices = len(devices)

        if num_devices == 0:
            print("[WARN] No devices connected. Waiting...")
            time.sleep(5)
            continue

        # allocate dynamically based on current number of devices
        prb_allocation = quantum_slice_allocation(num_devices, total_PRBs)

        # map each device to its slice id
        slice_config = {
            "slices": [
                {"id": i + 1, "PRBs": prb_allocation[i]}
                for i in range(num_devices)
            ]
        }

        # write JSON
        with open(json_path, "w") as f:
            json.dump(slice_config, f, indent=2)

        print(f"[INFO] Devices: {devices}")
        print(f"[INFO] PRB Allocation: {prb_allocation}")
        print(f"[INFO] Updated JSON → {json_path}")
        time.sleep(10)


# --- CLI Interface ---
def cli():
    global stop_flag

    print("\n=== Dynamic Quantum Slice Controller CLI ===")
    print("Commands:")
    print("  add <device_id>     → Add device")
    print("  remove <device_id>  → Remove device")
    print("  list                → List devices")
    print("  exit                → Stop controller\n")

    while True:
        cmd = input(">> ").strip().split()
        if not cmd:
            continue

        action = cmd[0].lower()

        if action == "add" and len(cmd) == 2:
            dev_id = cmd[1]
            if dev_id not in devices:
                devices.append(dev_id)
                print(f"[INFO] Added device: {dev_id}")
            else:
                print(f"[WARN] Device {dev_id} already exists.")

        elif action == "remove" and len(cmd) == 2:
            dev_id = cmd[1]
            if dev_id in devices:
                devices.remove(dev_id)
                print(f"[INFO] Removed device: {dev_id}")
            else:
                print(f"[WARN] Device {dev_id} not found.")

        elif action == "list":
            print(f"[INFO] Connected devices ({len(devices)}): {devices or 'None'}")

        elif action == "exit":
            print("[INFO] Stopping controller...")
            stop_flag = True
            break

        else:
            print("[ERROR] Invalid command.")


# --- Main Entry ---
def main():
    print("[INFO] Starting Dynamic Quantum xApp Slice Controller...")

    controller_thread = threading.Thread(target=slice_controller, daemon=True)
    controller_thread.start()

    cli()
    controller_thread.join()
    print("[INFO] Controller stopped.")


if __name__ == "__main__":
    main()
