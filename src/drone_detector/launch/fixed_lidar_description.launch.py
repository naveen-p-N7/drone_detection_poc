#!/usr/bin/env python3
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition
from launch.substitutions import Command, LaunchConfiguration
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue

import os

from ament_index_python.packages import get_package_share_directory

def generate_launch_description():
    
    use_sim_time = DeclareLaunchArgument(
        "use_sim_time",
        default_value="true",
        description="Use Gazebo simulation time.",
    )

    use_joint_state_gui = DeclareLaunchArgument(
        "use_joint_state_gui",
        default_value="true",
        description="Launch the manual joint-state GUI. Set false for automatic PTZ control.",
    )

    package_share = get_package_share_directory("drone_detector")

    xacro_file = os.path.join(
        package_share,
        "robot_description",
        "fixed_lidar.xacro",
    )

    robot_description = ParameterValue(
        Command(
            [
                "xacro ",
                xacro_file,
            ]
        ),
        value_type=str,
    )

    robot_state_publisher = Node(
        package="robot_state_publisher",
        executable="robot_state_publisher",
        name="robot_state_publisher",
        output="screen",
        parameters=[
            {
                "robot_description": robot_description,
                "use_sim_time": LaunchConfiguration("use_sim_time"),
            }
        ],
    )
    
    joint_state_publisher_gui = Node(
        package="joint_state_publisher_gui",
        executable="joint_state_publisher_gui",
        name="ptz_joint_state_publisher_gui",
        output="screen",
        condition=IfCondition(LaunchConfiguration("use_joint_state_gui")),
    )

    return LaunchDescription(
        [
            use_sim_time,
            use_joint_state_gui,
            robot_state_publisher,
            joint_state_publisher_gui,
        ]
    )
