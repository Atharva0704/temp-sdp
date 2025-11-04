#!/bin/bash

# ==============================================================================
# ORANSlice Deployment and Execution Helper Script (Quantum xApp Integrated)
# ==============================================================================

set -e

# --- Configuration ---
BASE_DIR="$HOME"₹
ORANSLICE_DIR="$BASE_DIR/ORANSlice"
E2SIM_DIR="$BASE_DIR/o-ran-e2sim"
XAPP_DIR="$BASE_DIR/oran-xapp"

# --- Helper Functions ---
print_info() { echo -e "\n\e[1;34m[INFO]\e[0m $1"; }
print_success() { echo -e "\e[1;32m[SUCCESS]\e[0m $1"; }
print_warning() { echo -e "\e[1;33m[WARNING]\e[0m $1"; }
print_error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; }

# --- Core Functions ---
clone_repos() {
    print_info "Cloning all required repositories into $BASE_DIR..."
    cd "$BASE_DIR"

    [ -d "$ORANSLICE_DIR" ] && print_warning "ORANSlice exists, skipping clone." || \
        git clone https://github.com/wineslab/ORANSlice.git && print_success "Cloned ORANSlice."

    [ -d "$E2SIM_DIR" ] && print_warning "o-ran-e2sim exists, skipping clone." || \
        git clone https://gerrit.o-ran-sc.org/r/ric-plt/e2sim "$E2SIM_DIR" && print_success "Cloned e2sim."

    [ -d "$XAPP_DIR" ] && print_warning "oran-xapp exists, skipping clone." || \
        git clone https://github.com/wineslab/oran-xapp.git "$XAPP_DIR" && print_success "Cloned oran-xapp."

    [ -d "$BASE_DIR/protobuf-c" ] || (print_info "Cloning protobuf-c..." && git clone https://github.com/protobuf-c/protobuf-c)

    print_success "All repositories cloned."
}

install_dependencies() {
    print_info "Installing system dependencies..."
    sudo apt-get update
    sudo apt-get install -y protobuf-compiler libprotoc-dev autoconf libtool python3-pip
    pip install qiskit qiskit-optimization
    print_info "Building and installing protobuf-c..."
    cd "$BASE_DIR/protobuf-c"
    ./autogen.sh
    ./configure
    make
    sudo make install
    sudo ldconfig
    print_success "Dependencies installed."
}

build_oai_ran() {
    print_info "Checking and installing OAI RAN build dependencies..."

    # Core build tools
    sudo apt-get update
    sudo apt-get install -y \
        build-essential cmake ninja-build git \
        pkg-config autoconf automake libtool \
        libboost-all-dev libfftw3-dev \
        libblas-dev liblapack-dev gfortran \
        libtinfo-dev libxml2-dev flex bison \
        python3 python3-pip

    print_info "Dependencies ready. Starting OAI RAN build..."

    BUILD_DIR="$ORANSLICE_DIR/oai_ran/cmake_targets/ran_build"
    # Clean old build
    [ -d "$BUILD_DIR" ] && rm -rf "$BUILD_DIR"

    cd "$ORANSLICE_DIR/oai_ran/cmake_targets"

    # Install extra deps (OAI helper)
    ./build_oai -I || { print_error "Dependency installation via build_oai failed."; return 1; }

    # Actual build (gNB + nrUE)
    ./build_oai --ninja --gNB --nrUE || { print_error "Build failed. Check logs above."; return 1; }

    print_success "OAI RAN built successfully."
}


run_oai_core() {
    print_info "Starting OAI 5G Core Network..."
    cd "$ORANSLICE_DIR/oai_cn/oai-cn5g-legacy/"
    print_warning "Core running in this terminal. Stop with Ctrl+C."
    sudo ./restart_cn.sh
}

run_gnb_rfsim() {
    print_info "Starting OAI gNB RF Simulation..."
    cd "ORANSlice/oai_ran/cmake_targets/ran_build/build"
    ./nr-softmodem -O ../../../targets/PROJECTS/GENERIC-NR-5GC/CONF/ORANSlice.gnb.sa.band78.fr1.106PRB.usrpx310.conf --sa --rfsim
}

run_nue_rfsim() {
    print_info "Starting OAI nrUE RF Simulation..."
    cd "$ORANSLICE_DIR/oai_ran/cmake_targets/ran_build/build"
    sudo ./nr-uesoftmodem -r 106 --numerology 1 --band 78 -C 3619200000 --sa -O ../../../targets/PROJECTS/GENERIC-NR-5GC/CONF/nrUE_slice1.conf --rfsim --rfsimulator.serveraddr 127.0.0.1
}

run_e2sim() {
    print_info "Running e2sim..."
    cd "$E2SIM_DIR"
    read -p "Enter E2 terminator address: " e2term_addr
    read -p "Enter E2 terminator port: " e2term_port
    [ -z "$e2term_addr" ] || [ -z "$e2term_port" ] && print_error "Address or port empty" && return 1
    print_warning "Build and run manually per OSC guide."
}

run_xapp_connector() {
    print_info "Running xApp BS Connector..."
    cd "$XAPP_DIR/xapp-sm-connector"
    print_warning "Build and run manually (Go build)."
}

run_xapp_logic() {
    print_info "Running xApp Logic Unit (Quantum Simulator)..."
    cd "$XAPP_DIR/xapp-slice-controller"
    python3 slicing_ctrl_xapp_kpm.py
}

apply_troubleshooting_patch() {
    print_info "Applying patch to test RAN slicing without RIC..."
    cd "$ORANSLICE_DIR/oai_ran"
    PATCH_FILE="$ORANSLICE_DIR/doc/rrmPolicyJson.patch"
    [ ! -f "$PATCH_FILE" ] && print_error "Patch not found" && return 1
    git apply "$PATCH_FILE"

    CONFIG_FILE="$ORANSLICE_DIR/oai_ran/targets/PROJECTS/GENERIC-NR-5GC/CONF/ORANSlice.gnb.sa.band78.fr1.106PRB.usrpx310.conf"
    JSON_PATH="$ORANSLICE_DIR/rrmPolicy.json"
    sed -i "s|SliceConf = \".*\";|SliceConf = \"$JSON_PATH\";|" "$CONFIG_FILE"
    print_success "Patch applied and gNB config updated."
}

main_menu() {
    while true; do
        clear
        cat << "EOF"
-- Deployment and Execution Helper --
======================= SETUP & BUILD =========================
1. Clone all required git repositories
2. Install dependencies (protobuf-c)
3. Build OAI RAN (gNB and nrUE)

===================== RUN RFSim EXAMPLE =====================
(Run these in separate terminals in the given order)
4. Run OAI 5G Core Network
5. Run OAI gNB (RFSim)
6. Run OAI nrUE (RFSim)

==================== RUN RIC COMPONENTS =====================
(Requires a running O-RAN SC RIC instance)
7. Run e2sim
8. Run xApp Connector
9. Run xApp Logic Unit (Quantum Simulator)

====================== TROUBLESHOOTING ======================
10. Apply patch to test RAN Slicing without RIC

=============================================================
q. Quit
EOF
        read -p "Enter your choice: " choice
        case $choice in
            1) clone_repos ;;
            2) install_dependencies ;;
            3) build_oai_ran ;;
            4) run_oai_core ;;
            5) run_gnb_rfsim ;;
            6) run_nue_rfsim ;;
            7) run_e2sim ;;
            8) run_xapp_connector ;;
            9) run_xapp_logic ;;
            10) apply_troubleshooting_patch ;;
            q|Q) echo "Exiting."; exit 0 ;;
            *) print_error "Invalid option." ;;
        esac
        read -p "Press Enter to return to menu..."
    done
}

main_menu
