#include "drone_detector/dbscan_clusterer.hpp"

#include <queue>

namespace drone_detector
{

DbscanClusterer::DbscanClusterer(
  const float epsilon_m,
  const int min_points)
: epsilon_squared_(epsilon_m * epsilon_m),
  min_points_(min_points)
{
}

float DbscanClusterer::distanceSquared(
  const pcl::PointXYZ & first,
  const pcl::PointXYZ & second)
{
  const float dx = first.x - second.x;
  const float dy = first.y - second.y;
  const float dz = first.z - second.z;

  return dx * dx + dy * dy + dz * dz;
}

std::vector<int> DbscanClusterer::regionQuery(
  const PointCloudConstPtr & cloud,
  const std::size_t index) const
{
  std::vector<int> neighbors;
  neighbors.reserve(cloud->points.size());

  for (std::size_t j = 0; j < cloud->points.size(); ++j) {
    if (distanceSquared(cloud->points[index], cloud->points[j]) <=
        epsilon_squared_) {
      neighbors.push_back(static_cast<int>(j));
    }
  }

  return neighbors;
}

ClusterList DbscanClusterer::cluster(
  const PointCloudConstPtr & cloud) const
{
  const std::size_t point_count = cloud->points.size();

  Labels labels(point_count, -1);
  Visited visited(point_count, false);

  ClusterList clusters;
  int next_cluster_id = 0;

  for (std::size_t i = 0; i < point_count; ++i) {
    if (visited[i]) {
      continue;
    }

    visited[i] = true;
    const auto neighbors = regionQuery(cloud, i);

    if (static_cast<int>(neighbors.size()) < min_points_) {
      labels[i] = -2;  // Noise.
      continue;
    }

    labels[i] = next_cluster_id;

    std::queue<int> seeds;
    for (const int neighbor : neighbors) {
      if (neighbor != static_cast<int>(i)) {
        seeds.push(neighbor);
      }
    }

    while (!seeds.empty()) {
      const int current = seeds.front();
      seeds.pop();

      if (!visited[current]) {
        visited[current] = true;

        const auto current_neighbors =
          regionQuery(cloud, static_cast<std::size_t>(current));

        if (static_cast<int>(current_neighbors.size()) >= min_points_) {
          for (const int neighbor : current_neighbors) {
            seeds.push(neighbor);
          }
        }
      }

      if (labels[current] == -1 || labels[current] == -2) {
        labels[current] = next_cluster_id;
      }
    }

    ++next_cluster_id;
  }

  clusters.resize(static_cast<std::size_t>(next_cluster_id));

  for (std::size_t i = 0; i < point_count; ++i) {
    if (labels[i] >= 0) {
      clusters[static_cast<std::size_t>(labels[i])].push_back(
        static_cast<int>(i));
    }
  }

  return clusters;
}

}  // namespace drone_detector
