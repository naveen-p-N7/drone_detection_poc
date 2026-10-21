#!/bin/bash

set -e

source /opt/ros/jazzy/setup.bash

ros2 run ros_gz_bridge parameter_bridge \
  /world/iris_runway/clock@rosgraph_msgs/msg/Clock@gz.msgs.Clock \
  --ros-args \
  -r /world/iris_runway/clock:=/clock
