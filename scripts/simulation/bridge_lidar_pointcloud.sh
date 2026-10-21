#!/bin/bash
source /opt/ros/jazzy/setup.bash

ros2 run ros_gz_bridge parameter_bridge   /fixed_lidar/points/points@sensor_msgs/msg/PointCloud2@gz.msgs.PointCloudPacked
