#pragma once

#include <vector>

#include <pcl/point_cloud.h>
#include <pcl/point_types.h>

#include "drone_detector/detection_types.hpp"

namespace drone_detector
{

/**
 * @brief Performs Euclidean clustering on a point cloud.
 *
 * Uses PCL's EuclideanClusterExtraction with a KdTree
 * for efficient spatial neighbor searches.
 */
class EuclideanClusterer
{
public:
  using PointT = pcl::PointXYZ;
  using PointCloud = pcl::PointCloud<PointT>;
  using PointCloudPtr = PointCloud::Ptr;

  /**
   * @brief Construct a Euclidean clusterer.
   *
   * @param cluster_tolerance Maximum Euclidean distance between
   *                          connected points in the same cluster.
   * @param min_cluster_size Minimum number of points required.
   * @param max_cluster_size Maximum number of points allowed.
   */
  EuclideanClusterer(
    double cluster_tolerance,
    int min_cluster_size,
    int max_cluster_size);

  /**
   * @brief Extract clusters from the input cloud.
   *
   * @param cloud Input point cloud.
   * @return Vector containing point indices for each detected cluster.
   */
  std::vector<std::vector<int>> cluster(
    const PointCloudPtr & cloud) const;

private:
  double cluster_tolerance_;
  int min_cluster_size_;
  int max_cluster_size_;
};
}