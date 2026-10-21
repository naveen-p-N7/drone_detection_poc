#!/usr/bin/env python3
"""Forward measured PTZ joint states to /joint_states for robot_state_publisher."""

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import JointState
from rclpy.qos import QoSHistoryPolicy, QoSProfile, QoSReliabilityPolicy


class PtzJointStateBridge(Node):
    def __init__(self):
        super().__init__('ptz_joint_state_bridge')
        self.declare_parameter(
            'measured_joint_states_topic', '/ptz_camera/measured_joint_states'
        )
        self.declare_parameter('joint_states_topic', '/joint_states')
        measured_joint_states_topic = self.get_parameter(
            'measured_joint_states_topic'
        ).value
        joint_states_topic = self.get_parameter('joint_states_topic').value
        self.publisher = self.create_publisher(
            JointState, joint_states_topic, QoSProfile(depth=1)
        )
        latest_state_qos = QoSProfile(
            history=QoSHistoryPolicy.KEEP_LAST,
            depth=1,
            reliability=QoSReliabilityPolicy.BEST_EFFORT,
        )
        self.subscription = self.create_subscription(
            JointState, measured_joint_states_topic, self.command_callback, latest_state_qos
        )
        self.get_logger().info(
            f'Forwarding {measured_joint_states_topic} to {joint_states_topic}. '
            'RViz now follows Gazebo-measured angles, not controller requests.'
        )

    def command_callback(self, msg):
        # Preserve the measured positions and timestamps for robot_state_publisher.
        self.publisher.publish(msg)


def main(args=None):
    rclpy.init(args=args)
    node = PtzJointStateBridge()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
