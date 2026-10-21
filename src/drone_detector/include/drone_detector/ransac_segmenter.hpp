#pragma once

#include "drone_detector/detection_types.hpp"

namespace drone_detector
{

/**
 * @brief Fits the dominant ground plane using RANSAC and separates it.
 */
class RansacGroundSegmenter
{
public:
  /**
   * @param distance_threshold_m Maximum distance from the fitted plane for
   * a point to be treated as a ground inlier.
   */
  explicit RansacGroundSegmenter(float distance_threshold_m);

  /**
   * @brief Segment the dominant plane.
   * @param input Finite XYZ point cloud.
   * @return Ground and non-ground clouds plus model information.
   * @throws std::runtime_error when no plane can be found.
   */
  PlaneSegmentationResult segment(const PointCloudPtr & input) const;

private:
  float distance_threshold_m_;
};

}  // namespace drone_detector
