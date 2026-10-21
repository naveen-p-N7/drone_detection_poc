#include <algorithm>
#include <chrono>
#include <cmath>
#include <functional>
#include <limits>
#include <memory>
#include <string>

#include <geometry_msgs/msg/point_stamped.hpp>
#include <rclcpp/rclcpp.hpp>
#include <sensor_msgs/msg/joint_state.hpp>
#include <std_msgs/msg/float64.hpp>
#include <tf2/exceptions.h>
#include <tf2/time.hpp>
#include <tf2_geometry_msgs/tf2_geometry_msgs.hpp>
#include <tf2_ros/buffer.h>
#include <tf2_ros/transform_listener.h>

#include "drone_detector/msg/tracked_drone_array.hpp"

namespace drone_detector
{

class PtzControllerNode final : public rclcpp::Node
{
public:
  PtzControllerNode()
  : Node("ptz_controller"),
    tf_buffer_(get_clock()),
    tf_listener_(tf_buffer_),
    last_update_steady_(std::chrono::steady_clock::now())
  {
    target_track_id_ = declare_parameter<int>("target_track_id", 1);
    target_frame_ = declare_parameter<std::string>("target_frame", "camera_base_link");
    tracks_topic_ = declare_parameter<std::string>("tracks_topic", "/drone_detection/tracks");
    joint_states_topic_ = declare_parameter<std::string>(
      "joint_states_topic", "/ptz_camera/measured_joint_states");
    tilt_min_ = declare_parameter<double>("tilt_min", -1.0472);
    tilt_max_ = declare_parameter<double>("tilt_max", 1.0472);
    max_pan_rate_ = declare_parameter<double>("max_pan_rate", 2.5);
    pan_gain_ = declare_parameter<double>("pan_gain", 4.0);
    max_tilt_rate_ = declare_parameter<double>("max_tilt_rate", 0.6);
    prediction_lead_time_ = declare_parameter<double>("prediction_lead_time", 0.15);
    use_measurement_ = declare_parameter<bool>("use_measurement", false);

    // Gazebo consumes angular velocity for the continuous pan joint.
    pan_pub_ = create_publisher<std_msgs::msg::Float64>(
      "/ptz_camera/pan_vel_cmd", rclcpp::QoS(1).reliable());
    tilt_pub_ = create_publisher<std_msgs::msg::Float64>(
      "/ptz_camera/tilt_cmd", rclcpp::QoS(1).reliable());

    tracks_sub_ = create_subscription<drone_detector::msg::TrackedDroneArray>(
      tracks_topic_, rclcpp::SensorDataQoS().keep_last(1),
      std::bind(&PtzControllerNode::tracksCallback, this, std::placeholders::_1));

    joint_states_sub_ = create_subscription<sensor_msgs::msg::JointState>(
      joint_states_topic_, rclcpp::SensorDataQoS().keep_last(1),
      std::bind(&PtzControllerNode::jointStatesCallback, this, std::placeholders::_1));

    RCLCPP_INFO(
      get_logger(),
      "PTZ controller started. target_track_id=%d, target_frame='%s', "
      "tracks='%s', measured joint states='%s'.",
      target_track_id_, target_frame_.c_str(),
      tracks_topic_.c_str(), joint_states_topic_.c_str());
  }

private:
  void tracksCallback(const drone_detector::msg::TrackedDroneArray::SharedPtr msg)
  {
    if (!have_joint_state_) {
      stopPanMotion();
      RCLCPP_WARN_THROTTLE(
        get_logger(), *get_clock(), 3000,
        "Waiting for measured Gazebo PTZ joint states on '%s'.", joint_states_topic_.c_str());
      return;
    }
    const auto found = std::find_if(
      msg->tracks.begin(), msg->tracks.end(),
      [this](const auto & track) { return track.track_id == target_track_id_; });

    if (found == msg->tracks.end()) {
      stopPanMotion();
      RCLCPP_WARN_THROTTLE(
        get_logger(), *get_clock(), 3000,
        "Target track %d is not present in the tracking message.", target_track_id_);
      return;
    }

    if (!found->confirmed || !found->visible) {
      stopPanMotion();
      RCLCPP_WARN_THROTTLE(
        get_logger(), *get_clock(), 3000,
        "Target track %d is not confirmed/visible; holding last PTZ command.", target_track_id_);
      return;
    }

    geometry_msgs::msg::PointStamped target_in_source;
    target_in_source.header = msg->header;
    target_in_source.point = (use_measurement_ && found->measurement_valid) ?
      found->measurement : found->position;

    // Compensate for the cloud/tracking age and the PTZ joint response by
    // aiming at a short velocity-projected future position.
    const double message_age = std::max(
      0.0, (nowRosTime() - rclcpp::Time(msg->header.stamp, RCL_ROS_TIME)).seconds());
    const double prediction_time = std::clamp(
      message_age + prediction_lead_time_, 0.0, 0.5);
    target_in_source.point.x += found->velocity.x * prediction_time;
    target_in_source.point.y += found->velocity.y * prediction_time;
    target_in_source.point.z += found->velocity.z * prediction_time;

    geometry_msgs::msg::PointStamped target_in_camera_base;
    try {
      target_in_camera_base = tf_buffer_.transform(
        target_in_source, target_frame_, tf2::durationFromSec(0.05));
    } catch (const tf2::TransformException & ex) {
      stopPanMotion();
      RCLCPP_WARN_THROTTLE(
        get_logger(), *get_clock(), 3000,
        "Cannot transform target from '%s' to '%s': %s",
        msg->header.frame_id.c_str(), target_frame_.c_str(), ex.what());
      return;
    }

    const double x = target_in_camera_base.point.x;
    const double y = target_in_camera_base.point.y;
    const double z = target_in_camera_base.point.z;
    const double horizontal_distance = std::hypot(x, y);

    const double raw_pan = std::atan2(y, x);
    double desired_tilt = std::atan2(-z, horizontal_distance);
    desired_tilt = std::clamp(desired_tilt, tilt_min_, tilt_max_);

    const auto now = std::chrono::steady_clock::now();
    const double dt = std::clamp(
      std::chrono::duration<double>(now - last_update_steady_).count(), 0.0, 0.25);
    last_update_steady_ = now;

    // Close the pan loop against Gazebo's measured joint angle, rather than
    // integrating the requested velocity and assuming the mechanism followed it.
    const double pan_error = std::atan2(
      std::sin(raw_pan - measured_pan_), std::cos(raw_pan - measured_pan_));
    const double pan_velocity = std::clamp(
      pan_gain_ * pan_error, -max_pan_rate_, max_pan_rate_);
    commanded_tilt_ = moveToward(
      measured_tilt_, desired_tilt, max_tilt_rate_ * dt);

    // 2. Publish Float64 command topics for Gazebo Sim
    std_msgs::msg::Float64 pan_msg;
    std_msgs::msg::Float64 tilt_msg;
    pan_msg.data = pan_velocity;
    tilt_msg.data = commanded_tilt_;
    pan_pub_->publish(pan_msg);
    tilt_pub_->publish(tilt_msg);

    RCLCPP_INFO_THROTTLE(
      get_logger(), *get_clock(), 1000,
      "Track %d target in %s: (%.2f, %.2f, %.2f) m; "
      "command pan=%.1f deg, tilt=%.1f deg, prediction=%.2f s",
      target_track_id_, target_frame_.c_str(), x, y, z,
      radiansToDegrees(measured_pan_), radiansToDegrees(measured_tilt_), prediction_time);
  }

  void jointStatesCallback(const sensor_msgs::msg::JointState::SharedPtr msg)
  {
    for (size_t i = 0; i < msg->name.size() && i < msg->position.size(); ++i) {
      if (isJointName(msg->name[i], "pan_joint")) {
        measured_pan_ = msg->position[i];
        have_pan_state_ = true;
      } else if (isJointName(msg->name[i], "tilt_joint")) {
        measured_tilt_ = msg->position[i];
        have_tilt_state_ = true;
      }
    }
    have_joint_state_ = have_pan_state_ && have_tilt_state_;
  }

  void stopPanMotion()
  {
    std_msgs::msg::Float64 pan_msg;
    pan_msg.data = 0.0;
    pan_pub_->publish(pan_msg);
  }

  rclcpp::Time nowRosTime() const
  {
    return get_clock()->now();
  }

  static double moveToward(double current, double target, double max_delta)
  {
    const double delta = target - current;
    return current + std::clamp(delta, -max_delta, max_delta);
  }

  static bool isJointName(const std::string & name, const std::string & joint)
  {
    return name == joint ||
      (name.size() > joint.size() &&
      name.compare(name.size() - joint.size(), joint.size(), joint) == 0 &&
      name[name.size() - joint.size() - 1] == ':');
  }

  static double radiansToDegrees(double radians)
  {
    return radians * 180.0 / kPi;
  }

  int target_track_id_{1};
  std::string target_frame_;
  std::string tracks_topic_;
  std::string joint_states_topic_;
  static constexpr double kPi = 3.14159265358979323846;
  double tilt_min_{-1.0472};
  double tilt_max_{1.0472};
  double max_pan_rate_{1.0};
  double pan_gain_{2.0};
  double max_tilt_rate_{0.6};
  double prediction_lead_time_{0.15};
  bool use_measurement_{false};
  double commanded_tilt_{0.0};
  double measured_pan_{0.0};
  double measured_tilt_{0.0};
  bool have_pan_state_{false};
  bool have_tilt_state_{false};
  bool have_joint_state_{false};
  std::chrono::steady_clock::time_point last_update_steady_;

  rclcpp::Publisher<std_msgs::msg::Float64>::SharedPtr pan_pub_;
  rclcpp::Publisher<std_msgs::msg::Float64>::SharedPtr tilt_pub_;
  rclcpp::Subscription<drone_detector::msg::TrackedDroneArray>::SharedPtr tracks_sub_;
  rclcpp::Subscription<sensor_msgs::msg::JointState>::SharedPtr joint_states_sub_;
  tf2_ros::Buffer tf_buffer_;
  tf2_ros::TransformListener tf_listener_;
};

}  // namespace drone_detector

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<drone_detector::PtzControllerNode>());
  rclcpp::shutdown();
  return 0;
}
