#include "drone_detector/marker_visualizer.hpp"

#include <utility>

#include <geometry_msgs/msg/point.hpp>

#include "drone_detector/detector_config.hpp"

namespace drone_detector
{

namespace
{

geometry_msgs::msg::Point makePoint(
  const float x,
  const float y,
  const float z)
{
  geometry_msgs::msg::Point point;
  point.x = x;
  point.y = y;
  point.z = z;
  return point;
}

void addEdge(
  visualization_msgs::msg::Marker & marker,
  const geometry_msgs::msg::Point & first,
  const geometry_msgs::msg::Point & second)
{
  marker.points.push_back(first);
  marker.points.push_back(second);
}

}  // namespace

MarkerVisualizer::MarkerVisualizer(
  rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr publisher,
  const float line_width_m)
: publisher_(std::move(publisher)),
  line_width_m_(line_width_m)
{
}

void MarkerVisualizer::clear(const std_msgs::msg::Header & header) const
{
  visualization_msgs::msg::Marker marker;
  marker.header = header;
  marker.ns = "drone_detection";
  marker.action = visualization_msgs::msg::Marker::DELETEALL;

  publisher_->publish(marker);
}

visualization_msgs::msg::Marker MarkerVisualizer::makeBoxMarker(
  const ClusterFeatures & features,
  const std_msgs::msg::Header & header,
  const float line_width_m)
{
  const auto & box = features.bounding_box;

  const auto p000 = makePoint(box.min_x, box.min_y, box.min_z);
  const auto p001 = makePoint(box.min_x, box.min_y, box.max_z);
  const auto p010 = makePoint(box.min_x, box.max_y, box.min_z);
  const auto p011 = makePoint(box.min_x, box.max_y, box.max_z);
  const auto p100 = makePoint(box.max_x, box.min_y, box.min_z);
  const auto p101 = makePoint(box.max_x, box.min_y, box.max_z);
  const auto p110 = makePoint(box.max_x, box.max_y, box.min_z);
  const auto p111 = makePoint(box.max_x, box.max_y, box.max_z);

  visualization_msgs::msg::Marker marker;
  marker.header = header;
  marker.ns = "drone_detection";
  marker.id = static_cast<int>(features.id);
  marker.type = visualization_msgs::msg::Marker::LINE_LIST;
  marker.action = visualization_msgs::msg::Marker::ADD;

  // LINE_LIST uses scale.x as line width.
  marker.scale.x = line_width_m;

  marker.color.r = config::kMarkerRed;
  marker.color.g = config::kMarkerGreen;
  marker.color.b = config::kMarkerBlue;
  marker.color.a = config::kMarkerAlpha;

  // Bottom rectangle.
  addEdge(marker, p000, p010);
  addEdge(marker, p010, p110);
  addEdge(marker, p110, p100);
  addEdge(marker, p100, p000);

  // Top rectangle.
  addEdge(marker, p001, p011);
  addEdge(marker, p011, p111);
  addEdge(marker, p111, p101);
  addEdge(marker, p101, p001);

  // Vertical edges.
  addEdge(marker, p000, p001);
  addEdge(marker, p010, p011);
  addEdge(marker, p100, p101);
  addEdge(marker, p110, p111);

  return marker;
}

void MarkerVisualizer::publishBox(
  const ClusterFeatures & features,
  const std_msgs::msg::Header & header) const
{
  publisher_->publish(makeBoxMarker(features, header, line_width_m_));
}

}  // namespace drone_detector
