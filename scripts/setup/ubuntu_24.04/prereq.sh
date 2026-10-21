#!/usr/bin/env bash

# ==============================================================================
# Drone Detection POC
# Ubuntu 24.04 Prerequisites
# ==============================================================================
#
# Purpose:
#   Install the common system-level tools and libraries required by the
#   Drone Detection POC setup.
#
# This script intentionally does NOT install:
#   - ROS 2 Jazzy
#   - Gazebo Harmonic
#   - ArduPilot
#   - ArduPilot-Gazebo
#   - Drone Detection POC dependencies
#
# Those components have their own setup scripts.
#
# Usage:
#   ./prereq.sh
#
# Requirements:
#   - Ubuntu 24.04 (Noble)
#   - Internet connection
#   - A user account with sudo privileges
#
# ==============================================================================

set -euo pipefail


# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_NAME="$(basename "$0")"
EXPECTED_OS="Ubuntu"
EXPECTED_CODENAME="noble"


# ==============================================================================
# Helper functions
# ==============================================================================

print_header()
{
    echo
    echo "======================================================================"
    echo "$1"
    echo "======================================================================"
}


print_step()
{
    echo
    echo "----------------------------------------------------------------------"
    echo "[STEP] $1"
    echo "----------------------------------------------------------------------"
}


print_info()
{
    echo "[INFO] $1"
}


print_success()
{
    echo "[OK]   $1"
}


print_warning()
{
    echo "[WARN] $1"
}


die()
{
    echo
    echo "[ERROR] $1"
    echo
    exit 1
}


command_exists()
{
    command -v "$1" >/dev/null 2>&1
}


# ==============================================================================
# Initial checks
# ==============================================================================

print_header "Drone Detection POC - Ubuntu 24.04 Prerequisites"

print_info "Running: $SCRIPT_NAME"


# ------------------------------------------------------------------------------
# Check that the script is not being executed as root
# ------------------------------------------------------------------------------

if [[ "${EUID}" -eq 0 ]]; then
    die "Do not run this script as root.
Run it as your normal user:

    ./prereq.sh

The script will use sudo when required."
fi


# ------------------------------------------------------------------------------
# Check operating system
# ------------------------------------------------------------------------------

print_step "Checking operating system"

if ! command_exists lsb_release; then
    die "lsb_release is not available.

Install it with:

    sudo apt update
    sudo apt install -y lsb-release"
fi

OS_ID="$(lsb_release -is)"
OS_RELEASE="$(lsb_release -rs)"
OS_CODENAME="$(lsb_release -cs)"

print_info "Distribution : $OS_ID"
print_info "Release      : $OS_RELEASE"
print_info "Codename     : $OS_CODENAME"


if [[ "$OS_ID" != "$EXPECTED_OS" ]]; then
    die "Unsupported operating system.

Expected:
    $EXPECTED_OS

Detected:
    $OS_ID"
fi


if [[ "$OS_CODENAME" != "$EXPECTED_CODENAME" ]]; then
    die "Unsupported Ubuntu release.

Expected:
    Ubuntu 24.04 (noble)

Detected:
    Ubuntu $OS_RELEASE ($OS_CODENAME)"
fi

print_success "Ubuntu 24.04 (noble) detected"


# ------------------------------------------------------------------------------
# Check architecture
# ------------------------------------------------------------------------------

print_step "Checking system architecture"

ARCHITECTURE="$(dpkg --print-architecture)"

print_info "Architecture: $ARCHITECTURE"

if [[ "$ARCHITECTURE" != "amd64" && "$ARCHITECTURE" != "arm64" ]]; then
    die "Unsupported architecture: $ARCHITECTURE

Currently supported architectures:
    amd64
    arm64"
fi

print_success "Architecture $ARCHITECTURE is supported"


# ==============================================================================
# Update package information
# ==============================================================================

print_step "Updating APT package information"

sudo apt-get update

print_success "APT package information updated"


# ==============================================================================
# Base system / development tools
# ==============================================================================

print_step "Installing base development tools"

sudo apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    ninja-build \
    pkg-config \
    git \
    ccache

print_success "Base development tools installed"


# ==============================================================================
# General command-line utilities
# ==============================================================================

print_step "Installing general command-line utilities"

sudo apt-get install -y \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    gawk \
    unzip \
    zip \
    tar \
    xz-utils \
    bzip2 \
    rsync \
    file \
    tree

print_success "General command-line utilities installed"


# ==============================================================================
# Python
# ==============================================================================

print_step "Installing Python development environment"

sudo apt-get install -y \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    python3-setuptools \
    python3-wheel

print_success "Python development environment installed"


# ==============================================================================
# Build and runtime libraries commonly required by the project
# ==============================================================================

print_step "Installing common development libraries"

sudo apt-get install -y \
    libtool \
    libtool-bin \
    libxml2-dev \
    libxslt1-dev \
    libssl-dev

print_success "Common development libraries installed"


# ==============================================================================
# Git / repository support
# ==============================================================================

print_step "Checking Git"

if ! command_exists git; then
    die "Git installation failed."
fi

GIT_VERSION="$(git --version)"
print_info "$GIT_VERSION"

print_success "Git is available"


# ==============================================================================
# Compiler verification
# ==============================================================================

print_step "Checking C/C++ compiler"

if ! command_exists gcc; then
    die "gcc is not available after installation."
fi

if ! command_exists g++; then
    die "g++ is not available after installation."
fi

GCC_VERSION="$(gcc --version | head -n 1)"
GXX_VERSION="$(g++ --version | head -n 1)"

print_info "$GCC_VERSION"
print_info "$GXX_VERSION"

print_success "C/C++ compiler is available"


# ==============================================================================
# CMake verification
# ==============================================================================

print_step "Checking CMake"

if ! command_exists cmake; then
    die "CMake is not available after installation."
fi

CMAKE_VERSION="$(cmake --version | head -n 1)"

print_info "$CMAKE_VERSION"

print_success "CMake is available"


# ==============================================================================
# Python verification
# ==============================================================================

print_step "Checking Python"

if ! command_exists python3; then
    die "python3 is not available after installation."
fi

if ! command_exists pip3; then
    print_warning "pip3 command was not found."
else
    print_info "Python : $(python3 --version)"
    print_info "pip    : $(pip3 --version)"
fi

if ! python3 -m venv --help >/dev/null 2>&1; then
    die "Python virtual environment support is not available."
fi

print_success "Python 3 and virtual environment support are available"


# ==============================================================================
# ccache verification
# ==============================================================================

print_step "Checking ccache"

if command_exists ccache; then
    print_info "ccache: $(ccache --version | head -n 1)"
    print_success "ccache is available"
else
    print_warning "ccache was not found."
fi


# ==============================================================================
# User groups
# ==============================================================================

print_step "Checking user groups"

if getent group dialout >/dev/null 2>&1; then

    if id -nG "$USER" | grep -qw dialout; then
        print_success "User '$USER' is already a member of dialout"
    else
        print_info "Adding '$USER' to the dialout group"

        sudo usermod -a -G dialout "$USER"

        print_warning "The dialout group membership will become active after"
        print_warning "logging out and logging back in."
    fi

else
    print_warning "dialout group was not found."
fi


# ==============================================================================
# Git configuration check
# ==============================================================================

print_step "Checking Git user configuration"

GIT_USER_NAME="$(git config --global user.name || true)"
GIT_USER_EMAIL="$(git config --global user.email || true)"

if [[ -n "$GIT_USER_NAME" ]]; then
    print_info "Git user.name : $GIT_USER_NAME"
else
    print_warning "Git user.name is not configured."
    print_warning "You can configure it later with:"
    print_warning "    git config --global user.name \"Your Name\""
fi

if [[ -n "$GIT_USER_EMAIL" ]]; then
    print_info "Git user.email: $GIT_USER_EMAIL"
else
    print_warning "Git user.email is not configured."
    print_warning "You can configure it later with:"
    print_warning "    git config --global user.email \"you@example.com\""
fi


# ==============================================================================
# Final verification
# ==============================================================================

print_header "Prerequisite Verification"

print_info "Operating system : Ubuntu $OS_RELEASE ($OS_CODENAME)"
print_info "Architecture     : $ARCHITECTURE"
print_info "Python           : $(python3 --version)"
print_info "CMake            : $(cmake --version | head -n 1)"
print_info "GCC              : $(gcc --version | head -n 1)"
print_info "G++              : $(g++ --version | head -n 1)"
print_info "Git              : $(git --version)"
print_info "ccache           : $(ccache --version | head -n 1)"


# ==============================================================================
# Completion
# ==============================================================================

print_header "Ubuntu 24.04 Prerequisites Complete"

echo "The common system prerequisites have been installed successfully."
echo
echo "Next setup components will install:"
echo
echo "    1. ROS 2 Jazzy"
echo "    2. Gazebo Harmonic"
echo "    3. ArduPilot"
echo "    4. ArduPilot-Gazebo"
echo "    5. Drone Detection POC"
echo
echo "No setup log files were created."
echo
