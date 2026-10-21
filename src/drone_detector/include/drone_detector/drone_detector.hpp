#pragma once

#include "drone_detector/cluster_features.hpp"
#include "drone_detector/dbscan_clusterer.hpp"
#include "drone_detector/euclidean_clusterer.hpp"
#include "drone_detector/marker_visualizer.hpp"
#include "drone_detector/point_cloud_preprocessor.hpp"
#include "drone_detector/ransac_segmenter.hpp"
#include "drone_detector/drone_tracker.hpp"
#include "drone_detector/track_visualizer.hpp"
#include "drone_detector/msg/tracked_drone_array.hpp"

#include "rclcpp/rclcpp.hpp"
#include "sensor_msgs/msg/point_cloud2.hpp"

namespace drone_detector
{

/**
 * @brief ROS 2 orchestration node for fixed-LiDAR drone detection.
 *
 * The node coordinates the perception pipeline but delegates algorithms to
 * focused classes:
 *
 * PointCloud2 -> PCL -> finite-point filtering -> optional RANSAC -> DBSCAN ->
 * cluster features -> RViz markers.
 */
class DroneDetectorNode : public rclcpp::Node
{
public:
  /// Construct the node, publishers, subscription, and processing components.
  explicit DroneDetectorNode(bool ransac_enabled);

private:
  /// Process one incoming LiDAR point cloud.
  void pointCloudCallback(
    const sensor_msgs::msg::PointCloud2::SharedPtr msg);

  /// Log a candidate cluster's geometry.
  void logCandidate(const ClusterFeatures & features) const;

  rclcpp::Subscription<sensor_msgs::msg::PointCloud2>::SharedPtr
    point_cloud_subscription_;

  rclcpp::Publisher<sensor_msgs::msg::PointCloud2>::SharedPtr
    ground_publisher_;

  rclcpp::Publisher<sensor_msgs::msg::PointCloud2>::SharedPtr
    non_ground_publisher_;

  PointCloudPreprocessor preprocessor_;
  bool ransac_enabled_;
  RansacGroundSegmenter ransac_segmenter_;
  EuclideanClusterer dbscan_clusterer_;
  ClusterFeatureExtractor feature_extractor_;
  // Raw detection bounding boxes. Kept on the existing marker topic.
  rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr marker_publisher_;

  // Tracking visualization is deliberately separated from detection boxes.
  rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr measurement_tail_publisher_;
  rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr ukf_tail_publisher_;
  rclcpp::Publisher<visualization_msgs::msg::Marker>::SharedPtr track_id_publisher_;

  // Machine-readable tracked positions for downstream modules such as PTZ control.
  rclcpp::Publisher<drone_detector::msg::TrackedDroneArray>::SharedPtr tracked_drones_publisher_;

  MarkerVisualizer marker_visualizer_;
  DroneTracker tracker_;
  TrackVisualizer track_visualizer_;
};

}  // namespace drone_detector
