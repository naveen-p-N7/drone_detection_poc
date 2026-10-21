#!/usr/bin/env bash

# ==============================================================================
# Drone Detection POC
# Project Setup - Ubuntu 22.04 / 24.04
# ==============================================================================
#
# Purpose:
#   Prepare and build the Drone Detection POC itself after the external
#   dependencies have been installed.
#
# Expected project location:
#   $HOME/drone_detection_poc
#
# Expected external dependencies:
#   ArduPilot:
#       $HOME/ardupilot
#
#   ArduPilot-Gazebo:
#       $HOME/gz_ws/src/ardupilot_gazebo
#
#   Gazebo:
#       Gazebo Harmonic / Gazebo Sim 8
#
#   ROS:
#       Ubuntu 22.04 -> ROS 2 Humble
#       Ubuntu 24.04 -> ROS 2 Jazzy
#
# Project layout prepared by this script:
#
#   drone_detection_poc/
#   ├── config/
#   │   ├── environment.sh
#   │   └── versions.sh                 # optional
#   ├── data/
#   │   └── bags/                       # intentionally empty
#   ├── docs/
#   ├── launch/
#   ├── scripts/
#   │   ├── simulation/
#   │   └── trajectory/
#   ├── simulation/
#   │   └── gazebo/
#   │       ├── models/
#   │       └── worlds/
#   ├── src/
#   │   └── drone_detector/
#   └── tests/
#
# This script:
#   - Validates the POC directory
#   - Detects Ubuntu 22.04 / 24.04
#   - Selects the expected ROS distribution
#   - Sources ROS
#   - Sources the POC environment configuration
#   - Validates ArduPilot, Gazebo, and ArduPilot-Gazebo dependencies
#   - Checks the POC source/package structure
#   - Installs ROS dependencies using rosdep
#   - Builds the POC with colcon
#   - Verifies the drone_detector ROS package
#   - Verifies important project scripts and Gazebo resources
#   - Creates the intentionally empty data/bags directory if needed
#   - Does NOT modify ~/.bashrc or ~/.profile
#
# This script does NOT:
#   - Install ROS
#   - Install Gazebo
#   - Install ArduPilot
#   - Clone ArduPilot
#   - Install/build ArduPilot-Gazebo
#   - Copy external repositories into the POC
#   - Create ROS bag files
#   - Start Gazebo
#   - Start ArduPilot SITL
#   - Modify shell startup files
#   - Create setup log files
#
# Prerequisite order:
#
#   1. prereq.sh
#   2. ros2_*_setup.sh
#   3. gazebo_harmonic_setup.sh
#   4. ardupilot_setup.sh
#   5. ardupilot_gazebo_setup.sh
#   6. project_setup.sh       <-- this script
#
# Usage:
#   chmod +x project_setup.sh
#   ./project_setup.sh
#
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

PROJECT_DIR="${DRONE_DETECTION_POC_DIR:-$HOME/drone_detection_poc}"

ARDUPILOT_DIR="${ARDUPILOT_DIR:-$HOME/ardupilot}"

ARDUPILOT_GAZEBO_DIR="${ARDUPILOT_GAZEBO_DIR:-$HOME/gz_ws/src/ardupilot_gazebo}"

ROS_HUMBLE_SETUP="/opt/ros/humble/setup.bash"
ROS_JAZZY_SETUP="/opt/ros/jazzy/setup.bash"

GZ_VERSION_EXPECTED="harmonic"
GZ_SIM_MAJOR_EXPECTED="8"

PACKAGE_NAME="drone_detector"

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

# ------------------------------------------------------------------------------
# Start
# ------------------------------------------------------------------------------

print_header "Drone Detection POC - Project Setup"

# ------------------------------------------------------------------------------
# 1. Root check
# ------------------------------------------------------------------------------

if [[ "${EUID}" -eq 0 ]]; then
    die "Do not run this script as root.

Run it as your normal user:

    ./project_setup.sh

The script will use sudo only where package installation requires it."
fi

# ------------------------------------------------------------------------------
# 2. Locate project directory
# ------------------------------------------------------------------------------

print_step "Checking Drone Detection POC directory"

if [[ ! -d "$PROJECT_DIR" ]]; then
    die "Drone Detection POC directory was not found:

    $PROJECT_DIR

Clone/copy the POC first, or set DRONE_DETECTION_POC_DIR to the correct path."
fi

print_info "Project directory:"
print_info "    $PROJECT_DIR"

cd "$PROJECT_DIR"

print_success "Drone Detection POC directory found"

# ------------------------------------------------------------------------------
# 3. Operating system detection
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
        EXPECTED_ROS_DISTRO="humble"
        ROS_SETUP="$ROS_HUMBLE_SETUP"
        print_success "Ubuntu 22.04 detected"
        print_info "Expected ROS 2 distribution: Humble"
        ;;
    noble)
        EXPECTED_ROS_DISTRO="jazzy"
        ROS_SETUP="$ROS_JAZZY_SETUP"
        print_success "Ubuntu 24.04 detected"
        print_info "Expected ROS 2 distribution: Jazzy"
        ;;
    *)
        die "Unsupported Ubuntu release: $OS_RELEASE ($OS_CODENAME).

Supported:
    Ubuntu 22.04 (Jammy) + ROS 2 Humble
    Ubuntu 24.04 (Noble) + ROS 2 Jazzy"
        ;;
esac

# ------------------------------------------------------------------------------
# 4. Architecture
# ------------------------------------------------------------------------------

print_step "Checking system architecture"

ARCHITECTURE="$(dpkg --print-architecture)"
print_info "Architecture: $ARCHITECTURE"

case "$ARCHITECTURE" in
    amd64)
        print_success "amd64 architecture detected"
        ;;
    arm64)
        print_warning "arm64 detected. The project may work, but the POC is"
        print_warning "primarily validated on amd64."
        ;;
    *)
        die "Unsupported architecture: $ARCHITECTURE"
        ;;
esac

# ------------------------------------------------------------------------------
# 5. Source ROS
# ------------------------------------------------------------------------------

print_step "Checking ROS 2 installation"

if [[ ! -f "$ROS_SETUP" ]]; then
    die "Expected ROS setup file was not found:

    $ROS_SETUP

Run the appropriate ROS setup script first."
fi

# shellcheck disable=SC1090
source "$ROS_SETUP"

print_info "ROS_DISTRO=${ROS_DISTRO:-<not set>}"
print_info "ROS_VERSION=${ROS_VERSION:-<not set>}"

[[ "${ROS_DISTRO:-}" == "$EXPECTED_ROS_DISTRO" ]] || \
    die "Unexpected ROS distribution.

Expected : $EXPECTED_ROS_DISTRO
Detected : ${ROS_DISTRO:-<not set>}"

command_exists ros2 || \
    die "ros2 command is not available after sourcing $ROS_SETUP"

command_exists colcon || \
    die "colcon command is not available.

Install ROS development tools before running this script."

print_success "ROS 2 $EXPECTED_ROS_DISTRO is available"
print_success "colcon is available"

# ------------------------------------------------------------------------------
# 6. Source project environment
# ------------------------------------------------------------------------------

print_step "Loading Drone Detection POC environment"

ENVIRONMENT_FILE="$PROJECT_DIR/config/environment.sh"

if [[ -f "$ENVIRONMENT_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENVIRONMENT_FILE"
    print_success "Loaded config/environment.sh"
else
    die "Project environment file was not found:

    $ENVIRONMENT_FILE"
fi

# Preserve explicit script configuration if environment.sh contains defaults.
export DRONE_DETECTION_POC_DIR="$PROJECT_DIR"
export ARDUPILOT_DIR="$ARDUPILOT_DIR"
export ARDUPILOT_GAZEBO_DIR="$ARDUPILOT_GAZEBO_DIR"
export GZ_VERSION="$GZ_VERSION_EXPECTED"

print_info "DRONE_DETECTION_POC_DIR=$DRONE_DETECTION_POC_DIR"
print_info "ARDUPILOT_DIR=$ARDUPILOT_DIR"
print_info "ARDUPILOT_GAZEBO_DIR=$ARDUPILOT_GAZEBO_DIR"
print_info "GZ_VERSION=$GZ_VERSION"

# ------------------------------------------------------------------------------
# 7. Validate external ArduPilot dependency
# ------------------------------------------------------------------------------

print_step "Validating ArduPilot dependency"

if [[ ! -d "$ARDUPILOT_DIR/.git" ]]; then
    die "ArduPilot Git repository was not found:

    $ARDUPILOT_DIR

Run ardupilot_setup.sh first."
fi

if [[ ! -f "$ARDUPILOT_DIR/Tools/autotest/sim_vehicle.py" ]]; then
    die "ArduPilot sim_vehicle.py was not found."
fi

print_success "ArduPilot repository found"

ARDUPILOT_COMMIT="$(git -C "$ARDUPILOT_DIR" rev-parse HEAD)"
ARDUPILOT_VERSION="$(git -C "$ARDUPILOT_DIR" describe --tags --always --dirty 2>/dev/null || true)"

print_info "ArduPilot commit : $ARDUPILOT_COMMIT"
print_info "ArduPilot version: ${ARDUPILOT_VERSION:-<unknown>}"

# ------------------------------------------------------------------------------
# 8. Validate Gazebo
# ------------------------------------------------------------------------------

print_step "Validating Gazebo Harmonic"

command_exists gz || \
    die "Gazebo 'gz' command was not found.

Run gazebo_harmonic_setup.sh first."

if ! gz sim --help >/dev/null 2>&1; then
    die "Gazebo Sim is not responding correctly."
fi

print_success "Gazebo Sim is available"

export GZ_VERSION="$GZ_VERSION_EXPECTED"

print_info "GZ_VERSION=$GZ_VERSION"

# Check the Gazebo Sim 8 development package when dpkg is available.
if dpkg-query -W -f='${Status}' libgz-sim8-dev 2>/dev/null \
    | grep -q "install ok installed"; then
    print_success "libgz-sim8-dev is installed"
else
    print_warning "libgz-sim8-dev was not detected."
    print_warning "ArduPilot-Gazebo may not have been installed correctly."
fi

# ------------------------------------------------------------------------------
# 9. Validate ArduPilot-Gazebo
# ------------------------------------------------------------------------------

print_step "Validating ArduPilot-Gazebo dependency"

if [[ ! -d "$ARDUPILOT_GAZEBO_DIR/.git" ]]; then
    die "ArduPilot-Gazebo repository was not found:

    $ARDUPILOT_GAZEBO_DIR

Run ardupilot_gazebo_setup.sh first."
fi

ARDUPILOT_GAZEBO_BUILD_DIR="$ARDUPILOT_GAZEBO_DIR/build"
ARDUPILOT_PLUGIN="$ARDUPILOT_GAZEBO_BUILD_DIR/libArduPilotPlugin.so"

if [[ ! -f "$ARDUPILOT_PLUGIN" ]]; then
    die "ArduPilotPlugin was not found:

    $ARDUPILOT_PLUGIN

Run ardupilot_gazebo_setup.sh first."
fi

print_success "ArduPilot-Gazebo repository found"
print_success "libArduPilotPlugin.so found"

ARDUPILOT_GAZEBO_COMMIT="$(git -C "$ARDUPILOT_GAZEBO_DIR" rev-parse HEAD)"
ARDUPILOT_GAZEBO_VERSION="$(git -C "$ARDUPILOT_GAZEBO_DIR" describe --tags --always --dirty 2>/dev/null || true)"

print_info "ArduPilot-Gazebo commit : $ARDUPILOT_GAZEBO_COMMIT"
print_info "ArduPilot-Gazebo version: ${ARDUPILOT_GAZEBO_VERSION:-<unknown>}"

# ------------------------------------------------------------------------------
# 10. Validate project structure
# ------------------------------------------------------------------------------

print_step "Checking Drone Detection POC structure"

REQUIRED_DIRECTORIES=(
    "config"
    "data"
    "data/bags"
    "docs"
    "launch"
    "scripts"
    "scripts/simulation"
    "scripts/trajectory"
    "simulation"
    "simulation/gazebo"
    "simulation/gazebo/models"
    "simulation/gazebo/worlds"
    "src"
    "src/drone_detector"
    "src/drone_detector/src"
    "tests"
)

for DIRECTORY in "${REQUIRED_DIRECTORIES[@]}"; do
    if [[ -d "$PROJECT_DIR/$DIRECTORY" ]]; then
        print_success "$DIRECTORY/"
    else
        print_warning "Missing directory: $DIRECTORY/"
        mkdir -p "$PROJECT_DIR/$DIRECTORY"
        print_info "Created: $DIRECTORY/"
    fi
done

# ------------------------------------------------------------------------------
# 11. Validate ROS package files
# ------------------------------------------------------------------------------

print_step "Checking drone_detector ROS package"

PACKAGE_DIR="$PROJECT_DIR/src/drone_detector"
PACKAGE_XML="$PACKAGE_DIR/package.xml"
CMAKE_FILE="$PACKAGE_DIR/CMakeLists.txt"

[[ -f "$PACKAGE_XML" ]] || \
    die "ROS package manifest not found:

    $PACKAGE_XML"

[[ -f "$CMAKE_FILE" ]] || \
    die "ROS package CMakeLists.txt not found:

    $CMAKE_FILE"

if grep -q "<name>$PACKAGE_NAME</name>" "$PACKAGE_XML"; then
    print_success "package.xml name is $PACKAGE_NAME"
else
    die "package.xml does not declare package name '$PACKAGE_NAME'."
fi

if grep -q "project($PACKAGE_NAME)" "$CMAKE_FILE"; then
    print_success "CMakeLists.txt declares project $PACKAGE_NAME"
else
    print_warning "Could not find the expected project($PACKAGE_NAME) declaration."
    print_warning "Please inspect CMakeLists.txt if the package build fails."
fi

# ------------------------------------------------------------------------------
# 12. Validate source files
# ------------------------------------------------------------------------------

print_step "Checking project source files"

SOURCE_FILES=(
    "src/drone_detector/src/drone_detector_node.cpp"
    "src/drone_detector/src/learning.cpp"
)

for SOURCE_FILE in "${SOURCE_FILES[@]}"; do
    if [[ -f "$PROJECT_DIR/$SOURCE_FILE" ]]; then
        print_success "$SOURCE_FILE"
    else
        print_warning "Source file not found: $SOURCE_FILE"
    fi
done

# ------------------------------------------------------------------------------
# 13. Validate Gazebo project resources
# ------------------------------------------------------------------------------

print_step "Checking project Gazebo resources"

WORLD_FILES=(
    "simulation/gazebo/worlds/iris_runway.sdf"
    "simulation/gazebo/worlds/two_drone.sdf"
)

for WORLD_FILE in "${WORLD_FILES[@]}"; do
    if [[ -f "$PROJECT_DIR/$WORLD_FILE" ]]; then
        print_success "$WORLD_FILE"
    else
        print_warning "World file not found: $WORLD_FILE"
    fi
done

MODEL_DIRECTORIES=(
    "fixed_lidar"
    "gimbal_small_3d"
    "iris_with_gimbal"
    "iris_with_gimbal_2"
    "iris_with_lidar"
    "iris_with_standoffs"
    "runway"
)

for MODEL in "${MODEL_DIRECTORIES[@]}"; do
    MODEL_DIR="$PROJECT_DIR/simulation/gazebo/models/$MODEL"

    if [[ -d "$MODEL_DIR" ]]; then
        print_success "Gazebo model: $MODEL"
    else
        print_warning "Gazebo model directory missing: $MODEL"
    fi
done

# ------------------------------------------------------------------------------
# 14. Validate project configuration
# ------------------------------------------------------------------------------

print_step "Checking project configuration"

if [[ -f "$PROJECT_DIR/config/environment.sh" ]]; then
    print_success "config/environment.sh"
else
    die "config/environment.sh is missing."
fi

if [[ -f "$PROJECT_DIR/config/versions.sh" ]]; then
    print_success "config/versions.sh"
else
    print_warning "config/versions.sh is not present."
    print_warning "This is optional for the current project setup."
fi

# ------------------------------------------------------------------------------
# 15. Install rosdep dependencies for the POC
# ------------------------------------------------------------------------------

print_step "Resolving ROS dependencies"

if command_exists rosdep; then
    print_success "rosdep is available"

    print_info "Updating rosdep database"
    rosdep update

    print_info "Installing dependencies from the POC source tree"
    cd "$PROJECT_DIR"

    rosdep install \
        --from-paths src \
        --ignore-src \
        -r \
        -y

    print_success "ROS dependencies resolved"
else
    die "rosdep is not available.

Install/configure rosdep using the ROS setup script first."
fi

# ------------------------------------------------------------------------------
# 16. Ensure project scripts are executable
# ------------------------------------------------------------------------------

print_step "Checking project scripts"

SCRIPT_FILES=(
    "scripts/simulation/bridge_gazebo_clock.sh"
    "scripts/simulation/bridge_lidar_pointcloud.sh"
    "scripts/simulation/start_drone1.sh"
    "scripts/simulation/start_drone2.sh"
    "scripts/simulation/start_gazebo.sh"
    "scripts/simulation/start_rviz.sh"
    "scripts/simulation/start_two_drone_gazebo.sh"
    "scripts/trajectory/trajectory.py"
    "scripts/trajectory/trajectory_multidrones.py"
    "scripts/trajectory/trajectory_multidrones_circle.py"
)

for SCRIPT_FILE in "${SCRIPT_FILES[@]}"; do
    FULL_PATH="$PROJECT_DIR/$SCRIPT_FILE"

    if [[ -f "$FULL_PATH" ]]; then
        chmod +x "$FULL_PATH"
        print_success "$SCRIPT_FILE"
    else
        print_warning "Script not found: $SCRIPT_FILE"
    fi
done

# ------------------------------------------------------------------------------
# 17. Validate environment paths
# ------------------------------------------------------------------------------

print_step "Validating Gazebo environment paths"

EXPECTED_PLUGIN_PATH="$ARDUPILOT_GAZEBO_DIR/build"
EXPECTED_PROJECT_MODELS="$PROJECT_DIR/simulation/gazebo/models"
EXPECTED_PROJECT_WORLDS="$PROJECT_DIR/simulation/gazebo/worlds"
EXPECTED_UPSTREAM_WORLDS="$ARDUPILOT_GAZEBO_DIR/worlds"

print_info "GZ_SIM_SYSTEM_PLUGIN_PATH:"
print_info "    ${GZ_SIM_SYSTEM_PLUGIN_PATH:-<not set>}"

print_info "GZ_SIM_RESOURCE_PATH:"
print_info "    ${GZ_SIM_RESOURCE_PATH:-<not set>}"

if [[ "${GZ_SIM_SYSTEM_PLUGIN_PATH:-}" == *"$EXPECTED_PLUGIN_PATH"* ]]; then
    print_success "ArduPilot-Gazebo plugin path is configured"
else
    print_warning "ArduPilot-Gazebo build directory is not currently present in"
    print_warning "GZ_SIM_SYSTEM_PLUGIN_PATH."
    print_warning "config/environment.sh should provide this path when sourced."
fi

for RESOURCE_PATH in \
    "$EXPECTED_PROJECT_MODELS" \
    "$EXPECTED_PROJECT_WORLDS"; do

    if [[ "${GZ_SIM_RESOURCE_PATH:-}" == *"$RESOURCE_PATH"* ]]; then
        print_success "Gazebo resource path configured: $RESOURCE_PATH"
    else
        print_warning "Gazebo resource path not detected: $RESOURCE_PATH"
    fi
done

if [[ -d "$EXPECTED_UPSTREAM_WORLDS" ]]; then
    print_success "ArduPilot-Gazebo worlds directory exists"
fi

# ------------------------------------------------------------------------------
# 18. Build project with colcon
# ------------------------------------------------------------------------------

print_step "Building Drone Detection POC"

cd "$PROJECT_DIR"

print_info "Project:"
print_info "    $PROJECT_DIR"

print_info "Build command:"
print_info "    colcon build --symlink-install"

echo

colcon build --symlink-install

print_success "Drone Detection POC build completed"

# ------------------------------------------------------------------------------
# 19. Source project workspace
# ------------------------------------------------------------------------------

print_step "Sourcing project workspace"

PROJECT_SETUP="$PROJECT_DIR/install/setup.bash"

if [[ ! -f "$PROJECT_SETUP" ]]; then
    die "Project workspace setup file was not generated:

    $PROJECT_SETUP"
fi

# shellcheck disable=SC1090
source "$PROJECT_SETUP"

print_success "Project workspace sourced"

# ------------------------------------------------------------------------------
# 20. Verify ROS package
# ------------------------------------------------------------------------------

print_step "Verifying drone_detector ROS package"

if ros2 pkg prefix "$PACKAGE_NAME" >/dev/null 2>&1; then
    PACKAGE_PREFIX="$(ros2 pkg prefix "$PACKAGE_NAME")"

    print_success "$PACKAGE_NAME is registered with ROS 2"
    print_info "Package prefix:"
    print_info "    $PACKAGE_PREFIX"
else
    die "ROS package '$PACKAGE_NAME' was not found after the build."
fi

# ------------------------------------------------------------------------------
# 21. Verify project executables
# ------------------------------------------------------------------------------

print_step "Checking generated ROS executables"

# Do not assume a particular executable name beyond what the package's
# CMakeLists.txt actually installs. Search the package prefix for executables.
if [[ -d "$PACKAGE_PREFIX/lib/$PACKAGE_NAME" ]]; then
    mapfile -t EXECUTABLES < <(
        find "$PACKAGE_PREFIX/lib/$PACKAGE_NAME" \
            -maxdepth 1 \
            -type f \
            -executable \
            -printf '%f\n' \
            | sort
    )

    if [[ "${#EXECUTABLES[@]}" -gt 0 ]]; then
        for EXECUTABLE in "${EXECUTABLES[@]}"; do
            print_success "ROS executable: $EXECUTABLE"
        done
    else
        print_warning "No executable files were found under:"
        print_warning "    $PACKAGE_PREFIX/lib/$PACKAGE_NAME"
    fi
else
    print_warning "No package-specific executable directory found."
    print_warning "This may be normal if the current package is library-only."
fi

# ------------------------------------------------------------------------------
# 22. Verify data/bags is empty
# ------------------------------------------------------------------------------

print_step "Checking data/bags directory"

BAG_DIR="$PROJECT_DIR/data/bags"

mkdir -p "$BAG_DIR"

if find "$BAG_DIR" -mindepth 1 -print -quit | grep -q .; then
    print_warning "data/bags is not empty."
    print_warning "The project setup does not delete existing bag files."
else
    print_success "data/bags exists and is intentionally empty"
fi

# ------------------------------------------------------------------------------
# 23. Optional project version information
# ------------------------------------------------------------------------------

print_step "Checking project Git state"

if [[ -d "$PROJECT_DIR/.git" ]]; then
    PROJECT_COMMIT="$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || true)"
    PROJECT_BRANCH="$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || true)"

    print_info "Project branch: ${PROJECT_BRANCH:-<detached HEAD>}"
    print_info "Project commit: ${PROJECT_COMMIT:-<unknown>}"

    if [[ -n "$(git -C "$PROJECT_DIR" status --short)" ]]; then
        print_warning "Project working tree contains uncommitted changes."
    else
        print_success "Project working tree is clean"
    fi
else
    print_warning "Project directory is not a Git repository yet."
    print_warning "This is allowed; Git can be initialized later."
fi

# ------------------------------------------------------------------------------
# 24. Final dependency summary
# ------------------------------------------------------------------------------

print_step "Final dependency summary"

echo
echo "ROS:"
echo "    Distribution : $ROS_DISTRO"
echo "    Setup        : $ROS_SETUP"
echo
echo "Gazebo:"
echo "    Version      : Harmonic"
echo "    GZ_VERSION   : $GZ_VERSION"
echo
echo "ArduPilot:"
echo "    Location     : $ARDUPILOT_DIR"
echo "    Commit       : $ARDUPILOT_COMMIT"
echo "    Version      : ${ARDUPILOT_VERSION:-<unknown>}"
echo
echo "ArduPilot-Gazebo:"
echo "    Location     : $ARDUPILOT_GAZEBO_DIR"
echo "    Build        : $ARDUPILOT_GAZEBO_BUILD_DIR"
echo "    Plugin       : $ARDUPILOT_PLUGIN"
echo "    Commit       : $ARDUPILOT_GAZEBO_COMMIT"
echo "    Version      : ${ARDUPILOT_GAZEBO_VERSION:-<unknown>}"
echo
echo "Drone Detection POC:"
echo "    Location     : $PROJECT_DIR"
echo "    ROS package  : $PACKAGE_NAME"
echo "    Install      : $PROJECT_DIR/install"
echo

# ------------------------------------------------------------------------------
# 25. Final summary
# ------------------------------------------------------------------------------

print_header "Drone Detection POC Project Setup Complete"

echo "The Drone Detection POC has been configured and built successfully."
echo
echo "Project:"
echo "    $PROJECT_DIR"
echo
echo "ROS package:"
echo "    $PACKAGE_NAME"
echo
echo "Workspace:"
echo "    $PROJECT_DIR/install"
echo
echo "External dependencies:"
echo "    ArduPilot       -> $ARDUPILOT_DIR"
echo "    ArduPilot-Gazebo -> $ARDUPILOT_GAZEBO_DIR"
echo "    Gazebo           -> Harmonic / Gazebo Sim 8"
echo "    ROS              -> $ROS_DISTRO"
echo
echo "For a new terminal, source:"
echo "    source $ROS_SETUP"
echo "    source $PROJECT_DIR/config/environment.sh"
echo "    source $PROJECT_DIR/install/setup.bash"
echo
echo "The project setup does not modify ~/.bashrc or ~/.profile."
echo
echo "The next step is to run the POC simulation validation:"
echo "    Gazebo"
echo "    ArduPilot SITL"
echo "    ArduPilot-Gazebo plugin"
echo "    Gazebo clock bridge"
echo "    LiDAR PointCloud2 bridge"
echo "    RViz"
echo "    Drone detector node"
echo
echo "No setup log files were created."
echo
