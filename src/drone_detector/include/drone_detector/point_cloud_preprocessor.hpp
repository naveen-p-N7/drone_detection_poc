#pragma once

#include "drone_detector/detection_types.hpp"

namespace drone_detector
{

/**
 * @brief Removes invalid points from a PCL XYZ point cloud.
 *
 * A LiDAR ray can contain NaN/Inf coordinates when it has no valid return.
 * Downstream geometry algorithms should receive only finite coordinates.
 */
class PointCloudPreprocessor
{
public:
  PointCloudPreprocessor() = default;

  /**
   * @brief Keep only points whose X, Y, and Z values are finite.
   * @param input Input point cloud.
   * @return A new dense cloud containing only finite points.
   */
  PointCloudPtr filterFinitePoints(const PointCloudConstPtr & input) const;
};

}  // namespace drone_detector
