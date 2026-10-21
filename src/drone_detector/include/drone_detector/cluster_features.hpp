#pragma once

#include <cstddef>

#include "drone_detector/detection_types.hpp"

namespace drone_detector
{

/**
 * @brief Calculates geometric features for one point-cloud cluster.
 */
class ClusterFeatureExtractor
{
public:
  /**
   * @brief Compute centroid, axis-aligned box, and LiDAR distance.
   * @param cloud Point cloud containing the cluster.
   * @param cluster Indices into @p cloud.
   * @param cluster_id DBSCAN cluster identifier.
   * @return Calculated cluster features.
   */
  ClusterFeatures compute(
    const PointCloudConstPtr & cloud,
    const ClusterIndices & cluster,
    std::size_t cluster_id) const;
};

}  // namespace drone_detector
