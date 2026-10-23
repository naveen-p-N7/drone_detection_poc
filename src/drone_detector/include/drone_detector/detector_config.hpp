#pragma once

#include <cstddef>

namespace drone_detector::config
{

// ROS topics.
inline constexpr char kPointCloudTopic[] = "/fixed_lidar/points/points";
//inline constexpr char kPointCloudTopic[] = "/simulated/drone_points"; // simulated points
// inline constexpr char kPointCloudTopic[] = "/radar_point"; // hari's ros bag
inline constexpr char kGroundTopic[] = "/pointcloud/ground";
inline constexpr char kNonGroundTopic[] = "/pointcloud/non_ground";
inline constexpr char kMarkerTopic[] = "/drone_detection/marker";
inline constexpr char kMeasurementTailTopic[] = "/drone_detection/measurement_tail";
inline constexpr char kUkfTailTopic[] = "/drone_detection/ukf_tail";
inline constexpr char kTrackIdTopic[] = "/drone_detection/track_id";
inline constexpr char kTrackedDronesTopic[] = "/drone_detection/tracks";

// ROS queue depths.
inline constexpr std::size_t kPointCloudPublisherQueueSize = 10;
inline constexpr std::size_t kMarkerPublisherQueueSize = 10;

// RANSAC.
inline constexpr float kRansacDistanceThresholdMeters = 0.15F;

// DBSCAN.
inline constexpr float kDbscanEpsilonMeters = 0.75F;
inline constexpr int kDbscanMinPoints = 4;

constexpr float kEuclideanClusterToleranceMeters = 0.75f;
constexpr int kEuclideanClusterMinSize = 4;
constexpr int kEuclideanClusterMaxSize = 100000;
// Reduce neighbor-search work while preserving useful geometry for drone boxes.
inline constexpr float kClusterVoxelLeafSizeMeters = 0.05F;

// Candidate filtering.
inline constexpr std::size_t kMinimumClusterPoints = 8;
// inline constexpr std::size_t kMinimumClusterPoints = 3; // hari's ros bag
inline constexpr float kMinimumCandidateCentroidZ = -2.5F;

// Static PTZ support pole and mounting base in the fixed_lidar sensor frame.
// The LiDAR is at world x=5.0 m and the PTZ pole is at world x=5.6 m.
inline constexpr float kPtzPoleCenterX = 0.6F;
inline constexpr float kPtzPoleCenterY = 0.0F;
inline constexpr float kPtzPoleExclusionRadius = 0.45F;
inline constexpr float kPtzPoleMinZ = -3.1F;
inline constexpr float kPtzPoleMaxZ = 0.8F;

// RViz marker.
inline constexpr float kMarkerLineWidthMeters = 0.015F;
inline constexpr float kMarkerRed = 1.0F;
inline constexpr float kMarkerGreen = 0.0F;
inline constexpr float kMarkerBlue = 0.0F;
inline constexpr float kMarkerAlpha = 1.0F;

}  // namespace drone_detector::config
