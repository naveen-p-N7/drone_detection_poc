#include "drone_detector/euclidean_clusterer.hpp"

#include <pcl/search/kdtree.h>
#include <pcl/segmentation/extract_clusters.h>

namespace drone_detector
{

EuclideanClusterer::EuclideanClusterer(
  double cluster_tolerance,
  int min_cluster_size,
  int max_cluster_size)
: cluster_tolerance_(cluster_tolerance),
  min_cluster_size_(min_cluster_size),
  max_cluster_size_(max_cluster_size)
{
}

std::vector<std::vector<int>> EuclideanClusterer::cluster(
  const PointCloudPtr & cloud) const
{
  std::vector<std::vector<int>> clusters;

  if (!cloud || cloud->empty())
  {
    return clusters;
  }

  // Build the spatial search structure used by PCL.
  pcl::search::KdTree<PointT>::Ptr tree(
    new pcl::search::KdTree<PointT>);

  tree->setInputCloud(cloud);

  // Configure PCL's Euclidean cluster extraction.
  pcl::EuclideanClusterExtraction<PointT> extractor;

  extractor.setClusterTolerance(cluster_tolerance_);
  extractor.setMinClusterSize(min_cluster_size_);
  extractor.setMaxClusterSize(max_cluster_size_);
  extractor.setSearchMethod(tree);
  extractor.setInputCloud(cloud);

  std::vector<pcl::PointIndices> cluster_indices;

  extractor.extract(cluster_indices);

  // Convert PCL's PointIndices representation into
  // the detector's generic vector-of-indices representation.
  clusters.reserve(cluster_indices.size());

  for (const auto & cluster : cluster_indices)
  {
    clusters.push_back(cluster.indices);
  }

  return clusters;
}

}