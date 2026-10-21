#include "drone_detector/ransac_segmenter.hpp"

#include <memory>
#include <stdexcept>

#include <pcl/filters/extract_indices.h>
#include <pcl/segmentation/sac_segmentation.h>

namespace drone_detector
{

RansacGroundSegmenter::RansacGroundSegmenter(
  const float distance_threshold_m)
: distance_threshold_m_(distance_threshold_m)
{
}

PlaneSegmentationResult RansacGroundSegmenter::segment(
  const PointCloudPtr & input) const
{
  auto inliers = std::make_shared<pcl::PointIndices>();
  auto coefficients = std::make_shared<pcl::ModelCoefficients>();

  pcl::SACSegmentation<pcl::PointXYZ> segmentation;
  segmentation.setOptimizeCoefficients(true);
  segmentation.setModelType(pcl::SACMODEL_PLANE);
  segmentation.setMethodType(pcl::SAC_RANSAC);
  segmentation.setDistanceThreshold(distance_threshold_m_);
  segmentation.setInputCloud(input);
  segmentation.segment(*inliers, *coefficients);

  if (inliers->indices.empty()) {
    throw std::runtime_error("RANSAC could not find a ground plane");
  }

  auto ground_cloud = std::make_shared<PointCloud>();
  auto non_ground_cloud = std::make_shared<PointCloud>();

  pcl::ExtractIndices<pcl::PointXYZ> extractor;
  extractor.setInputCloud(input);
  extractor.setIndices(inliers);

  extractor.setNegative(false);
  extractor.filter(*ground_cloud);

  extractor.setNegative(true);
  extractor.filter(*non_ground_cloud);

  return {
    ground_cloud,
    non_ground_cloud,
    inliers,
    coefficients
  };
}

}  // namespace drone_detector
