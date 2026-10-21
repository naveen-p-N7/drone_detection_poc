#include "drone_detector/track_visualizer.hpp"

#include <iomanip>
#include <sstream>
#include <string>
#include <utility>

namespace drone_detector
{

namespace
{
constexpr int kTextIdBase = 1000;
constexpr int kMeasurementTailIdBase = 2000;
constexpr int kEstimateTailIdBase = 3000;
constexpr double kTextHeight = 0.16;
constexpr double kTailWidth = 0.025;
}

TrackVisualizer::TrackVisualizer(
  rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr measurement_tail_publisher,
  rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr ukf_tail_publisher,
  rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr track_id_publisher,
  const double tail_seconds)
: measurement_tail_publisher_(std::move(measurement_tail_publisher)),
  ukf_tail_publisher_(std::move(ukf_tail_publisher)),
  track_id_publisher_(std::move(track_id_publisher)),
  tail_seconds_(tail_seconds)
{
}

void TrackVisualizer::publish(
  const std::vector<DroneTrack> & tracks,
  const std_msgs::msg::Header & header) const
{
  for (const auto & track : tracks) {
    if (!track.confirmed) {
      continue;
    }

    track_id_publisher_->publish(makeTextMarker(track, header));
    measurement_tail_publisher_->publish(makePathMarker(track, true, header));
    ukf_tail_publisher_->publish(makePathMarker(track, false, header));
  }
}

visualization_msgs::msg::Marker TrackVisualizer::makeTextMarker(
  const DroneTrack & track,
  const std_msgs::msg::Header & header) const
{
  visualization_msgs::msg::Marker marker;
  marker.header = header;
  marker.ns = "drone_track_id";
  marker.id = kTextIdBase + track.track_id;
  marker.type = visualization_msgs::msg::Marker::TEXT_VIEW_FACING;
  marker.action = visualization_msgs::msg::Marker::ADD;
  marker.pose.position = track.position;
  marker.pose.position.z += 0.30;
  marker.pose.orientation.w = 1.0;
  marker.scale.z = kTextHeight;
  marker.color.r = 1.0;
  marker.color.g = 1.0;
  marker.color.b = 1.0;
  marker.color.a = 1.0;

  std::ostringstream text;
  text << "DRONE " << track.track_id;
  if (!track.visible) {
    text << " [PREDICTED]";
  }
  marker.text = text.str();
  return marker;
}

visualization_msgs::msg::Marker TrackVisualizer::makePathMarker(
  const DroneTrack & track,
  const bool measurement_path,
  const std_msgs::msg::Header & header) const
{
  visualization_msgs::msg::Marker marker;
  marker.header = header;
  marker.ns = measurement_path ? "drone_measurement_tail" : "drone_ukf_tail";
  marker.id = (measurement_path ? kMeasurementTailIdBase : kEstimateTailIdBase) + track.track_id;
  marker.type = visualization_msgs::msg::Marker::LINE_STRIP;
  marker.action = visualization_msgs::msg::Marker::ADD;
  marker.scale.x = kTailWidth;
  marker.pose.orientation.w = 1.0;
  marker.color.a = 0.95;

  if (measurement_path) {
    // Measurement tail: warm color.
    marker.color.r = 1.0;
    marker.color.g = 0.55;
    marker.color.b = 0.05;
    for (const auto & sample : track.measurement_history) {
      marker.points.push_back(sample.point);
    }
  } else {
    // UKF tail: cool color.
    marker.color.r = 0.1;
    marker.color.g = 0.8;
    marker.color.b = 1.0;
    for (const auto & sample : track.estimate_history) {
      marker.points.push_back(sample.point);
    }
  }

  // The tracker already prunes history to the requested duration. Keep this
  // parameter here as documentation for the RViz component's contract.
  (void)tail_seconds_;
  return marker;
}


}  // namespace drone_detector
