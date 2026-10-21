#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_DIR/config/environment.sh"

cd "$ARDUPILOT_DIR/ArduCopter"

sim_vehicle.py \
  -v ArduCopter \
  -f gazebo-iris \
  --model JSON \
  -I 1 \
  --auto-sysid
