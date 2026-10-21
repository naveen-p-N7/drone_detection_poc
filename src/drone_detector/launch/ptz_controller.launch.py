from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    use_sim_time = DeclareLaunchArgument(
        "use_sim_time",
        default_value="true",
        description="Use simulation time for tracking message timestamps and TF.",
    )
    target_track_id = DeclareLaunchArgument(
        "target_track_id",
        default_value="1",
        description="Persistent drone track ID for the PTZ to follow.",
    )

    # 1. PTZ Tracking Controller Node
    ptz_controller = Node(
        package="drone_detector",
        executable="ptz_controller_node",
        name="ptz_controller",
        output="screen",
        parameters=[{
            "use_sim_time": LaunchConfiguration("use_sim_time"),
            "target_track_id": LaunchConfiguration("target_track_id"),
            "target_frame": "camera_base_link",
            "tracks_topic": "/drone_detection/tracks",
            "joint_states_topic": "/ptz_camera/measured_joint_states",
            "use_measurement": False,
            "max_pan_rate": 2.5,
            "pan_gain": 4.0,
            "max_tilt_rate": 0.6,
            "prediction_lead_time": 0.15,
        }],
    )

    # 2. Forward Gazebo's measured joint state to robot_state_publisher / RViz.
    joint_state_bridge = Node(
        package="drone_detector",
        executable="ptz_joint_state_bridge.py",
        name="ptz_joint_state_bridge",
        output="screen",
        parameters=[{
            "use_sim_time": LaunchConfiguration("use_sim_time"),
            "measured_joint_states_topic": "/ptz_camera/measured_joint_states",
            "joint_states_topic": "/joint_states",
        }],
    )

    # 3. ROS-GZ Bridge for Image Feed and Actuation Commands (for Gazebo Sim)
    ros_gz_image_bridge_node = Node(
        package="ros_gz_bridge",
        executable="parameter_bridge",
        name="ptz_camera_image_bridge",
        arguments=[
            "/ptz_camera/image@sensor_msgs/msg/Image[gz.msgs.Image",
            "/ptz_camera/camera_info@sensor_msgs/msg/CameraInfo[gz.msgs.CameraInfo",
            "/ptz_camera/pan_vel_cmd@std_msgs/msg/Float64]gz.msgs.Double",
            "/ptz_camera/tilt_cmd@std_msgs/msg/Float64]gz.msgs.Double",
            "/world/iris_runway/model/ptz_camera/joint_state@sensor_msgs/msg/JointState[gz.msgs.Model",
        ],
        remappings=[
            ("/world/iris_runway/model/ptz_camera/joint_state",
             "/ptz_camera/measured_joint_states"),
        ],
        parameters=[{"use_sim_time": LaunchConfiguration("use_sim_time")}],
        output="screen",
    )

    return LaunchDescription([
        use_sim_time,
        target_track_id,
        ptz_controller,
        joint_state_bridge,
        ros_gz_image_bridge_node,
    ])
