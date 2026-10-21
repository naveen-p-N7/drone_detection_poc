// #include <algorithm>
// #include <chrono>
// #include <cmath>
// #include <functional>
// #include <limits>
// #include <memory>
// #include <string>

// #include <geometry_msgs/msg/point_stamped.hpp>
// #include <rclcpp/rclcpp.hpp>
// #include <sensor_msgs/msg/joint_state.hpp>
// #include <tf2/exceptions.h>
// #include <tf2/time.hpp>
// #include <tf2_geometry_msgs/tf2_geometry_msgs.hpp>
// #include <tf2_ros/buffer.h>
// #include <tf2_ros/transform_listener.h>

// #include "drone_detector/msg/tracked_drone_array.hpp"

// namespace drone_detector
// {

// class PtzControllerNode final : public rclcpp::Node
// {
// public:
//   PtzControllerNode()
//   : Node("ptz_controller"),
//     tf_buffer_(get_clock()),
//     tf_listener_(tf_buffer_),
//     last_update_steady_(std::chrono::steady_clock::now())
//   {
//     target_track_id_ = declare_parameter<int>("target_track_id", 1);
//     target_frame_ = declare_parameter<std::string>(
//       "target_frame", "camera_base_link");
//     tracks_topic_ = declare_parameter<std::string>(
//       "tracks_topic", "/drone_detection/tracks");
//     command_topic_ = declare_parameter<std::string>(
//       "command_topic", "/ptz_controller/joint_commands");
//     pan_min_ = declare_parameter<double>("pan_min", -3.14159);
//     pan_max_ = declare_parameter<double>("pan_max", 3.14159);
//     tilt_min_ = declare_parameter<double>("tilt_min", -1.0472);
//     tilt_max_ = declare_parameter<double>("tilt_max", 1.0472);
//     max_pan_rate_ = declare_parameter<double>("max_pan_rate", 1.0);
//     max_tilt_rate_ = declare_parameter<double>("max_tilt_rate", 0.6);
//     use_measurement_ = declare_parameter<bool>("use_measurement", false);

//     command_pub_ = create_publisher<sensor_msgs::msg::JointState>(
//       command_topic_, rclcpp::QoS(10));

//     tracks_sub_ = create_subscription<drone_detector::msg::TrackedDroneArray>(
//       tracks_topic_, rclcpp::QoS(10),
//       std::bind(&PtzControllerNode::tracksCallback, this, std::placeholders::_1));

//     RCLCPP_INFO(
//       get_logger(),
//       "PTZ controller started. target_track_id=%d, target_frame='%s', "
//       "input='%s', command output='%s'. Output is desired joint commands, "
//       "not direct Gazebo actuation yet.",
//       target_track_id_, target_frame_.c_str(),
//       tracks_topic_.c_str(), command_topic_.c_str());
//   }

// private:
//   void tracksCallback(
//     const drone_detector::msg::TrackedDroneArray::SharedPtr msg)
//   {
//     const auto found = std::find_if(
//       msg->tracks.begin(), msg->tracks.end(),
//       [this](const auto & track) { return track.track_id == target_track_id_; });

//     if (found == msg->tracks.end()) {
//       RCLCPP_WARN_THROTTLE(
//         get_logger(), *get_clock(), 3000,
//         "Target track %d is not present in the tracking message.",
//         target_track_id_);
//       return;
//     }

//     if (!found->confirmed || !found->visible) {
//       RCLCPP_WARN_THROTTLE(
//         get_logger(), *get_clock(), 3000,
//         "Target track %d is not confirmed/visible; holding last PTZ command.",
//         target_track_id_);
//       return;
//     }

//     geometry_msgs::msg::PointStamped target_in_source;
//     target_in_source.header = msg->header;
//     target_in_source.point = (use_measurement_ && found->measurement_valid) ?
//       found->measurement : found->position;

//     geometry_msgs::msg::PointStamped target_in_camera_base;
//     try {
//       // Transform at the measurement timestamp, not at the latest available time.
//       target_in_camera_base = tf_buffer_.transform(
//         target_in_source, target_frame_, tf2::durationFromSec(0.05));
//     } catch (const tf2::TransformException & ex) {
//       RCLCPP_WARN_THROTTLE(
//         get_logger(), *get_clock(), 3000,
//         "Cannot transform target from '%s' to '%s': %s",
//         msg->header.frame_id.c_str(), target_frame_.c_str(), ex.what());
//       return;
//     }

//     const double x = target_in_camera_base.point.x;
//     const double y = target_in_camera_base.point.y;
//     const double z = target_in_camera_base.point.z;
//     const double horizontal_distance = std::hypot(x, y);

//     // Raw pan angle is wrapped to [-pi, pi] by atan2().
//     const double raw_pan = std::atan2(y, x);

//     // Choose the shortest angular change from the current pan command.
//     // This prevents a jump from +179 degrees to -179 degrees.
//     const double pan_error = std::atan2(
//       std::sin(raw_pan - commanded_pan_),
//       std::cos(raw_pan - commanded_pan_));

//     // Keep the desired pan angle continuous across the +/-180-degree boundary.
//     const double desired_pan = commanded_pan_ + pan_error;

//     // Positive rotation around +Y points +X toward -Z.
//     double desired_tilt = std::atan2(-z, horizontal_distance);

//     // Tilt remains bounded by the physical joint limits.
//     desired_tilt = std::clamp(desired_tilt, tilt_min_, tilt_max_);

//     const auto now = std::chrono::steady_clock::now();
//     const double dt = std::chrono::duration<double>(now - last_update_steady_).count();
//     last_update_steady_ = now;

//     commanded_pan_ = moveToward(
//       commanded_pan_, desired_pan, max_pan_rate_ * std::max(0.0, dt));
//     commanded_tilt_ = moveToward(
//       commanded_tilt_, desired_tilt, max_tilt_rate_ * std::max(0.0, dt));

//     sensor_msgs::msg::JointState command;
//     command.header.stamp = nowRosTime();
//     command.name = {"pan_joint", "tilt_joint"};
//     command.position = {commanded_pan_, commanded_tilt_};
//     command.velocity = {0.0, 0.0};
//     command.effort = {};
//     command_pub_->publish(command);

//     RCLCPP_INFO_THROTTLE(
//       get_logger(), *get_clock(), 1000,
//       "Track %d target in %s: (%.2f, %.2f, %.2f) m; "
//       "desired pan=%.1f deg, tilt=%.1f deg; command pan=%.1f deg, tilt=%.1f deg",
//       target_track_id_, target_frame_.c_str(), x, y, z,
//       radiansToDegrees(desired_pan), radiansToDegrees(desired_tilt),
//       radiansToDegrees(commanded_pan_), radiansToDegrees(commanded_tilt_));
//   }

//   rclcpp::Time nowRosTime() const
//   {
//     return get_clock()->now();
//   }

//   static double moveToward(double current, double target, double max_delta)
//   {
//     const double delta = target - current;
//     return current + std::clamp(delta, -max_delta, max_delta);
//   }

//   static double radiansToDegrees(double radians)
//   {
//     return radians * 180.0 / kPi;
//   }

//   int target_track_id_{1};
//   std::string target_frame_;
//   std::string tracks_topic_;
//   std::string command_topic_;
//   static constexpr double kPi = 3.14159265358979323846;
//   double pan_min_{-kPi};
//   double pan_max_{M_PI};
//   double tilt_min_{-1.0472};
//   double tilt_max_{1.0472};
//   double max_pan_rate_{1.0};
//   double max_tilt_rate_{0.6};
//   bool use_measurement_{false};
//   double commanded_pan_{0.0};
//   double commanded_tilt_{0.0};
//   std::chrono::steady_clock::time_point last_update_steady_;

//   rclcpp::Publisher<sensor_msgs::msg::JointState>::SharedPtr command_pub_;
//   rclcpp::Subscription<drone_detector::msg::TrackedDroneArray>::SharedPtr tracks_sub_;
//   tf2_ros::Buffer tf_buffer_;
//   tf2_ros::TransformListener tf_listener_;
// };

// }  // namespace drone_detector

// int main(int argc, char ** argv)
// {
//   rclcpp::init(argc, argv);
//   rclcpp::spin(std::make_shared<drone_detector::PtzControllerNode>());
//   rclcpp::shutdown();
//   return 0;
// }
