#pragma once

#include <cstddef>
#include <deque>
#include <vector>

#include <geometry_msgs/msg/point.hpp>
#include <rclcpp/rclcpp.hpp>

#include "drone_detector/ukf_3d_cv.hpp"

namespace drone_detector
{

struct TimedTrackPoint
{
  rclcpp::Time stamp;
  geometry_msgs::msg::Point point;
};

struct DroneTrack
{
  int track_id{0};
  geometry_msgs::msg::Point position;          // UKF estimate
  geometry_msgs::msg::Point measurement;       // latest LiDAR measurement
  bool measurement_valid{false};
  double velocity_x{0.0};
  double velocity_y{0.0};
  double velocity_z{0.0};
  bool confirmed{false};
  bool visible{false};
  std::size_t hits{0};
  std::size_t missed_frames{0};
  std::vector<TimedTrackPoint> measurement_history;
  std::vector<TimedTrackPoint> estimate_history;
};

/**
 * @brief Two-drone demo tracker with persistent logical IDs 1 and 2.
 *
 * The UKF remains independent from association. For the demo, the two logical
 * tracks are never renumbered. During normal operation detections are assigned
 * to the two predicted tracks. When a drone is temporarily missing, its track
 * remains alive and its estimated tail continues. Reacquisition also considers
 * the stored recent path so a returning drone can recover its original ID.
 */
class DroneTracker
{
public:
  static constexpr int kDroneCount = 2;

  DroneTracker(
    double association_gate_m = 2.0,
    double reacquisition_gate_m = 20.0,
    std::size_t confirmation_hits = 2,
    double history_seconds = 3.0);

  std::vector<DroneTrack> update(
    const std::vector<geometry_msgs::msg::Point> & detections,
    const rclcpp::Time & timestamp);

  void reset();

private:
  struct TrackState
  {
    explicit TrackState(int id, const geometry_msgs::msg::Point & initial_position);

    int track_id;
    Ukf3dCv filter;
    rclcpp::Time last_timestamp;
    geometry_msgs::msg::Point last_measurement;
    bool has_measurement{true};
    std::size_t hits{1};
    std::size_t missed_frames{0};
    bool confirmed{false};
    std::deque<TimedTrackPoint> measurement_history;
    std::deque<TimedTrackPoint> estimate_history;
  };

  static Ukf3dCv::Measurement toMeasurement(const geometry_msgs::msg::Point & point);
  static geometry_msgs::msg::Point toPoint(const Ukf3dCv::State & state);
  static double distance(const geometry_msgs::msg::Point & a, const geometry_msgs::msg::Point & b);
  static double distanceToHistory(
    const geometry_msgs::msg::Point & point,
    const std::deque<TimedTrackPoint> & history);

  void pruneHistory(TrackState & track, const rclcpp::Time & now);
  std::vector<DroneTrack> makeOutput() const;

  double association_gate_m_;
  double reacquisition_gate_m_;
  std::size_t confirmation_hits_;
  double history_seconds_;
  std::vector<TrackState> tracks_;
  bool initialized_{false};
};

}  // namespace drone_detector
