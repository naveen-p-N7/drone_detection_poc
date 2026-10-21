#!/usr/bin/env bash

# ==============================================================================
# Drone Detection POC
# Gazebo Harmonic Setup - Ubuntu 22.04 / 24.04
# ==============================================================================
#
# Purpose:
#   Install Gazebo Harmonic (Gazebo Sim 8) using the official OSRF binary
#   repository.
#
# This script installs:
#   - Gazebo Harmonic metapackage (gz-harmonic)
#   - Gazebo Sim 8 and its Harmonic library dependencies
#   - Development package required by ArduPilot-Gazebo:
#       libgz-sim8-dev
#   - Supporting build/runtime dependencies used by ArduPilot-Gazebo:
#       rapidjson-dev
#       libopencv-dev
#       GStreamer development/plugins packages
#
# Supported operating systems:
#   - Ubuntu 22.04 (Jammy)
#   - Ubuntu 24.04 (Noble)
#
# This script does NOT install:
#   - ROS 2
#   - ArduPilot
#   - ArduPilot-Gazebo
#   - Drone Detection POC source code
#
# Prerequisites:
#   - Run the appropriate OS prerequisite script first.
#   - Internet access.
#   - sudo access.
#
# Usage:
#   chmod +x gazebo_harmonic_setup.sh
#   ./gazebo_harmonic_setup.sh
#
# ==============================================================================

set -euo pipefail

EXPECTED_GZ_VERSION="harmonic"
EXPECTED_GZ_MAJOR="8"
OSRF_KEYRING="/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg"
OSRF_LIST="/etc/apt/sources.list.d/gazebo-stable.list"

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

print_header "Drone Detection POC - Gazebo Harmonic Setup"

# ------------------------------------------------------------------------------
# 1. Root check
# ------------------------------------------------------------------------------
if [[ "${EUID}" -eq 0 ]]; then
    die "Do not run this script as root.

Run it as your normal user:

    ./gazebo_harmonic_setup.sh

The script will use sudo when required."
fi

# ------------------------------------------------------------------------------
# 2. Operating system check
# ------------------------------------------------------------------------------
print_step "Checking operating system"

command_exists lsb_release || die "lsb_release is not installed."

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

Gazebo Harmonic setup is supported by this POC on:
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
        print_warning "arm64 is best-effort for Gazebo Harmonic."
        print_warning "The primary supported architecture for this POC is amd64."
        ;;
    *)
        die "Unsupported architecture: $ARCHITECTURE"
        ;;
esac

# ------------------------------------------------------------------------------
# 4. Basic tool checks
# ------------------------------------------------------------------------------
print_step "Checking required setup tools"

for TOOL in curl gpg lsb_release dpkg; do
    if command_exists "$TOOL"; then
        print_success "$TOOL"
    else
        print_warning "$TOOL is missing"
    fi
done

print_info "Installing missing base tools if required"

sudo apt-get update
sudo apt-get install -y \
    curl \
    ca-certificates \
    gnupg \
    lsb-release

print_success "Base setup tools are available"

# ------------------------------------------------------------------------------
# 5. Configure OSRF Gazebo repository
# ------------------------------------------------------------------------------
print_step "Configuring the official OSRF Gazebo repository"

print_info "Repository:"
print_info "https://packages.osrfoundation.org/gazebo/ubuntu-stable"

if [[ -f "$OSRF_KEYRING" ]]; then
    print_success "OSRF Gazebo keyring already exists"
else
    print_info "Installing OSRF Gazebo repository keyring"

    sudo curl -fsSL \
        "https://packages.osrfoundation.org/gazebo.gpg" \
        -o "$OSRF_KEYRING"

    sudo chmod 0644 "$OSRF_KEYRING"

    print_success "OSRF Gazebo keyring installed"
fi

EXPECTED_REPOSITORY_LINE="deb [arch=$(dpkg --print-architecture) signed-by=${OSRF_KEYRING}] https://packages.osrfoundation.org/gazebo/ubuntu-stable ${OS_CODENAME} main"

if [[ -f "$OSRF_LIST" ]] && grep -Fqx "$EXPECTED_REPOSITORY_LINE" "$OSRF_LIST"; then
    print_success "OSRF Gazebo repository is already configured correctly"
else
    print_info "Writing OSRF Gazebo repository configuration"

    echo "$EXPECTED_REPOSITORY_LINE" \
        | sudo tee "$OSRF_LIST" >/dev/null

    print_success "OSRF Gazebo repository configured"
fi

# ------------------------------------------------------------------------------
# 6. Update package metadata
# ------------------------------------------------------------------------------
print_step "Updating APT package information"

sudo apt-get update

print_success "APT package information updated"

# ------------------------------------------------------------------------------
# 7. Install Gazebo Harmonic
# ------------------------------------------------------------------------------
print_step "Installing Gazebo Harmonic"

if package_installed "gz-harmonic"; then
    print_success "gz-harmonic is already installed"
else
    print_info "Installing the official Gazebo Harmonic metapackage"
    sudo apt-get install -y gz-harmonic
    print_success "Gazebo Harmonic installed"
fi

# ------------------------------------------------------------------------------
# 8. Install ArduPilot-Gazebo development dependencies
# ------------------------------------------------------------------------------
print_step "Installing ArduPilot-Gazebo build dependencies"

print_info "Installing Gazebo Sim 8 development package"

sudo apt-get install -y \
    libgz-sim8-dev \
    rapidjson-dev

print_success "Gazebo/JSON development dependencies installed"

print_info "Installing OpenCV dependencies"

sudo apt-get install -y \
    libopencv-dev

print_success "OpenCV development package installed"

print_info "Installing GStreamer dependencies"

sudo apt-get install -y \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-libav \
    gstreamer1.0-gl

print_success "GStreamer dependencies installed"

# ------------------------------------------------------------------------------
# 9. Set GZ_VERSION for the current script
# ------------------------------------------------------------------------------
print_step "Configuring Gazebo version"

export GZ_VERSION="$EXPECTED_GZ_VERSION"

print_info "GZ_VERSION=$GZ_VERSION"

print_success "Gazebo version configured for this setup"

# ------------------------------------------------------------------------------
# 10. Verify Gazebo executable
# ------------------------------------------------------------------------------
print_step "Verifying Gazebo executable"

command_exists gz || die "The 'gz' command is not available after installation."

print_info "gz command: $(command -v gz)"

print_success "Gazebo command is available"

# ------------------------------------------------------------------------------
# 11. Verify Gazebo Sim
# ------------------------------------------------------------------------------
print_step "Checking Gazebo Sim"

if ! gz sim --help >/dev/null 2>&1; then
    die "Gazebo Sim could not be executed."
fi

print_success "gz sim command is available"

# Try to report the installed Gazebo Sim version.
# Different package revisions can format this output differently, so this is
# informational rather than a strict version-string comparison.
if gz sim --version >/dev/null 2>&1; then
    print_info "Gazebo Sim version:"
    gz sim --version || true
else
    print_info "Gazebo Sim version information is not exposed by this command."
fi

# ------------------------------------------------------------------------------
# 12. Verify Gazebo Sim 8 development package
# ------------------------------------------------------------------------------
print_step "Checking Gazebo Sim 8 development package"

if package_installed "libgz-sim8-dev"; then
    print_success "libgz-sim8-dev is installed"
else
    die "libgz-sim8-dev is not installed."
fi

# ------------------------------------------------------------------------------
# 13. Verify key Harmonic libraries
# ------------------------------------------------------------------------------
print_step "Checking key Gazebo Harmonic libraries"

REQUIRED_GZ_PACKAGES=(
    "gz-sim8"
    "gz-common5"
    "gz-rendering8"
    "gz-transport13"
    "gz-msgs10"
    "gz-math7"
    "gz-plugin2"
    "gz-tools2"
)

for PACKAGE in "${REQUIRED_GZ_PACKAGES[@]}"; do
    if package_installed "$PACKAGE"; then
        print_success "$PACKAGE"
    else
        print_warning "$PACKAGE is not installed as a direct dpkg package."
        print_warning "It may still be provided through another installed package."
    fi
done

# ------------------------------------------------------------------------------
# 14. Verify Gazebo executable through a minimal non-GUI command
# ------------------------------------------------------------------------------
print_step "Running a minimal Gazebo validation"

if gz sim --help >/dev/null 2>&1; then
    print_success "Gazebo Sim responds correctly"
else
    die "Gazebo Sim validation failed."
fi

# ------------------------------------------------------------------------------
# 15. Check for legacy Gazebo Classic
# ------------------------------------------------------------------------------
print_step "Checking for Gazebo Classic"

if command_exists gazebo; then
    print_warning "The legacy 'gazebo' command is present."
    print_warning "Gazebo Classic and Gazebo Harmonic are different products."
    print_warning "The Drone Detection POC uses Gazebo Harmonic via 'gz sim'."
else
    print_success "No legacy Gazebo Classic executable detected"
fi

# ------------------------------------------------------------------------------
# 16. Final environment information
# ------------------------------------------------------------------------------
print_step "Gazebo environment information"

print_info "GZ_VERSION=$GZ_VERSION"
print_info "Gazebo command=$(command -v gz)"

if [[ -f "$OSRF_LIST" ]]; then
    print_info "OSRF repository=$OSRF_LIST"
fi

# ------------------------------------------------------------------------------
# 17. Final summary
# ------------------------------------------------------------------------------
print_header "Gazebo Harmonic Setup Complete"

echo "Gazebo Harmonic has been installed successfully."
echo
echo "Installed:"
echo "    Gazebo Harmonic"
echo "    Gazebo Sim 8"
echo "    libgz-sim8-dev"
echo "    rapidjson-dev"
echo "    libopencv-dev"
echo "    GStreamer development/plugins"
echo
echo "Gazebo command:"
echo "    gz sim"
echo
echo "Gazebo version:"
echo "    Harmonic"
echo
echo "Gazebo environment:"
echo "    GZ_VERSION=harmonic"
echo
echo "OSRF repository:"
echo "    $OSRF_LIST"
echo
echo "Next setup stage:"
echo "    ArduPilot"
echo "    ArduPilot-Gazebo"
echo
echo "No setup log files were created."
echo
