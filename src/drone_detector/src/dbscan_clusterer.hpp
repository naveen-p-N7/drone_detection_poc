#pragma once

#include <vector>

#include "drone_detector/detection_types.hpp"

namespace drone_detector
{

/**
 * @brief Density-based clustering for 3D LiDAR points.
 *
 * This implementation intentionally uses a direct O(N^2) neighborhood search
 * because it keeps the algorithm easy to study. The public interface can be
 * preserved when the neighborhood search is later replaced by a KD-tree.
 */
class DbscanClusterer
{
public:
  /**
   * @param epsilon_m Maximum 3D neighbor distance in metres.
   * @param min_points Minimum neighbors required for a core point.
   */
  DbscanClusterer(float epsilon_m, int min_points);

  /**
   * @brief Cluster the cloud and return non-noise clusters.
   * @param cloud Input finite point cloud.
   * @return Clusters represented as indices into @p cloud.
   */
  ClusterList cluster(const PointCloudConstPtr & cloud) const;

private:
  using Labels = std::vector<int>;
  using Visited = std::vector<bool>;

  std::vector<int> regionQuery(
    const PointCloudConstPtr & cloud,
    std::size_t index) const;

  static float distanceSquared(
    const pcl::PointXYZ & first,
    const pcl::PointXYZ & second);

  float epsilon_squared_;
  int min_points_;
};

}  // namespace drone_detector
