#!/bin/bash

set -e

source /opt/ros/jazzy/setup.bash

rviz2 --ros-args -p use_sim_time:=true
