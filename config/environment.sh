#!/bin/bash

# Drone Detection POC environment configuration

# Project
export DRONE_DETECTION_POC_DIR="$HOME/drone_detection_poc"

# External dependencies
export ARDUPILOT_DIR="$HOME/ardupilot"
export ARDUPILOT_GAZEBO_DIR="$HOME/gz_ws/src/ardupilot_gazebo"

# Gazebo
export GZ_VERSION="harmonic"

# ArduPilot-Gazebo system plugin
export GZ_SIM_SYSTEM_PLUGIN_PATH="${ARDUPILOT_GAZEBO_DIR}/build"

# Project Gazebo resources
export GZ_SIM_RESOURCE_PATH="${DRONE_DETECTION_POC_DIR}/simulation/gazebo/models:${DRONE_DETECTION_POC_DIR}/simulation/gazebo/worlds:${ARDUPILOT_GAZEBO_DIR}/worlds"