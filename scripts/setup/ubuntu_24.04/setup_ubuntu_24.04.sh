#!/usr/bin/env bash

# ==============================================================================
# Drone Detection POC
# Ubuntu 24.04 Complete Setup
# ==============================================================================
#
# Purpose:
#   Run every Ubuntu 24.04 setup stage for the Drone Detection POC in the
#   correct dependency order.
#
# This script is the TOP-LEVEL ORCHESTRATOR for Ubuntu 24.04.
#
# It delegates the actual installation/configuration work to:
#
#   1. prereq.sh
#   2. ros2_jazzy_setup.sh
#   3. gazebo_harmonic_setup.sh
#   4. ardupilot_setup.sh
#   5. ardupilot_gazebo_setup.sh
#   6. project_setup.sh
#
# Directory:
#
#   scripts/setup/ubuntu_24.04/
#   ├── setup_ubuntu_24.04.sh       <-- this script
#   ├── prereq.sh
#   ├── ros2_jazzy_setup.sh
#   ├── gazebo_harmonic_setup.sh
#   ├── ardupilot_setup.sh
#   ├── ardupilot_gazebo_setup.sh
#   └── project_setup.sh
#
# Execution order:
#
#   setup_ubuntu_24.04.sh
#          |
#          +--> prereq.sh
#          |
#          +--> ros2_jazzy_setup.sh
#          |
#          +--> gazebo_harmonic_setup.sh
#          |
#          +--> ardupilot_setup.sh
#          |
#          +--> ardupilot_gazebo_setup.sh
#          |
#          +--> project_setup.sh
#
# Important:
#   - This script must be run as a normal user.
#   - Individual scripts use sudo when necessary.
#   - If any stage fails, this script stops immediately.
#   - Existing repositories are reused by the individual setup scripts.
#   - This script does not modify ~/.bashrc or ~/.profile itself.
#   - This script does not create setup log files.
#
# Usage:
#
#   chmod +x setup_ubuntu_24.04.sh
#   ./setup_ubuntu_24.04.sh
#
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SETUP_DIR="$SCRIPT_DIR"

PREREQ_SCRIPT="$SETUP_DIR/prereq.sh"
ROS_SCRIPT="$SETUP_DIR/ros2_jazzy_setup.sh"
GAZEBO_SCRIPT="$SETUP_DIR/gazebo_harmonic_setup.sh"
ARDUPILOT_SCRIPT="$SETUP_DIR/ardupilot_setup.sh"
ARDUPILOT_GAZEBO_SCRIPT="$SETUP_DIR/ardupilot_gazebo_setup.sh"
PROJECT_SCRIPT="$SETUP_DIR/project_setup.sh"

EXPECTED_OS_ID="Ubuntu"
EXPECTED_OS_CODENAME="noble"
EXPECTED_OS_RELEASE="24.04"

# ------------------------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------------------------

print_header() {
    echo
    echo "======================================================================"
    echo "$1"
    echo "======================================================================"
}

print_step() {
    echo
    echo "----------------------------------------------------------------------"
    echo "[STEP] $1"
    echo "----------------------------------------------------------------------"
}

print_info() {
    echo "[INFO] $1"
}

print_success() {
    echo "[OK]   $1"
}

print_warning() {
    echo "[WARN] $1"
}

die() {
    echo
    echo "[ERROR] $1"
    echo
    exit 1
}

# ------------------------------------------------------------------------------
# Stage runner
# ------------------------------------------------------------------------------

run_stage() {
    local stage_number="$1"
    local total_stages="$2"
    local stage_name="$3"
    local stage_script="$4"

    print_header "Stage ${stage_number}/${total_stages}: ${stage_name}"

    if [[ ! -f "$stage_script" ]]; then
        die "Setup script not found:

    $stage_script"
    fi

    if [[ ! -x "$stage_script" ]]; then
        print_info "Making setup script executable:"
        print_info "    $stage_script"
        chmod +x "$stage_script"
    fi

    print_info "Running:"
    print_info "    $stage_script"
    echo

    "$stage_script"

    print_success "Stage ${stage_number}/${total_stages} completed: ${stage_name}"
}

# ------------------------------------------------------------------------------
# Start
# ------------------------------------------------------------------------------

print_header "Drone Detection POC - Ubuntu 24.04 Complete Setup"

# ------------------------------------------------------------------------------
# 1. Root check
# ------------------------------------------------------------------------------

if [[ "${EUID}" -eq 0 ]]; then
    die "Do not run the complete setup as root.

Run it as your normal user:

    ./setup_ubuntu_24.04.sh

The individual setup scripts will use sudo when required."
fi

# ------------------------------------------------------------------------------
# 2. Determine project directory
# ------------------------------------------------------------------------------

print_step "Locating Drone Detection POC"

print_info "Setup directory:"
print_info "    $SETUP_DIR"

print_info "Project directory:"
print_info "    $PROJECT_DIR"

if [[ ! -d "$PROJECT_DIR" ]]; then
    die "Drone Detection POC directory was not found:

    $PROJECT_DIR"
fi

print_success "Drone Detection POC directory found"

# ------------------------------------------------------------------------------
# 3. Verify operating system
# ------------------------------------------------------------------------------

print_step "Checking operating system"

if ! command -v lsb_release >/dev/null 2>&1; then
    die "lsb_release is not installed.

The prerequisite stage normally installs the required system tools,
but the operating-system check must happen before that stage."
fi

OS_ID="$(lsb_release -is)"
OS_RELEASE="$(lsb_release -rs)"
OS_CODENAME="$(lsb_release -cs)"

print_info "Distribution : $OS_ID"
print_info "Release      : $OS_RELEASE"
print_info "Codename     : $OS_CODENAME"

[[ "$OS_ID" == "$EXPECTED_OS_ID" ]] || \
    die "This setup is for Ubuntu only.

Detected: $OS_ID"

[[ "$OS_CODENAME" == "$EXPECTED_OS_CODENAME" ]] || \
    die "This setup is specifically for Ubuntu 24.04 (Noble).

Detected: Ubuntu $OS_RELEASE ($OS_CODENAME)"

if [[ "$OS_RELEASE" != "$EXPECTED_OS_RELEASE" ]]; then
    print_warning "Expected Ubuntu $EXPECTED_OS_RELEASE but detected Ubuntu $OS_RELEASE."
    print_warning "The codename is noble, so the setup will continue."
fi

print_success "Ubuntu 24.04 (Noble) detected"

# ------------------------------------------------------------------------------
# 4. Architecture check
# ------------------------------------------------------------------------------

print_step "Checking system architecture"

ARCHITECTURE="$(dpkg --print-architecture)"

print_info "Architecture: $ARCHITECTURE"

case "$ARCHITECTURE" in
    amd64)
        print_success "amd64 detected"
        ;;
    arm64)
        print_warning "arm64 detected."
        print_warning "The POC is primarily validated on amd64."
        ;;
    *)
        die "Unsupported architecture: $ARCHITECTURE"
        ;;
esac

# ------------------------------------------------------------------------------
# 5. Check sudo
# ------------------------------------------------------------------------------

print_step "Checking sudo access"

if ! command -v sudo >/dev/null 2>&1; then
    die "sudo is not installed."
fi

if ! sudo -v; then
    die "Unable to obtain sudo privileges."
fi

print_success "sudo access verified"

# ------------------------------------------------------------------------------
# 6. Display setup plan
# ------------------------------------------------------------------------------

print_header "Ubuntu 24.04 Setup Plan"

echo "The following stages will be executed in order:"
echo
echo "    1. Prerequisites"
echo "       $PREREQ_SCRIPT"
echo
echo "    2. ROS 2 Jazzy"
echo "       $ROS_SCRIPT"
echo
echo "    3. Gazebo Harmonic"
echo "       $GAZEBO_SCRIPT"
echo
echo "    4. ArduPilot"
echo "       $ARDUPILOT_SCRIPT"
echo
echo "    5. ArduPilot-Gazebo"
echo "       $ARDUPILOT_GAZEBO_SCRIPT"
echo
echo "    6. Drone Detection POC"
echo "       $PROJECT_SCRIPT"
echo
echo "If any stage fails, execution stops immediately."
echo

# ------------------------------------------------------------------------------
# 7. Confirm all setup scripts exist before starting
# ------------------------------------------------------------------------------

print_step "Checking all setup scripts"

SETUP_SCRIPTS=(
    "$PREREQ_SCRIPT"
    "$ROS_SCRIPT"
    "$GAZEBO_SCRIPT"
    "$ARDUPILOT_SCRIPT"
    "$ARDUPILOT_GAZEBO_SCRIPT"
    "$PROJECT_SCRIPT"
)

for SCRIPT in "${SETUP_SCRIPTS[@]}"; do
    if [[ -f "$SCRIPT" ]]; then
        print_success "$(basename "$SCRIPT")"
    else
        die "Required setup script is missing:

    $SCRIPT"
    fi
done

print_success "All Ubuntu 24.04 setup stages are available"

# ------------------------------------------------------------------------------
# 8. Make all setup scripts executable
# ------------------------------------------------------------------------------

print_step "Preparing setup scripts"

for SCRIPT in "${SETUP_SCRIPTS[@]}"; do
    if [[ ! -x "$SCRIPT" ]]; then
        chmod +x "$SCRIPT"
        print_info "Made executable: $(basename "$SCRIPT")"
    fi
done

print_success "Setup scripts are executable"

# ------------------------------------------------------------------------------
# 9. Export project-level locations
# ------------------------------------------------------------------------------

print_step "Preparing setup environment"

export DRONE_DETECTION_POC_DIR="$PROJECT_DIR"
export ARDUPILOT_DIR="${ARDUPILOT_DIR:-$HOME/ardupilot}"
export ARDUPILOT_GAZEBO_DIR="${ARDUPILOT_GAZEBO_DIR:-$HOME/gz_ws/src/ardupilot_gazebo}"
export GZ_VERSION="harmonic"

print_info "DRONE_DETECTION_POC_DIR=$DRONE_DETECTION_POC_DIR"
print_info "ARDUPILOT_DIR=$ARDUPILOT_DIR"
print_info "ARDUPILOT_GAZEBO_DIR=$ARDUPILOT_GAZEBO_DIR"
print_info "GZ_VERSION=$GZ_VERSION"

print_success "Setup environment prepared"

# ------------------------------------------------------------------------------
# 10. Execute stages
# ------------------------------------------------------------------------------

TOTAL_STAGES=6

run_stage \
    "1" \
    "$TOTAL_STAGES" \
    "System Prerequisites" \
    "$PREREQ_SCRIPT"

run_stage \
    "2" \
    "$TOTAL_STAGES" \
    "ROS 2 Jazzy" \
    "$ROS_SCRIPT"

run_stage \
    "3" \
    "$TOTAL_STAGES" \
    "Gazebo Harmonic" \
    "$GAZEBO_SCRIPT"

run_stage \
    "4" \
    "$TOTAL_STAGES" \
    "ArduPilot SITL" \
    "$ARDUPILOT_SCRIPT"

run_stage \
    "5" \
    "$TOTAL_STAGES" \
    "ArduPilot-Gazebo" \
    "$ARDUPILOT_GAZEBO_SCRIPT"

run_stage \
    "6" \
    "$TOTAL_STAGES" \
    "Drone Detection POC" \
    "$PROJECT_SCRIPT"

# ------------------------------------------------------------------------------
# 11. Final validation
# ------------------------------------------------------------------------------

print_header "Final Installation Validation"

# ROS
print_step "Validating ROS 2 Jazzy"

if [[ -f "/opt/ros/jazzy/setup.bash" ]]; then
    # shellcheck disable=SC1091
    source "/opt/ros/jazzy/setup.bash"
    print_success "ROS 2 Jazzy setup file exists"
else
    die "ROS 2 Jazzy setup file was not found."
fi

if command -v ros2 >/dev/null 2>&1; then
    print_success "ros2 command is available"
else
    die "ros2 command is not available."
fi

# Gazebo
print_step "Validating Gazebo Harmonic"

if command -v gz >/dev/null 2>&1; then
    print_success "gz command is available"
else
    die "gz command is not available."
fi

if gz sim --help >/dev/null 2>&1; then
    print_success "Gazebo Sim is available"
else
    die "Gazebo Sim validation failed."
fi

# ArduPilot
print_step "Validating ArduPilot"

if [[ -f "$ARDUPILOT_DIR/Tools/autotest/sim_vehicle.py" ]]; then
    print_success "ArduPilot sim_vehicle.py exists"
else
    die "ArduPilot sim_vehicle.py was not found."
fi

if [[ -x "$ARDUPILOT_DIR/build/sitl/bin/arducopter" ]]; then
    print_success "ArduCopter SITL binary exists"
else
    die "ArduCopter SITL binary was not found."
fi

# ArduPilot-Gazebo
print_step "Validating ArduPilot-Gazebo"

ARDUPILOT_PLUGIN="$ARDUPILOT_GAZEBO_DIR/build/libArduPilotPlugin.so"

if [[ -f "$ARDUPILOT_PLUGIN" ]]; then
    print_success "libArduPilotPlugin.so exists"
else
    die "ArduPilotPlugin was not found:

    $ARDUPILOT_PLUGIN"
fi

# Project
print_step "Validating Drone Detection POC"

if [[ -f "$PROJECT_DIR/install/setup.bash" ]]; then
    print_success "POC install/setup.bash exists"
else
    die "POC install/setup.bash was not found."
fi

# shellcheck disable=SC1090
source "$PROJECT_DIR/install/setup.bash"

if ros2 pkg prefix drone_detector >/dev/null 2>&1; then
    print_success "drone_detector ROS package is registered"
else
    die "drone_detector ROS package is not registered."
fi

# ------------------------------------------------------------------------------
# 12. Final version/commit summary
# ------------------------------------------------------------------------------

print_header "Installed Component Summary"

ARDUPILOT_COMMIT="$(git -C "$ARDUPILOT_DIR" rev-parse HEAD 2>/dev/null || true)"
ARDUPILOT_VERSION="$(git -C "$ARDUPILOT_DIR" describe --tags --always --dirty 2>/dev/null || true)"

ARDUPILOT_GAZEBO_COMMIT="$(
    git -C "$ARDUPILOT_GAZEBO_DIR" rev-parse HEAD 2>/dev/null || true
)"
ARDUPILOT_GAZEBO_VERSION="$(
    git -C "$ARDUPILOT_GAZEBO_DIR" describe --tags --always --dirty 2>/dev/null || true
)"

echo "Operating System:"
echo "    Ubuntu $OS_RELEASE ($OS_CODENAME)"
echo
echo "ROS:"
echo "    ROS 2 Jazzy"
echo
echo "Gazebo:"
echo "    Gazebo Harmonic / Gazebo Sim 8"
echo
echo "ArduPilot:"
echo "    Location : $ARDUPILOT_DIR"
echo "    Version  : ${ARDUPILOT_VERSION:-<unknown>}"
echo "    Commit   : ${ARDUPILOT_COMMIT:-<unknown>}"
echo
echo "ArduPilot-Gazebo:"
echo "    Location : $ARDUPILOT_GAZEBO_DIR"
echo "    Version  : ${ARDUPILOT_GAZEBO_VERSION:-<unknown>}"
echo "    Commit   : ${ARDUPILOT_GAZEBO_COMMIT:-<unknown>}"
echo "    Plugin   : $ARDUPILOT_PLUGIN"
echo
echo "Drone Detection POC:"
echo "    Location : $PROJECT_DIR"
echo "    Package  : drone_detector"
echo

# ------------------------------------------------------------------------------
# 13. Final instructions
# ------------------------------------------------------------------------------

print_header "Ubuntu 24.04 Setup Complete"

echo "All six setup stages completed successfully."
echo
echo "The environment now contains:"
echo
echo "    ROS 2 Jazzy"
echo "        ↓"
echo "    Gazebo Harmonic"
echo "        ↓"
echo "    ArduPilot SITL"
echo "        ↓"
echo "    ArduPilot-Gazebo"
echo "        ↓"
echo "    Drone Detection POC"
echo
echo "For a new terminal, source the POC environment with:"
echo
echo "    source $PROJECT_DIR/config/environment.sh"
echo "    source $PROJECT_DIR/install/setup.bash"
echo
echo "Important:"
echo "    ArduPilot remains at:"
echo "        $ARDUPILOT_DIR"
echo
echo "    ArduPilot-Gazebo remains at:"
echo "        $ARDUPILOT_GAZEBO_DIR"
echo
echo "    Project-specific Gazebo resources remain at:"
echo "        $PROJECT_DIR/simulation/gazebo"
echo
echo "The setup scripts do not copy external repositories into the POC."
echo
echo "The next step is simulation validation using the existing POC scripts."
echo
echo "No setup log files were created."
echo
