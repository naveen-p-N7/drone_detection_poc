#pragma once

#include "drone_detector/detection_types.hpp"

#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/header.hpp"
#include "visualization_msgs/msg/marker.hpp"

namespace drone_detector
{

/**
 * @brief Publishes RViz wireframe bounding boxes.
 *
 * Uses visualization_msgs/Marker LINE_LIST instead of a filled CUBE, so the
 * detected point cloud remains visible through the box.
 */
class MarkerVisualizer
{
public:
  /**
   * @param publisher Marker publisher shared with the detector node.
   * @param line_width_m Marker line width in metres.
   */
  MarkerVisualizer(
    rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr publisher,
    float line_width_m);

  /**
   * @brief Delete all previous detector markers.
   * @param header Current point-cloud header.
   */
  void clear(const std_msgs::msg::Header & header) const;

  /**
   * @brief Publish one cluster's bounding box as a wireframe marker.
   * @param features Geometric features of the cluster.
   * @param header Current point-cloud header.
   */
  void publishBox(
    const ClusterFeatures & features,
    const std_msgs::msg::Header & header) const;

private:
  static visualization_msgs::msg::Marker makeBoxMarker(
    const ClusterFeatures & features,
    const std_msgs::msg::Header & header,
    float line_width_m);

  rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr publisher_;
  float line_width_m_;
};

}  // namespace drone_detector
