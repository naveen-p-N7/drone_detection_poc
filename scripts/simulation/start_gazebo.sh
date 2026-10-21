#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_DIR/config/environment.sh"

gz sim -v4 -r "$PROJECT_DIR/simulation/gazebo/worlds/iris_runway.sdf"
