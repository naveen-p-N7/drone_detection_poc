#!/usr/bin/env bash

# ==============================================================================
# Drone Detection POC
# ROS 2 Jazzy Setup - Ubuntu 24.04
# ==============================================================================
#
# Purpose:
#   Install and configure ROS 2 Jazzy on Ubuntu 24.04.
#
# This script installs:
#   - ROS 2 Jazzy Desktop
#   - ROS development tools
#   - rosdep
#   - ROS-Gazebo integration packages required by the POC
#
# This script does NOT install:
#   - Gazebo Harmonic
#   - ArduPilot
#   - ArduPilot-Gazebo
#   - Drone Detection POC
#
# Prerequisite:
#   Run prereq.sh before this script.
#
# Usage:
#   ./ros2_jazzy_setup.sh
#
# ==============================================================================

set -euo pipefail

EXPECTED_ROS_DISTRO="jazzy"
EXPECTED_OS_CODENAME="noble"
ROS_SETUP="/opt/ros/${EXPECTED_ROS_DISTRO}/setup.bash"

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

print_header "Drone Detection POC - ROS 2 Jazzy Setup"

if [[ "${EUID}" -eq 0 ]]; then
    die "Do not run this script as root.

Run it as your normal user:

    ./ros2_jazzy_setup.sh

The script will use sudo when required."
fi

print_step "Checking operating system"

command_exists lsb_release || die "lsb_release is not installed. Run prereq.sh first."

OS_ID="$(lsb_release -is)"
OS_RELEASE="$(lsb_release -rs)"
OS_CODENAME="$(lsb_release -cs)"

print_info "Distribution : $OS_ID"
print_info "Release      : $OS_RELEASE"
print_info "Codename     : $OS_CODENAME"

[[ "$OS_ID" == "Ubuntu" ]] || die "This script supports Ubuntu only. Detected: $OS_ID"
[[ "$OS_CODENAME" == "$EXPECTED_OS_CODENAME" ]] || die "This script is specifically for Ubuntu 24.04 (noble). Detected: Ubuntu $OS_RELEASE ($OS_CODENAME)"

print_success "Ubuntu 24.04 (noble) detected"

print_step "Checking system architecture"

ARCHITECTURE="$(dpkg --print-architecture)"
print_info "Architecture: $ARCHITECTURE"

case "$ARCHITECTURE" in
    amd64|arm64) print_success "Architecture $ARCHITECTURE is supported" ;;
    *) die "Unsupported architecture: $ARCHITECTURE" ;;
esac

print_step "Checking locale"

CURRENT_LANG="${LANG:-}"
print_info "LANG=${CURRENT_LANG:-<not set>}"

if [[ "$CURRENT_LANG" != "en_US.UTF-8" ]]; then
    print_info "Configuring en_US.UTF-8 locale"
    sudo locale-gen en_US en_US.UTF-8
    sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    print_success "Locale configured"
else
    print_success "Locale already configured"
fi

print_step "Checking Ubuntu Universe repository"

if apt-cache policy | grep -q "Components:.*universe"; then
    print_success "Universe repository is available"
else
    print_info "Enabling Universe repository"
    sudo add-apt-repository -y universe
    sudo apt-get update
    print_success "Universe repository enabled"
fi

print_step "Configuring ROS 2 package repository"

if dpkg-query -W -f='${Status}' ros2-apt-source 2>/dev/null | grep -q "install ok installed"; then
    print_success "ros2-apt-source is already installed"
else
    print_info "Installing ros2-apt-source"
    sudo apt-get update
    sudo apt-get install -y curl ca-certificates gnupg
    sudo apt-get install -y ros2-apt-source
    print_success "ROS 2 package repository configured"
fi

print_step "Updating APT package information"
sudo apt-get update
print_success "APT package information updated"

print_step "Installing ROS 2 Jazzy Desktop"
sudo apt-get install -y "ros-${EXPECTED_ROS_DISTRO}-desktop"
print_success "ROS 2 Jazzy Desktop installed"

print_step "Installing ROS development tools"
sudo apt-get install -y ros-dev-tools
print_success "ROS development tools installed"

print_step "Installing rosdep"

if command_exists rosdep; then
    print_success "rosdep is already installed"
else
    sudo apt-get install -y python3-rosdep
    print_success "rosdep installed"
fi

print_step "Configuring rosdep"

if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
    print_info "Initializing rosdep"
    sudo rosdep init
    print_success "rosdep initialized"
else
    print_success "rosdep is already initialized"
fi

print_info "Updating rosdep database"
rosdep update
print_success "rosdep database updated"

print_step "Installing ROS-Gazebo integration packages"

sudo apt-get install -y     "ros-${EXPECTED_ROS_DISTRO}-ros-gz"     "ros-${EXPECTED_ROS_DISTRO}-ros-gz-sim"     "ros-${EXPECTED_ROS_DISTRO}-ros-gz-bridge"

print_success "ROS-Gazebo integration packages installed"

print_step "Verifying ROS 2 installation"

[[ -f "$ROS_SETUP" ]] || die "ROS 2 setup file was not found: $ROS_SETUP"
print_success "ROS setup file exists"

# shellcheck disable=SC1090
source "$ROS_SETUP"

print_info "ROS_DISTRO=$ROS_DISTRO"

[[ "$ROS_DISTRO" == "$EXPECTED_ROS_DISTRO" ]] || die "Unexpected ROS distribution. Expected: $EXPECTED_ROS_DISTRO; Detected: $ROS_DISTRO"

print_step "Checking ROS 2 commands"

command_exists ros2 || die "ros2 command is not available after sourcing ROS."

print_info "ROS 2 command: $(command -v ros2)"
print_success "ros2 command is available"

print_step "Checking required ROS packages"

REQUIRED_PACKAGES=(
    "ros_gz_bridge"
    "ros_gz_sim"
)

for PACKAGE in "${REQUIRED_PACKAGES[@]}"; do
    if ros2 pkg prefix "$PACKAGE" >/dev/null 2>&1; then
        print_success "$PACKAGE"
        print_info "  Path: $(ros2 pkg prefix "$PACKAGE")"
    else
        die "Required ROS package is missing: $PACKAGE"
    fi
done

print_step "Checking colcon"

command_exists colcon || die "colcon is not available. ros-dev-tools installation may have failed."
print_info "colcon: $(command -v colcon)"
print_success "colcon is available"

print_step "ROS environment"

print_info "ROS_DISTRO         = ${ROS_DISTRO:-<not set>}"
print_info "ROS_VERSION        = ${ROS_VERSION:-<not set>}"
print_info "ROS_PYTHON_VERSION = ${ROS_PYTHON_VERSION:-<not set>}"

print_header "ROS 2 Jazzy Setup Complete"

echo "ROS 2 Jazzy has been installed successfully."
echo
echo "Installed:"
echo "    ROS 2 Jazzy Desktop"
echo "    ROS development tools"
echo "    rosdep"
echo "    ros_gz"
echo "    ros_gz_sim"
echo "    ros_gz_bridge"
echo
echo "ROS setup:"
echo "    $ROS_SETUP"
echo
echo "For the current terminal:"
echo "    source $ROS_SETUP"
echo
echo "The next setup stage will install:"
echo "    Gazebo Harmonic"
echo
echo "No setup log files were created."
echo
