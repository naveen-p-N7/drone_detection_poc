#!/usr/bin/env bash

# ==============================================================================
# Drone Detection POC
# ArduPilot Setup - Ubuntu 22.04 / 24.04
# ==============================================================================
#
# Purpose:
#   Install, clone, initialize, and build ArduPilot SITL as an external
#   dependency of the Drone Detection POC.
#
# This script:
#   - Supports Ubuntu 22.04 (Jammy) and Ubuntu 24.04 (Noble)
#   - Installs the ArduPilot build/SITL prerequisites using ArduPilot's
#     official install-prereqs-ubuntu.sh script
#   - Clones ArduPilot with its submodules when the repository is absent
#   - Reuses an existing ~/ardupilot checkout instead of overwriting it
#   - Initializes and updates Git submodules
#   - Builds ArduCopter SITL
#   - Verifies sim_vehicle.py, SITL, pymavlink, and MAVProxy
#
# This script does NOT:
#   - Copy ArduPilot into the Drone Detection POC repository
#   - Install Gazebo
#   - Install ArduPilot-Gazebo
#   - Modify the POC source tree
#   - Create setup log files
#   - Automatically checkout a different ArduPilot commit
#
# Default external dependency location:
#   $HOME/ardupilot
#
# The POC intentionally keeps ArduPilot outside:
#   $HOME/drone_detection_poc
#
# Usage:
#   chmod +x ardupilot_setup.sh
#   ./ardupilot_setup.sh
#
# Notes:
#   - The ArduPilot prerequisite installer may modify ~/.profile and other
#     shell configuration as part of its normal operation.
#   - A new login shell may be required before every PATH change becomes
#     permanent.
#
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

ARDUPILOT_REPO_URL="https://github.com/ArduPilot/ardupilot.git"
ARDUPILOT_DIR="${ARDUPILOT_DIR:-$HOME/ardupilot}"
ARDUPILOT_BRANCH="${ARDUPILOT_BRANCH:-master}"

EXPECTED_UBUNTU_CODENAMES=("jammy" "noble")
VEHICLE_DIR="${ARDUPILOT_DIR}/ArduCopter"
PREREQ_SCRIPT="${ARDUPILOT_DIR}/Tools/environment_install/install-prereqs-ubuntu.sh"
SITL_SCRIPT="${ARDUPILOT_DIR}/Tools/autotest/sim_vehicle.py"

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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null \
        | grep -q "install ok installed"
}

# ------------------------------------------------------------------------------
# Start
# ------------------------------------------------------------------------------

print_header "Drone Detection POC - ArduPilot Setup"

# ------------------------------------------------------------------------------
# 1. Root check
# ------------------------------------------------------------------------------

if [[ "${EUID}" -eq 0 ]]; then
    die "Do not run this script as root.

Run it as your normal user:

    ./ardupilot_setup.sh

The script will use sudo when required."
fi

# ------------------------------------------------------------------------------
# 2. Check operating system
# ------------------------------------------------------------------------------

print_step "Checking operating system"

command_exists lsb_release || \
    die "lsb_release is not installed."

OS_ID="$(lsb_release -is)"
OS_RELEASE="$(lsb_release -rs)"
OS_CODENAME="$(lsb_release -cs)"

print_info "Distribution : $OS_ID"
print_info "Release      : $OS_RELEASE"
print_info "Codename     : $OS_CODENAME"

[[ "$OS_ID" == "Ubuntu" ]] || \
    die "This script supports Ubuntu only. Detected: $OS_ID"

case "$OS_CODENAME" in
    jammy)
        print_success "Ubuntu 22.04 (Jammy) detected"
        ;;
    noble)
        print_success "Ubuntu 24.04 (Noble) detected"
        ;;
    *)
        die "Unsupported Ubuntu release: $OS_RELEASE ($OS_CODENAME).

Supported releases:
    Ubuntu 22.04 (Jammy)
    Ubuntu 24.04 (Noble)"
        ;;
esac

# ------------------------------------------------------------------------------
# 3. Architecture check
# ------------------------------------------------------------------------------

print_step "Checking system architecture"

ARCHITECTURE="$(dpkg --print-architecture)"
print_info "Architecture: $ARCHITECTURE"

case "$ARCHITECTURE" in
    amd64)
        print_success "amd64 architecture detected"
        ;;
    arm64)
        print_warning "arm64 detected."
        print_warning "ArduPilot SITL can be built on Linux, but this POC is primarily"
        print_warning "validated on amd64."
        ;;
    *)
        die "Unsupported architecture: $ARCHITECTURE"
        ;;
esac

# ------------------------------------------------------------------------------
# 4. Check basic tools
# ------------------------------------------------------------------------------

print_step "Checking basic system tools"

for TOOL in git curl python3 pip3 make gcc g++ cmake; do
    if command_exists "$TOOL"; then
        print_success "$TOOL -> $(command -v "$TOOL")"
    else
        print_warning "$TOOL is not currently available"
    fi
done

print_info "Installing basic tools required before running ArduPilot's prerequisite installer"

sudo apt-get update
sudo apt-get install -y \
    git \
    curl \
    ca-certificates \
    python3 \
    python3-pip \
    build-essential \
    cmake

print_success "Basic system tools are available"

# ------------------------------------------------------------------------------
# 5. Check/install ArduPilot source tree
# ------------------------------------------------------------------------------

print_step "Checking ArduPilot source tree"

if [[ -d "$ARDUPILOT_DIR/.git" ]]; then
    print_success "Existing ArduPilot Git repository found"
    print_info "Location: $ARDUPILOT_DIR"
else
    if [[ -e "$ARDUPILOT_DIR" ]]; then
        die "The ArduPilot path exists but is not a Git repository:

    $ARDUPILOT_DIR

Move/remove that directory or set ARDUPILOT_DIR to another location."
    fi

    print_info "Cloning ArduPilot"
    print_info "Repository: $ARDUPILOT_REPO_URL"
    print_info "Branch    : $ARDUPILOT_BRANCH"
    print_info "Location  : $ARDUPILOT_DIR"

    git clone \
        --branch "$ARDUPILOT_BRANCH" \
        --recurse-submodules \
        "$ARDUPILOT_REPO_URL" \
        "$ARDUPILOT_DIR"

    print_success "ArduPilot repository cloned"
fi

cd "$ARDUPILOT_DIR"

# ------------------------------------------------------------------------------
# 6. Verify Git repository
# ------------------------------------------------------------------------------

print_step "Verifying ArduPilot Git repository"

REPO_REMOTE="$(git config --get remote.origin.url || true)"
CURRENT_BRANCH="$(git branch --show-current || true)"
CURRENT_COMMIT="$(git rev-parse HEAD)"

print_info "Remote : ${REPO_REMOTE:-<not configured>}"
print_info "Branch : ${CURRENT_BRANCH:-<detached HEAD>}"
print_info "Commit : $CURRENT_COMMIT"

if [[ "$REPO_REMOTE" != *"github.com/ArduPilot/ardupilot"* ]]; then
    print_warning "The existing repository remote does not look like the official"
    print_warning "ArduPilot repository."
    print_warning "The script will continue without changing the remote."
fi

print_success "ArduPilot repository is accessible"

# ------------------------------------------------------------------------------
# 7. Initialize/update Git submodules
# ------------------------------------------------------------------------------

print_step "Initializing ArduPilot Git submodules"

git submodule sync --recursive
git submodule update --init --recursive

print_success "ArduPilot submodules are initialized and synchronized"

# ------------------------------------------------------------------------------
# 8. Show repository state
# ------------------------------------------------------------------------------

print_step "Checking repository state"

if [[ -n "$(git status --short)" ]]; then
    print_warning "The ArduPilot working tree contains local changes:"
    git status --short
    echo
    print_warning "Existing local changes will NOT be overwritten by this script."
else
    print_success "ArduPilot working tree is clean"
fi

# ------------------------------------------------------------------------------
# 9. Verify ArduPilot prerequisite installer
# ------------------------------------------------------------------------------

print_step "Checking ArduPilot prerequisite installer"

[[ -f "$PREREQ_SCRIPT" ]] || \
    die "ArduPilot prerequisite installer was not found:

    $PREREQ_SCRIPT"

[[ -x "$PREREQ_SCRIPT" ]] || \
    chmod +x "$PREREQ_SCRIPT"

print_success "ArduPilot prerequisite installer is available"

# ------------------------------------------------------------------------------
# 10. Install ArduPilot prerequisites
# ------------------------------------------------------------------------------

print_step "Installing ArduPilot build and SITL prerequisites"

print_info "Running the official ArduPilot prerequisite installer:"
print_info "    $PREREQ_SCRIPT -y"
echo
print_info "This may install:"
print_info "    C/C++ build tools"
print_info "    Python development/runtime packages"
print_info "    pymavlink"
print_info "    MAVProxy"
print_info "    empy"
print_info "    pexpect"
print_info "    dronecan"
print_info "    SITL-related dependencies"
print_info "    ccache"
print_info "    other ArduPilot build dependencies"
echo

"$PREREQ_SCRIPT" -y

print_success "ArduPilot prerequisites installed"

# ------------------------------------------------------------------------------
# 11. Check dialout group
# ------------------------------------------------------------------------------

print_step "Checking dialout group membership"

if id -nG "$USER" | tr ' ' '\n' | grep -qx "dialout"; then
    print_success "User $USER is already a member of dialout"
else
    print_warning "User $USER is not currently a member of dialout"
    print_info "Adding user to dialout group"
    sudo usermod -a -G dialout "$USER"
    print_warning "A logout/login may be required for the group change to take effect."
fi

# ------------------------------------------------------------------------------
# 12. Locate Python tooling
# ------------------------------------------------------------------------------

print_step "Checking Python environment"

print_info "Python:"
python3 --version

print_info "Python executable:"
command -v python3

if command_exists pip3; then
    print_info "pip3:"
    pip3 --version
else
    print_warning "pip3 is not available in the current PATH"
fi

# ------------------------------------------------------------------------------
# 13. Verify pymavlink
# ------------------------------------------------------------------------------

print_step "Checking pymavlink"

if python3 -c "import pymavlink" >/dev/null 2>&1; then
    print_success "pymavlink is importable"
else
    print_warning "pymavlink is not importable in the current Python environment."
    print_warning "The prerequisite installer may have configured it in another"
    print_warning "environment or the current shell may need to be refreshed."
fi

# ------------------------------------------------------------------------------
# 14. Verify MAVProxy
# ------------------------------------------------------------------------------

print_step "Checking MAVProxy"

if command_exists mavproxy.py; then
    print_success "MAVProxy is available"
    print_info "MAVProxy: $(command -v mavproxy.py)"
else
    print_warning "mavproxy.py is not currently available in PATH."
    print_warning "A new shell may be required after prerequisite installation."
fi

# ------------------------------------------------------------------------------
# 15. Verify sim_vehicle.py
# ------------------------------------------------------------------------------

print_step "Checking sim_vehicle.py"

[[ -f "$SITL_SCRIPT" ]] || \
    die "sim_vehicle.py was not found:

    $SITL_SCRIPT"

[[ -x "$SITL_SCRIPT" ]] || chmod +x "$SITL_SCRIPT"

print_success "sim_vehicle.py exists"
print_info "Location: $SITL_SCRIPT"

# ------------------------------------------------------------------------------
# 16. Verify ArduPilot Waf
# ------------------------------------------------------------------------------

print_step "Checking ArduPilot Waf build system"

[[ -f "$ARDUPILOT_DIR/waf" ]] || \
    die "ArduPilot waf script was not found:

    $ARDUPILOT_DIR/waf"

[[ -x "$ARDUPILOT_DIR/waf" ]] || chmod +x "$ARDUPILOT_DIR/waf"

print_success "ArduPilot waf is available"

# ------------------------------------------------------------------------------
# 17. Build ArduCopter SITL
# ------------------------------------------------------------------------------

print_step "Building ArduCopter SITL"

[[ -d "$VEHICLE_DIR" ]] || \
    die "ArduCopter directory was not found:

    $VEHICLE_DIR"

cd "$VEHICLE_DIR"

print_info "Building from:"
print_info "    $VEHICLE_DIR"
echo

print_info "Running:"
print_info "    ../waf configure --board sitl"
echo

"$ARDUPILOT_DIR/waf" configure --board sitl

print_success "ArduCopter SITL configuration completed"

print_info "Running:"
print_info "    ../waf copter"
echo

"$ARDUPILOT_DIR/waf" copter

print_success "ArduCopter SITL build completed"

# ------------------------------------------------------------------------------
# 18. Verify SITL binary
# ------------------------------------------------------------------------------

print_step "Checking generated ArduCopter SITL binary"

SITL_BINARY="$ARDUPILOT_DIR/build/sitl/bin/arducopter"

if [[ -x "$SITL_BINARY" ]]; then
    print_success "ArduCopter SITL binary exists"
    print_info "Binary: $SITL_BINARY"
else
    die "ArduCopter SITL binary was not found:

    $SITL_BINARY"
fi

# ------------------------------------------------------------------------------
# 19. Check sim_vehicle.py help
# ------------------------------------------------------------------------------

print_step "Validating sim_vehicle.py"

if python3 "$SITL_SCRIPT" --help >/dev/null 2>&1; then
    print_success "sim_vehicle.py executes successfully"
else
    print_warning "sim_vehicle.py could not be executed with the current shell."
    print_warning "This may be caused by a Python/PATH environment that needs"
    print_warning "to be refreshed after prerequisite installation."
fi

# ------------------------------------------------------------------------------
# 20. Report ArduPilot version
# ------------------------------------------------------------------------------

print_step "Reporting ArduPilot version"

VERSION_OUTPUT="$(git describe --tags --always --dirty 2>/dev/null || true)"

if [[ -n "$VERSION_OUTPUT" ]]; then
    print_info "ArduPilot version: $VERSION_OUTPUT"
else
    print_warning "Unable to determine ArduPilot version using git describe"
fi

# ------------------------------------------------------------------------------
# 21. Final repository information
# ------------------------------------------------------------------------------

print_step "Final ArduPilot repository information"

cd "$ARDUPILOT_DIR"

FINAL_COMMIT="$(git rev-parse HEAD)"
FINAL_BRANCH="$(git branch --show-current || true)"

print_info "Location : $ARDUPILOT_DIR"
print_info "Branch   : ${FINAL_BRANCH:-<detached HEAD>}"
print_info "Commit   : $FINAL_COMMIT"
print_info "Version  : ${VERSION_OUTPUT:-<unknown>}"

# ------------------------------------------------------------------------------
# 22. Final summary
# ------------------------------------------------------------------------------

print_header "ArduPilot Setup Complete"

echo "ArduPilot has been installed and built successfully."
echo
echo "External dependency:"
echo "    $ARDUPILOT_DIR"
echo
echo "Repository:"
echo "    $ARDUPILOT_REPO_URL"
echo
echo "ArduCopter SITL:"
echo "    $SITL_BINARY"
echo
echo "sim_vehicle.py:"
echo "    $SITL_SCRIPT"
echo
echo "ArduPilot version:"
echo "    ${VERSION_OUTPUT:-<unknown>}"
echo
echo "Next setup stage:"
echo "    ArduPilot-Gazebo"
echo
echo "Important:"
echo "    ArduPilot remains outside the Drone Detection POC repository."
echo
echo "If dialout membership was newly added:"
echo "    Log out and log back in before using hardware serial devices."
echo
echo "For SITL, you can run:"
echo "    cd $VEHICLE_DIR"
echo "    python3 $SITL_SCRIPT -v ArduCopter -f gazebo-iris --model JSON"
echo
echo "No setup log files were created."
echo
