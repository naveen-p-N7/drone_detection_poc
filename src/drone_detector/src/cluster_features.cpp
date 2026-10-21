#include "drone_detector/cluster_features.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <stdexcept>

namespace drone_detector
{

ClusterFeatures ClusterFeatureExtractor::compute(
  const PointCloudConstPtr & cloud,
  const ClusterIndices & cluster,
  const std::size_t cluster_id) const
{
  if (cluster.empty()) {
    throw std::invalid_argument(
      "Cannot calculate features for an empty cluster");
  }

  BoundingBox box;
  box.min_x = std::numeric_limits<float>::max();
  box.max_x = std::numeric_limits<float>::lowest();
  box.min_y = std::numeric_limits<float>::max();
  box.max_y = std::numeric_limits<float>::lowest();
  box.min_z = std::numeric_limits<float>::max();
  box.max_z = std::numeric_limits<float>::lowest();

  double sum_x = 0.0;
  double sum_y = 0.0;
  double sum_z = 0.0;

  for (const int index : cluster) {
    const auto & point = cloud->points.at(static_cast<std::size_t>(index));

    box.min_x = std::min(box.min_x, point.x);
    box.max_x = std::max(box.max_x, point.x);
    box.min_y = std::min(box.min_y, point.y);
    box.max_y = std::max(box.max_y, point.y);
    box.min_z = std::min(box.min_z, point.z);
    box.max_z = std::max(box.max_z, point.z);

    sum_x += point.x;
    sum_y += point.y;
    sum_z += point.z;
  }

  const double count = static_cast<double>(cluster.size());

  ClusterFeatures features;
  features.id = cluster_id;
  features.point_count = cluster.size();
  features.centroid_x = static_cast<float>(sum_x / count);
  features.centroid_y = static_cast<float>(sum_y / count);
  features.centroid_z = static_cast<float>(sum_z / count);
  features.bounding_box = box;
  features.distance_m = std::sqrt(
    features.centroid_x * features.centroid_x +
    features.centroid_y * features.centroid_y +
    features.centroid_z * features.centroid_z);

  return features;
}

}  // namespace drone_detector
