#include "drone_detector/point_cloud_preprocessor.hpp"

#include <cmath>
#include <cstdint>

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

}  // namespace drone_detector
