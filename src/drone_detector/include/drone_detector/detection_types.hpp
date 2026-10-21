#pragma once

#include <cstddef>
#include <vector>

#include <pcl/ModelCoefficients.h>
#include <pcl/PointIndices.h>
#include <pcl/point_cloud.h>
#include <pcl/point_types.h>

namespace drone_detector
{

using PointCloud = pcl::PointCloud<pcl::PointXYZ>;
using PointCloudPtr = PointCloud::Ptr;
using PointCloudConstPtr = PointCloud::ConstPtr;
using ClusterIndices = std::vector<int>;
using ClusterList = std::vector<ClusterIndices>;

/**
 * @brief Axis-aligned 3D bounding box expressed in the point-cloud frame.
 */
struct BoundingBox
{
  float min_x{0.0F};
  float max_x{0.0F};
  float min_y{0.0F};
  float max_y{0.0F};
  float min_z{0.0F};
  float max_z{0.0F};

  /// @return Box size along X in metres.
  float sizeX() const { return max_x - min_x; }

  /// @return Box size along Y in metres.
  float sizeY() const { return max_y - min_y; }

  /// @return Box size along Z in metres.
  float sizeZ() const { return max_z - min_z; }
};

/**
 * @brief Geometric features calculated for a clustered object.
 */
struct ClusterFeatures
{
  std::size_t id{0};
  std::size_t point_count{0};

  float centroid_x{0.0F};
  float centroid_y{0.0F};
  float centroid_z{0.0F};

  BoundingBox bounding_box;

  /// @return Euclidean distance from the LiDAR origin to the centroid.
  float distance_m{0.0F};
};

/**
 * @brief Result produced by the RANSAC ground segmentation stage.
 */
struct PlaneSegmentationResult
{
  PointCloudPtr ground_cloud;
  PointCloudPtr non_ground_cloud;
  pcl::PointIndices::Ptr inliers;
  pcl::ModelCoefficients::Ptr coefficients;
};

}  // namespace drone_detector
