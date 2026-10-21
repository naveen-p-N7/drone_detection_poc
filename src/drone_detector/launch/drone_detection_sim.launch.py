#!/usr/bin/env python3

"""
Drone Detection POC - ROS 2 Simulation Launch

Launches the ROS-side components required by the drone detection
simulation:

    1. Gazebo clock bridge
    2. Gazebo LiDAR point-cloud bridge
    3. Drone detector node
    4. RViz

Gazebo and ArduPilot SITL are intentionally not launched here.
They are managed independently by the simulation scripts.

Usage:
    ros2 launch drone_detector drone_detection_sim.launch.py

Prerequisites:
    - ROS 2 Jazzy
    - Gazebo Harmonic
    - ros_gz_bridge
    - Gazebo simulation already running
    - ArduPilot SITL already running
    - drone_detector package built
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration
from launch.launch_description_sources import PythonLaunchDescriptionSource

from launch_ros.actions import Node

import os

from ament_index_python.packages import get_package_share_directory


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

GAZEBO_WORLD = "iris_runway"

GAZEBO_CLOCK_TOPIC = f"/world/{GAZEBO_WORLD}/clock"
ROS_CLOCK_TOPIC = "/clock"

GAZEBO_LIDAR_TOPIC = "/fixed_lidar/points/points"
ROS_LIDAR_TOPIC = "/fixed_lidar/points/points"

RVIZ_CONFIG = os.path.join(
    get_package_share_directory("drone_detector"),
    "launch",
    "rviz",
    "drone_detection.rviz",
)


# ---------------------------------------------------------------------------
# Launch Description
# ---------------------------------------------------------------------------

def generate_launch_description():
    """
    Create and return the ROS 2 launch description.
    """
    
    package_share = get_package_share_directory("drone_detector")

    fixed_lidar_description_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(
                package_share,
                "launch",
                "fixed_lidar_description.launch.py",
            )
        ),
        launch_arguments={
            "use_sim_time": LaunchConfiguration("use_sim_time"),
            "use_joint_state_gui": LaunchConfiguration("use_joint_state_gui"),
        }.items(),
    )

    # -----------------------------------------------------------------------
    # Launch arguments
    # -----------------------------------------------------------------------

    use_sim_time = DeclareLaunchArgument(
        "use_sim_time",
        default_value="true",
        description="Use Gazebo simulation time instead of system time.",
    )

    use_joint_state_gui = DeclareLaunchArgument(
        "use_joint_state_gui",
        default_value="false",
        description="Launch manual joint-state GUI; set false for automatic PTZ control.",
    )

    enable_rviz = DeclareLaunchArgument(
        "enable_rviz",
        default_value="true",
        description="Start RViz.",
    )

    enable_detector = DeclareLaunchArgument(
        "enable_detector",
        default_value="true",
        description="Start the drone detector node.",
    )

    ransac = DeclareLaunchArgument(
        "ransac",
        default_value="1",
        description="Enable (1) or disable (0) RANSAC ground removal.",
    )

    # -----------------------------------------------------------------------
    # Gazebo Clock -> ROS Clock Bridge
    # -----------------------------------------------------------------------

    clock_bridge = Node(
        package="ros_gz_bridge",
        executable="parameter_bridge",
        name="gazebo_clock_bridge",
        output="screen",
        arguments=[
            f"{GAZEBO_CLOCK_TOPIC}"
            "@rosgraph_msgs/msg/Clock"
            "@gz.msgs.Clock",
            "--ros-args",
            "-r",
            f"{GAZEBO_CLOCK_TOPIC}:={ROS_CLOCK_TOPIC}",
        ],
    )

    # -----------------------------------------------------------------------
    # Gazebo LiDAR -> ROS PointCloud2 Bridge
    # -----------------------------------------------------------------------

    lidar_bridge = Node(
        package="ros_gz_bridge",
        executable="parameter_bridge",
        name="lidar_pointcloud_bridge",
        output="screen",
        arguments=[
            f"{GAZEBO_LIDAR_TOPIC}"
            "@sensor_msgs/msg/PointCloud2"
            "@gz.msgs.PointCloudPacked",
        ],
    )

    # -----------------------------------------------------------------------
    # Drone Detector
    # -----------------------------------------------------------------------

    drone_detector = Node(
        package="drone_detector",
        executable="drone_detector_node",
        name="drone_detector",
        output="screen",
        arguments=[
            "--ransac",
            LaunchConfiguration("ransac"),
        ],
        parameters=[
            {
                "use_sim_time": LaunchConfiguration("use_sim_time"),
            }
        ],
        condition=IfCondition(
            LaunchConfiguration("enable_detector")
        ),
    )

    # -----------------------------------------------------------------------
    # RViz
    # -----------------------------------------------------------------------

    rviz = Node(
        package="rviz2",
        executable="rviz2",
        name="rviz2",
        output="screen",
        arguments=[
            "-d",
            RVIZ_CONFIG,
        ],
        parameters=[
            {
                "use_sim_time": LaunchConfiguration("use_sim_time"),
            }
        ],
        condition=IfCondition(
            LaunchConfiguration("enable_rviz")
        ),
    )

    # -----------------------------------------------------------------------
    # LaunchDescription
    # -----------------------------------------------------------------------


    return LaunchDescription(
        [
            use_sim_time,
            use_joint_state_gui,
            enable_rviz,
            enable_detector,
            ransac,
            
            fixed_lidar_description_launch,

            clock_bridge,
            lidar_bridge,
            drone_detector,
            rviz,            
        ]
    )
