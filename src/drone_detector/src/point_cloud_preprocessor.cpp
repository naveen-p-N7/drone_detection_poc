#include "drone_detector/point_cloud_preprocessor.hpp"

#include <cmath>
#include <cstdint>

#include "drone_detector/detector_config.hpp"

namespace drone_detector
{

PointCloudPtr PointCloudPreprocessor::filterFinitePoints(
  const PointCloudConstPtr & input) const
{
  auto output = std::make_shared<PointCloud>();
  output->points.reserve(input->points.size());

  for (const auto & point : input->points) {
    if (!std::isfinite(point.x) ||
        !std::isfinite(point.y) ||
        !std::isfinite(point.z)) {
      continue;
    }

    output->points.push_back(point);
  }

  output->width = static_cast<std::uint32_t>(output->points.size());
  output->height = 1U;
  output->is_dense = true;

  return output;
}

PointCloudPtr PointCloudPreprocessor::removePtzSupportPole(
  const PointCloudConstPtr & input, const std::string & frame_id) const
{
  auto output = std::make_shared<PointCloud>();
  output->points.reserve(input->points.size());

  // These coordinates are calibrated in fixed_lidar. Never apply the mask in
  // an unrelated or transformed frame, where it could erase real detections.
  if (frame_id != "fixed_lidar" && frame_id != "/fixed_lidar") {
    output->points = input->points;
  } else {
    const float radius_squared =
      config::kPtzPoleExclusionRadius * config::kPtzPoleExclusionRadius;
    for (const auto & point : input->points) {
      const float dx = point.x - config::kPtzPoleCenterX;
      const float dy = point.y - config::kPtzPoleCenterY;
      const bool inside_support_radius = dx * dx + dy * dy <= radius_squared;
      const bool within_pole_height =
        point.z >= config::kPtzPoleMinZ && point.z <= config::kPtzPoleMaxZ;
      if (!inside_support_radius || !within_pole_height) {
        output->points.push_back(point);
      }
    }
  }

  output->width = static_cast<std::uint32_t>(output->points.size());
  output->height = 1U;
  output->is_dense = true;
  return output;
}

}  // namespace drone_detector
