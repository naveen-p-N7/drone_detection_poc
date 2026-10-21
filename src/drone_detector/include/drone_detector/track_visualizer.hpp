#pragma once

#include <vector>

#include "drone_detector/drone_tracker.hpp"
#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/header.hpp"
#include "visualization_msgs/msg/marker.hpp"

namespace drone_detector
{

/**
 * @brief RViz visualization for persistent drone tracks.
 *
 * Each drone gets a label plus two independent 120-second tails:
 * measurement history and UKF-estimated history.
 */
class TrackVisualizer
{
public:
  TrackVisualizer(
    rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr measurement_tail_publisher,
    rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr ukf_tail_publisher,
    rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr track_id_publisher,
    double tail_seconds = 3.0);

  void publish(
    const std::vector<DroneTrack> & tracks,
    const std_msgs::msg::Header & header) const;

private:
  visualization_msgs::msg::Marker makeTextMarker(
    const DroneTrack & track,
    const std_msgs::msg::Header & header) const;

  visualization_msgs::msg::Marker makePathMarker(
    const DroneTrack & track,
    bool measurement_path,
    const std_msgs::msg::Header & header) const;

  rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr measurement_tail_publisher_;
  rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr ukf_tail_publisher_;
  rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr track_id_publisher_;
  double tail_seconds_;
};

}  // namespace drone_detector
