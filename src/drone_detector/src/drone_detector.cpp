#include "drone_detector/drone_detector.hpp"

#include <chrono>
#include <cstdint>
#include <stdexcept>
#include <utility>

#include <pcl/filters/voxel_grid.h>

#include "drone_detector/detector_config.hpp"
#include "pcl_conversions/pcl_conversions.h"

namespace drone_detector
{

DroneDetectorNode::DroneDetectorNode(const bool ransac_enabled)
: Node("drone_detector"),
  ransac_enabled_(ransac_enabled),
  ransac_segmenter_(config::kRansacDistanceThresholdMeters),
  dbscan_clusterer_(
      config::kEuclideanClusterToleranceMeters,
      config::kEuclideanClusterMinSize,
    config::kEuclideanClusterMaxSize),
  marker_publisher_(
    this->create_publisher<visualization_msgs::msg::Marker>(
      config::kMarkerTopic,
      config::kMarkerPublisherQueueSize)),
  measurement_tail_publisher_(
    this->create_publisher<visualization_msgs::msg::Marker>(
      config::kMeasurementTailTopic,
      config::kMarkerPublisherQueueSize)),
  ukf_tail_publisher_(
    this->create_publisher<visualization_msgs::msg::Marker>(
      config::kUkfTailTopic,
      config::kMarkerPublisherQueueSize)),
  track_id_publisher_(
    this->create_publisher<visualization_msgs::msg::Marker>(
      config::kTrackIdTopic,
      config::kMarkerPublisherQueueSize)),
  tracked_drones_publisher_(
    this->create_publisher<drone_detector::msg::TrackedDroneArray>(
      config::kTrackedDronesTopic,
      config::kMarkerPublisherQueueSize)),
  marker_visualizer_(
    marker_publisher_,
    config::kMarkerLineWidthMeters),
  tracker_(
    2.0,   // normal association gate
    200.0, // reacquisition gate for a returning demo drone
    2,     // confirmation hits
    3.0),
  track_visualizer_(measurement_tail_publisher_, ukf_tail_publisher_, track_id_publisher_, 5.0)
{
  point_cloud_subscription_ =
    this->create_subscription<sensor_msgs::msg::PointCloud2>(
    config::kPointCloudTopic,
    rclcpp::SensorDataQoS().keep_last(1),
    std::bind(
      &DroneDetectorNode::pointCloudCallback,
      this,
      std::placeholders::_1));

  ground_publisher_ =
    this->create_publisher<sensor_msgs::msg::PointCloud2>(
    config::kGroundTopic,
    config::kPointCloudPublisherQueueSize);

  non_ground_publisher_ =
    this->create_publisher<sensor_msgs::msg::PointCloud2>(
    config::kNonGroundTopic,
    config::kPointCloudPublisherQueueSize);

  RCLCPP_INFO(get_logger(), "Drone detector started");
  RCLCPP_INFO(
    get_logger(),
    "Input topic: %s",
    config::kPointCloudTopic);
  RCLCPP_INFO(
    get_logger(),
    "RANSAC threshold=%.2f m, DBSCAN eps=%.2f m, minPts=%d",
    config::kRansacDistanceThresholdMeters,
    config::kDbscanEpsilonMeters,
    config::kDbscanMinPoints);
  RCLCPP_INFO(
    get_logger(),
    "RANSAC ground removal: %s",
    ransac_enabled_ ? "enabled" : "disabled");
}

void DroneDetectorNode::pointCloudCallback(
  const sensor_msgs::msg::PointCloud2::SharedPtr msg)
{
  using SteadyClock = std::chrono::steady_clock;
  const auto callback_start = SteadyClock::now();
  auto stage_start = callback_start;
  const double cloud_age_at_start_ms =
    (get_clock()->now() - rclcpp::Time(msg->header.stamp, RCL_ROS_TIME)).seconds() * 1000.0;

  auto raw_cloud = std::make_shared<PointCloud>();
  pcl::fromROSMsg(*msg, *raw_cloud);
  const double conversion_ms =
    std::chrono::duration<double, std::milli>(SteadyClock::now() - stage_start).count();

  stage_start = SteadyClock::now();
  const auto clean_cloud = preprocessor_.filterFinitePoints(raw_cloud);
  const double finite_filter_ms =
    std::chrono::duration<double, std::milli>(SteadyClock::now() - stage_start).count();

  if (clean_cloud->empty()) {
    RCLCPP_WARN_THROTTLE(
      get_logger(),
      *get_clock(),
      5000,
      "Received cloud contains no finite XYZ points");
    marker_visualizer_.clear(msg->header);
    return;
  }

  auto ground_cloud = std::make_shared<PointCloud>();
  ground_cloud->width = 0U;
  ground_cloud->height = 1U;
  ground_cloud->is_dense = true;
  PointCloudPtr detection_cloud = clean_cloud;

  stage_start = SteadyClock::now();
  if (ransac_enabled_) {
    try {
      const auto segmentation = ransac_segmenter_.segment(clean_cloud);
      ground_cloud = segmentation.ground_cloud;
      detection_cloud = segmentation.non_ground_cloud;
    } catch (const std::runtime_error & error) {
      RCLCPP_WARN_THROTTLE(
        get_logger(),
        *get_clock(),
        5000,
        "Ground segmentation failed: %s",
        error.what());
      marker_visualizer_.clear(msg->header);
      return;
    }
  }
  const double segmentation_ms =
    std::chrono::duration<double, std::milli>(SteadyClock::now() - stage_start).count();

  stage_start = SteadyClock::now();
  sensor_msgs::msg::PointCloud2 ground_msg;
  sensor_msgs::msg::PointCloud2 non_ground_msg;

  pcl::toROSMsg(*ground_cloud, ground_msg);
  pcl::toROSMsg(*detection_cloud, non_ground_msg);

  ground_msg.header = msg->header;
  non_ground_msg.header = msg->header;

  ground_publisher_->publish(ground_msg);
  non_ground_publisher_->publish(non_ground_msg);
  const double cloud_publish_ms =
    std::chrono::duration<double, std::milli>(SteadyClock::now() - stage_start).count();

  stage_start = SteadyClock::now();
  auto cluster_cloud = std::make_shared<PointCloud>();
  pcl::VoxelGrid<pcl::PointXYZ> voxel_filter;
  voxel_filter.setInputCloud(detection_cloud);
  voxel_filter.setLeafSize(
    config::kClusterVoxelLeafSizeMeters,
    config::kClusterVoxelLeafSizeMeters,
    config::kClusterVoxelLeafSizeMeters);
  voxel_filter.filter(*cluster_cloud);
  const double voxel_filter_ms =
    std::chrono::duration<double, std::milli>(SteadyClock::now() - stage_start).count();

  stage_start = SteadyClock::now();
  const auto clusters = dbscan_clusterer_.cluster(cluster_cloud);
  const double clustering_ms =
    std::chrono::duration<double, std::milli>(SteadyClock::now() - stage_start).count();

  stage_start = SteadyClock::now();
  marker_visualizer_.clear(msg->header);

  std::size_t candidate_count = 0;
  std::vector<geometry_msgs::msg::Point> candidate_detections;
  candidate_detections.reserve(clusters.size());

  for (std::size_t cluster_id = 0;
       cluster_id < clusters.size();
       ++cluster_id) {
    const auto & cluster = clusters[cluster_id];

    if (cluster.size() < config::kMinimumClusterPoints) {
      continue;
    }

    const auto features =
      feature_extractor_.compute(
      cluster_cloud,
      cluster,
      cluster_id);

    // The PTZ/LiDAR mounting hardware occupies this near-origin region. Reject
    // detections there based on position, not point count or box thickness:
    // voxel downsampling changes both of those properties.
    if (features.distance_m < 0.5F) {
      RCLCPP_DEBUG(
        get_logger(),
        "Skipping detection inside LiDAR mount exclusion radius: "
        "distance=%.3f m, points=%zu",
        features.distance_m,
        features.point_count);
      continue;
    }

    if (features.centroid_z < config::kMinimumCandidateCentroidZ) {
      continue;
    }

    ++candidate_count;

    geometry_msgs::msg::Point detection;
    detection.x = features.centroid_x;
    detection.y = features.centroid_y;
    detection.z = features.centroid_z;
    candidate_detections.push_back(detection);

    marker_visualizer_.publishBox(features, msg->header);
    logCandidate(features);
  }
  const double feature_marker_ms =
    std::chrono::duration<double, std::milli>(SteadyClock::now() - stage_start).count();

  stage_start = SteadyClock::now();
  const rclcpp::Time frame_time(msg->header.stamp, RCL_ROS_TIME);
  const auto tracks = tracker_.update(candidate_detections, frame_time);
  track_visualizer_.publish(tracks, msg->header);

  // Publish tracking data separately from RViz visualization markers. The
  // header preserves the point-cloud frame so consumers can transform targets
  // into the PTZ mounting frame using TF2.
  drone_detector::msg::TrackedDroneArray tracked_drones_msg;
  tracked_drones_msg.header = msg->header;
  tracked_drones_msg.tracks.reserve(tracks.size());

  for (const auto & track : tracks) {
    drone_detector::msg::TrackedDrone tracked;
    tracked.track_id = track.track_id;
    tracked.position = track.position;
    tracked.measurement = track.measurement;
    tracked.measurement_valid = track.measurement_valid;
    tracked.velocity.x = track.velocity_x;
    tracked.velocity.y = track.velocity_y;
    tracked.velocity.z = track.velocity_z;
    tracked.confirmed = track.confirmed;
    tracked.visible = track.visible;
    tracked.missed_frames = static_cast<std::uint32_t>(track.missed_frames);
    tracked_drones_msg.tracks.push_back(std::move(tracked));
  }
  tracked_drones_publisher_->publish(tracked_drones_msg);

  for (const auto & track : tracks) {
    if (!track.confirmed) {
      continue;
    }

    RCLCPP_INFO(
      get_logger(),
      "Track %d: position=(%.2f, %.2f, %.2f) velocity=(%.2f, %.2f, %.2f) "
      "visible=%s hits=%zu missed=%zu",
      track.track_id,
      track.position.x,
      track.position.y,
      track.position.z,
      track.velocity_x,
      track.velocity_y,
      track.velocity_z,
      track.visible ? "yes" : "no",
      track.hits,
      track.missed_frames);
  }

  const double tracking_publish_ms =
    std::chrono::duration<double, std::milli>(SteadyClock::now() - stage_start).count();
  const double total_ms =
    std::chrono::duration<double, std::milli>(SteadyClock::now() - callback_start).count();
  const double cloud_age_at_end_ms =
    (get_clock()->now() - rclcpp::Time(msg->header.stamp, RCL_ROS_TIME)).seconds() * 1000.0;

  RCLCPP_INFO_THROTTLE(
    get_logger(), *get_clock(), 2000,
    "Timing ms: cloud_age_start=%.1f cloud_age_end=%.1f convert=%.1f finite_filter=%.1f "
    "ransac=%.1f cloud_publish=%.1f voxel_filter=%.1f clustering=%.1f "
    "features_markers=%.1f "
    "tracking_publish=%.1f total=%.1f",
    cloud_age_at_start_ms,
    cloud_age_at_end_ms,
    conversion_ms,
    finite_filter_ms,
    segmentation_ms,
    cloud_publish_ms,
    voxel_filter_ms,
    clustering_ms,
    feature_marker_ms,
    tracking_publish_ms,
    total_ms);

  RCLCPP_INFO(
    get_logger(),
    "Cloud: raw=%zu finite=%zu ground=%zu non_ground=%zu "
    "clusters=%zu candidates=%zu",
    raw_cloud->points.size(),
    clean_cloud->points.size(),
    ground_cloud->points.size(),
    detection_cloud->points.size(),
    clusters.size(),
    candidate_count);
}

void DroneDetectorNode::logCandidate(
  const ClusterFeatures & features) const
{
  const auto & box = features.bounding_box;

  RCLCPP_INFO(
    get_logger(),
    "Candidate %zu: points=%zu center=(%.2f, %.2f, %.2f) "
    "box=(%.2f, %.2f, %.2f) distance=%.2f m",
    features.id,
    features.point_count,
    features.centroid_x,
    features.centroid_y,
    features.centroid_z,
    box.sizeX(),
    box.sizeY(),
    box.sizeZ(),
    features.distance_m);
}

}  // namespace drone_detector
