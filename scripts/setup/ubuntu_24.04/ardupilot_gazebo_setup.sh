#!/usr/bin/env bash

# ==============================================================================
# Drone Detection POC
# ArduPilot-Gazebo Setup - Ubuntu 22.04 / 24.04
# ==============================================================================
#
# Purpose:
#   Install, clone, configure, and build the official ArduPilot-Gazebo plugin
#   for Gazebo Harmonic.
#
# Architecture:
#
#   Drone Detection POC
#          |
#          +---- ArduPilot SITL
#          |       ~/ardupilot
#          |
#          +---- Gazebo Harmonic
#          |       installed system-wide
#          |
#          +---- ArduPilot-Gazebo
#                  ~/gz_ws/src/ardupilot_gazebo
#                  |
#                  +---- libArduPilotPlugin.so
#
# The POC keeps ArduPilot-Gazebo OUTSIDE the POC repository.
#
# This script:
#   - Supports Ubuntu 22.04 (Jammy) and Ubuntu 24.04 (Noble)
#   - Requires Gazebo Harmonic to already be installed
#   - Requires ArduPilot to already be installed
#   - Clones the official ArduPilot-Gazebo repository when absent
#   - Initializes Git submodules
#   - Installs the official Harmonic build dependencies
#   - Configures GZ_VERSION=harmonic
#   - Builds ArduPilot-Gazebo using CMake
#   - Verifies libArduPilotPlugin.so
#   - Verifies the project models/worlds
#
# This script does NOT:
#   - Copy ArduPilot-Gazebo into ~/drone_detection_poc
#   - Copy .so files into the POC
#   - Modify ~/.bashrc
#   - Modify ~/.profile
#   - Modify the user's existing Gazebo environment permanently
#   - Replace custom POC models/worlds
#   - Checkout a different commit automatically
#   - Create setup log files
#
# Default external dependency:
#   $HOME/gz_ws/src/ardupilot_gazebo
#
# Official repository:
#   https://github.com/ArduPilot/ardupilot_gazebo
#
# Current POC-tested repository commit can be pinned later in versions.sh.
#
# Usage:
#   chmod +x ardupilot_gazebo_setup.sh
#   ./ardupilot_gazebo_setup.sh
#
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

ARDUPILOT_GAZEBO_REPO_URL="https://github.com/ArduPilot/ardupilot_gazebo.git"

# Keep this separate from the POC repository.
ARDUPILOT_GAZEBO_DIR="${ARDUPILOT_GAZEBO_DIR:-$HOME/gz_ws/src/ardupilot_gazebo}"

# Gazebo version used by this POC.
GZ_VERSION_EXPECTED="harmonic"

# Gazebo Harmonic uses Gazebo Sim 8.
GZ_SIM_MAJOR="8"

BUILD_TYPE="${BUILD_TYPE:-RelWithDebInfo}"

# Number of parallel build jobs.
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"

BUILD_DIR="${ARDUPILOT_GAZEBO_DIR}/build"

PLUGIN_LIBRARY="${BUILD_DIR}/libArduPilotPlugin.so"

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

print_header "Drone Detection POC - ArduPilot-Gazebo Setup"

# ------------------------------------------------------------------------------
# 1. Root check
# ------------------------------------------------------------------------------

if [[ "${EUID}" -eq 0 ]]; then
    die "Do not run this script as root.

Run it as your normal user:

    ./ardupilot_gazebo_setup.sh

The script will use sudo when required."
fi

# ------------------------------------------------------------------------------
# 2. Operating system check
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
        print_warning "The POC is primarily validated on amd64."
        ;;
    *)
        die "Unsupported architecture: $ARCHITECTURE"
        ;;
esac

# ------------------------------------------------------------------------------
# 4. Check ArduPilot
# ------------------------------------------------------------------------------

print_step "Checking ArduPilot dependency"

ARDUPILOT_DIR="${ARDUPILOT_DIR:-$HOME/ardupilot}"

if [[ -d "$ARDUPILOT_DIR/.git" ]]; then
    print_success "ArduPilot repository found"
    print_info "Location: $ARDUPILOT_DIR"
else
    die "ArduPilot repository was not found at:

    $ARDUPILOT_DIR

Run ardupilot_setup.sh first, or set ARDUPILOT_DIR to the correct checkout."
fi

if [[ -f "$ARDUPILOT_DIR/Tools/autotest/sim_vehicle.py" ]]; then
    print_success "sim_vehicle.py found"
else
    die "sim_vehicle.py was not found in the ArduPilot checkout."
fi

# ------------------------------------------------------------------------------
# 5. Check Gazebo Harmonic
# ------------------------------------------------------------------------------

print_step "Checking Gazebo Harmonic"

command_exists gz || \
    die "The 'gz' command was not found.

Run gazebo_harmonic_setup.sh first."

print_info "Gazebo command: $(command -v gz)"

if gz sim --help >/dev/null 2>&1; then
    print_success "gz sim is available"
else
    die "Gazebo Sim is not working correctly."
fi

# ------------------------------------------------------------------------------
# 6. Check Gazebo Sim 8 development package
# ------------------------------------------------------------------------------

print_step "Checking Gazebo Sim 8 development package"

if package_installed "libgz-sim8-dev"; then
    print_success "libgz-sim8-dev is installed"
else
    die "libgz-sim8-dev is not installed.

Run gazebo_harmonic_setup.sh first."
fi

# ------------------------------------------------------------------------------
# 7. Configure GZ_VERSION for current process
# ------------------------------------------------------------------------------

print_step "Configuring Gazebo version"

export GZ_VERSION="$GZ_VERSION_EXPECTED"

print_info "GZ_VERSION=$GZ_VERSION"

print_success "GZ_VERSION configured for this setup"

# ------------------------------------------------------------------------------
# 8. Install build dependencies
# ------------------------------------------------------------------------------

print_step "Installing ArduPilot-Gazebo build dependencies"

print_info "Updating APT package information"
sudo apt-get update

print_info "Installing CMake/build dependencies"

sudo apt-get install -y \
    build-essential \
    cmake \
    make \
    g++ \
    git \
    ccache

print_success "Core build dependencies installed"

print_info "Installing ArduPilot-Gazebo Harmonic dependencies"

sudo apt-get install -y \
    libgz-sim8-dev \
    rapidjson-dev \
    libunwind-dev \
    libopencv-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-libav \
    gstreamer1.0-gl

print_success "ArduPilot-Gazebo dependencies installed"

# ------------------------------------------------------------------------------
# 9. Check/create parent directory
# ------------------------------------------------------------------------------

print_step "Preparing ArduPilot-Gazebo source location"

SOURCE_PARENT="$(dirname "$ARDUPILOT_GAZEBO_DIR")"

mkdir -p "$SOURCE_PARENT"

print_info "Source parent: $SOURCE_PARENT"
print_info "Repository   : $ARDUPILOT_GAZEBO_DIR"

print_success "Source location is ready"

# ------------------------------------------------------------------------------
# 10. Clone repository if necessary
# ------------------------------------------------------------------------------

print_step "Checking ArduPilot-Gazebo repository"

if [[ -d "$ARDUPILOT_GAZEBO_DIR/.git" ]]; then
    print_success "Existing ArduPilot-Gazebo Git repository found"
else
    if [[ -e "$ARDUPILOT_GAZEBO_DIR" ]]; then
        die "The configured ArduPilot-Gazebo path exists but is not a Git repository:

    $ARDUPILOT_GAZEBO_DIR

Move/remove that directory or set ARDUPILOT_GAZEBO_DIR to another location."
    fi

    print_info "Cloning official ArduPilot-Gazebo repository"
    print_info "Repository: $ARDUPILOT_GAZEBO_REPO_URL"
    print_info "Location  : $ARDUPILOT_GAZEBO_DIR"

    git clone \
        --recurse-submodules \
        "$ARDUPILOT_GAZEBO_REPO_URL" \
        "$ARDUPILOT_GAZEBO_DIR"

    print_success "ArduPilot-Gazebo repository cloned"
fi

cd "$ARDUPILOT_GAZEBO_DIR"

# ------------------------------------------------------------------------------
# 11. Verify repository remote
# ------------------------------------------------------------------------------

print_step "Verifying ArduPilot-Gazebo repository"

REPO_REMOTE="$(git config --get remote.origin.url || true)"
CURRENT_BRANCH="$(git branch --show-current || true)"
CURRENT_COMMIT="$(git rev-parse HEAD)"

print_info "Remote : ${REPO_REMOTE:-<not configured>}"
print_info "Branch : ${CURRENT_BRANCH:-<detached HEAD>}"
print_info "Commit : $CURRENT_COMMIT"

if [[ "$REPO_REMOTE" != *"github.com/ArduPilot/ardupilot_gazebo"* ]]; then
    print_warning "The existing repository remote does not look like the official"
    print_warning "ArduPilot-Gazebo repository."
    print_warning "The script will not change the remote automatically."
fi

print_success "Repository is accessible"

# ------------------------------------------------------------------------------
# 12. Initialize/update submodules
# ------------------------------------------------------------------------------

print_step "Initializing ArduPilot-Gazebo Git submodules"

git submodule sync --recursive
git submodule update --init --recursive

print_success "Git submodules synchronized"

# ------------------------------------------------------------------------------
# 13. Check source tree state
# ------------------------------------------------------------------------------

print_step "Checking repository state"

if [[ -n "$(git status --short)" ]]; then
    print_warning "The ArduPilot-Gazebo working tree contains local changes:"
    git status --short
    echo
    print_warning "Existing local changes will NOT be overwritten."
else
    print_success "ArduPilot-Gazebo working tree is clean"
fi

# ------------------------------------------------------------------------------
# 14. Check required source files
# ------------------------------------------------------------------------------

print_step "Checking ArduPilot-Gazebo source tree"

[[ -f "$ARDUPILOT_GAZEBO_DIR/CMakeLists.txt" ]] || \
    die "CMakeLists.txt was not found."

[[ -f "$ARDUPILOT_GAZEBO_DIR/package.xml" ]] || \
    print_warning "package.xml was not found. Continuing because this build"
    print_warning "is being performed directly with CMake."

[[ -d "$ARDUPILOT_GAZEBO_DIR/models" ]] || \
    print_warning "models directory is missing."

[[ -d "$ARDUPILOT_GAZEBO_DIR/worlds" ]] || \
    print_warning "worlds directory is missing."

print_success "ArduPilot-Gazebo source tree is available"

# ------------------------------------------------------------------------------
# 15. Configure ccache
# ------------------------------------------------------------------------------

print_step "Checking ccache"

if command_exists ccache; then
    print_success "ccache is available"

    export PATH="/usr/lib/ccache:$PATH"

    print_info "ccache directory added to current PATH"
else
    print_warning "ccache is not available."
    print_warning "The build will continue without ccache."
fi

# ------------------------------------------------------------------------------
# 16. Prepare clean/configurable build directory
# ------------------------------------------------------------------------------

print_step "Preparing CMake build directory"

mkdir -p "$BUILD_DIR"

print_info "Build directory: $BUILD_DIR"
print_info "Build type     : $BUILD_TYPE"
print_info "Build jobs     : $BUILD_JOBS"

print_success "Build directory is ready"

# ------------------------------------------------------------------------------
# 17. Configure CMake
# ------------------------------------------------------------------------------

print_step "Configuring ArduPilot-Gazebo with CMake"

cd "$BUILD_DIR"

print_info "Running:"
print_info "    cmake .. -DCMAKE_BUILD_TYPE=$BUILD_TYPE"
echo

cmake .. \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE"

print_success "CMake configuration completed"

# ------------------------------------------------------------------------------
# 18. Build plugin
# ------------------------------------------------------------------------------

print_step "Building ArduPilot-Gazebo"

print_info "Running:"
print_info "    cmake --build . --parallel $BUILD_JOBS"
echo

cmake --build . --parallel "$BUILD_JOBS"

print_success "ArduPilot-Gazebo build completed"

# ------------------------------------------------------------------------------
# 19. Verify generated libraries
# ------------------------------------------------------------------------------

print_step "Checking generated ArduPilot-Gazebo libraries"

EXPECTED_LIBRARIES=(
    "libArduPilotPlugin.so"
    "libCameraZoomPlugin.so"
    "libGstCameraPlugin.so"
    "libParachutePlugin.so"
)

for LIBRARY in "${EXPECTED_LIBRARIES[@]}"; do
    LIBRARY_PATH="$BUILD_DIR/$LIBRARY"

    if [[ -f "$LIBRARY_PATH" ]]; then
        print_success "$LIBRARY"
        print_info "  Path: $LIBRARY_PATH"
    else
        print_warning "$LIBRARY was not generated."
    fi
done

[[ -f "$PLUGIN_LIBRARY" ]] || \
    die "The critical ArduPilotPlugin library was not generated:

    $PLUGIN_LIBRARY

The ArduPilot-Gazebo build did not produce the plugin required by the POC."

print_success "libArduPilotPlugin.so exists"

# ------------------------------------------------------------------------------
# 20. Inspect plugin dependencies
# ------------------------------------------------------------------------------

print_step "Checking ArduPilotPlugin shared-library dependencies"

if command_exists ldd; then
    print_info "Checking for missing shared libraries"

    if ldd "$PLUGIN_LIBRARY" | grep -q "not found"; then
        print_warning "One or more shared-library dependencies are missing:"
        ldd "$PLUGIN_LIBRARY" | grep "not found" || true
        die "ArduPilotPlugin has unresolved shared-library dependencies."
    else
        print_success "ArduPilotPlugin shared-library dependencies are resolved"
    fi
fi

# ------------------------------------------------------------------------------
# 21. Report plugin information
# ------------------------------------------------------------------------------

print_step "Inspecting ArduPilotPlugin"

if command_exists file; then
    print_info "Binary information:"
    file "$PLUGIN_LIBRARY"
fi

if command_exists ldd; then
    print_info "Gazebo-related dependencies detected:"
    ldd "$PLUGIN_LIBRARY" | grep -E "gz-|ignition|opencv|gstreamer" || true
fi

# ------------------------------------------------------------------------------
# 22. Verify models/worlds
# ------------------------------------------------------------------------------

print_step "Checking upstream models and worlds"

if [[ -d "$ARDUPILOT_GAZEBO_DIR/models" ]]; then
    MODEL_COUNT="$(find "$ARDUPILOT_GAZEBO_DIR/models" -mindepth 1 -maxdepth 1 -type d | wc -l)"
    print_info "Model directories: $MODEL_COUNT"
    print_success "Models directory exists"
else
    print_warning "No models directory found."
fi

if [[ -d "$ARDUPILOT_GAZEBO_DIR/worlds" ]]; then
    WORLD_COUNT="$(find "$ARDUPILOT_GAZEBO_DIR/worlds" -maxdepth 1 -type f | wc -l)"
    print_info "World files: $WORLD_COUNT"
    print_success "Worlds directory exists"
else
    print_warning "No worlds directory found."
fi

# ------------------------------------------------------------------------------
# 23. Print environment values for POC configuration
# ------------------------------------------------------------------------------

print_step "Preparing POC Gazebo environment information"

print_info "ArduPilot-Gazebo source:"
print_info "    $ARDUPILOT_GAZEBO_DIR"

print_info "ArduPilot-Gazebo build:"
print_info "    $BUILD_DIR"

print_info "System plugin path required by Gazebo:"
print_info "    $BUILD_DIR"

print_info "Upstream model path:"
print_info "    $ARDUPILOT_GAZEBO_DIR/models"

print_info "Upstream world path:"
print_info "    $ARDUPILOT_GAZEBO_DIR/worlds"

print_info "GZ_VERSION:"
print_info "    $GZ_VERSION"

print_success "POC environment information prepared"

# ------------------------------------------------------------------------------
# 24. Important: do not modify shell startup files
# ------------------------------------------------------------------------------

print_step "Checking shell startup policy"

print_info "This script intentionally does NOT modify:"
print_info "    ~/.bashrc"
print_info "    ~/.profile"
print_info "    ~/.zshrc"

print_info "The Drone Detection POC controls its Gazebo paths through:"
print_info "    config/environment.sh"

print_success "Shell startup files were left unchanged"

# ------------------------------------------------------------------------------
# 25. Final repository information
# ------------------------------------------------------------------------------

print_step "Final ArduPilot-Gazebo repository information"

cd "$ARDUPILOT_GAZEBO_DIR"

FINAL_COMMIT="$(git rev-parse HEAD)"
FINAL_BRANCH="$(git branch --show-current || true)"
FINAL_VERSION="$(git describe --tags --always --dirty 2>/dev/null || true)"

print_info "Location : $ARDUPILOT_GAZEBO_DIR"
print_info "Branch   : ${FINAL_BRANCH:-<detached HEAD>}"
print_info "Commit   : $FINAL_COMMIT"
print_info "Version  : ${FINAL_VERSION:-<unknown>}"

# ------------------------------------------------------------------------------
# 26. Final summary
# ------------------------------------------------------------------------------

print_header "ArduPilot-Gazebo Setup Complete"

echo "ArduPilot-Gazebo has been installed and built successfully."
echo
echo "External dependency:"
echo "    $ARDUPILOT_GAZEBO_DIR"
echo
echo "Repository:"
echo "    $ARDUPILOT_GAZEBO_REPO_URL"
echo
echo "Gazebo:"
echo "    Harmonic"
echo "    Gazebo Sim $GZ_SIM_MAJOR"
echo
echo "Critical plugin:"
echo "    $PLUGIN_LIBRARY"
echo
echo "Plugin path used by the POC:"
echo "    $BUILD_DIR"
echo
echo "Upstream resources:"
echo "    Models : $ARDUPILOT_GAZEBO_DIR/models"
echo "    Worlds : $ARDUPILOT_GAZEBO_DIR/worlds"
echo
echo "Important:"
echo "    ArduPilot-Gazebo remains outside the Drone Detection POC repository."
echo "    The POC should reference this external build through environment.sh."
echo
echo "The next step is to verify the complete:"
echo "    ArduPilot SITL + Gazebo Harmonic + ArduPilot-Gazebo"
echo "    integration using the POC launch scripts."
echo
echo "No setup log files were created."
echo
