#include "drone_detector/drone_tracker.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <stdexcept>

namespace drone_detector
{

DroneTracker::TrackState::TrackState(
  const int id,
  const geometry_msgs::msg::Point & initial_position)
: track_id(id),
  filter(),
  last_timestamp(0, 0, RCL_ROS_TIME),
  last_measurement(initial_position)
{
  filter.initialize(DroneTracker::toMeasurement(initial_position));
}

DroneTracker::DroneTracker(
  const double association_gate_m,
  const double reacquisition_gate_m,
  const std::size_t confirmation_hits,
  const double history_seconds)
: association_gate_m_(association_gate_m),
  reacquisition_gate_m_(reacquisition_gate_m),
  confirmation_hits_(confirmation_hits),
  history_seconds_(history_seconds)
{
}

Ukf3dCv::Measurement DroneTracker::toMeasurement(const geometry_msgs::msg::Point & point)
{
  Ukf3dCv::Measurement result;
  result << point.x, point.y, point.z;
  return result;
}

geometry_msgs::msg::Point DroneTracker::toPoint(const Ukf3dCv::State & state)
{
  geometry_msgs::msg::Point point;
  point.x = state(0);
  point.y = state(1);
  point.z = state(2);
  return point;
}

double DroneTracker::distance(
  const geometry_msgs::msg::Point & a,
  const geometry_msgs::msg::Point & b)
{
  const double dx = a.x - b.x;
  const double dy = a.y - b.y;
  const double dz = a.z - b.z;
  return std::sqrt(dx * dx + dy * dy + dz * dz);
}

double DroneTracker::distanceToHistory(
  const geometry_msgs::msg::Point & point,
  const std::deque<TimedTrackPoint> & history)
{
  double best = std::numeric_limits<double>::max();
  for (const auto & sample : history) {
    best = std::min(best, distance(point, sample.point));
  }
  return best;
}

void DroneTracker::pruneHistory(TrackState & track, const rclcpp::Time & now)
{
  const rclcpp::Duration keep = rclcpp::Duration::from_seconds(history_seconds_);
  while (!track.measurement_history.empty() &&
    now - track.measurement_history.front().stamp > keep)
  {
    track.measurement_history.pop_front();
  }
  while (!track.estimate_history.empty() &&
    now - track.estimate_history.front().stamp > keep)
  {
    track.estimate_history.pop_front();
  }
}

std::vector<DroneTrack> DroneTracker::update(
  const std::vector<geometry_msgs::msg::Point> & detections,
  const rclcpp::Time & timestamp)
{
  // First frame: establish the two permanent logical IDs by X position.
  if (!initialized_) {
    if (detections.empty()) {
      return {};
    }

    std::vector<geometry_msgs::msg::Point> ordered = detections;
    std::sort(ordered.begin(), ordered.end(),
      [](const auto & a, const auto & b) { return a.x < b.x; });

    const std::size_t count = std::min<std::size_t>(kDroneCount, ordered.size());
    for (std::size_t i = 0; i < count; ++i) {
      tracks_.emplace_back(static_cast<int>(i + 1), ordered[i]);
      auto & track = tracks_.back();
      track.last_timestamp = timestamp;
      track.confirmed = confirmation_hits_ <= 1;
      track.measurement_history.push_back({timestamp, ordered[i]});
      track.estimate_history.push_back({timestamp, ordered[i]});
    }
    initialized_ = true;
    return makeOutput();
  }

  // Predict every persistent track before association.
  for (auto & track : tracks_) {
    double dt = (timestamp - track.last_timestamp).seconds();
    if (dt < 0.0) {
      dt = 0.0;
    }
    track.filter.predict(dt);
    track.last_timestamp = timestamp;
  }

  std::array<int, kDroneCount> assignment{};
  assignment.fill(-1);
  // With only two drones, explicitly evaluate both possible assignments. This
  // prevents candidate ordering from swapping the logical IDs.
  if (tracks_.size() == kDroneCount && detections.size() >= kDroneCount) {
    const auto associationCost = [&](const TrackState & track, const auto & detection) {
      const double predicted = distance(detection, toPoint(track.filter.state()));
      if (track.missed_frames == 0 || track.estimate_history.empty()) {
        return predicted;
      }
      return std::min({
        predicted,
        distanceToHistory(detection, track.estimate_history),
        distance(detection, track.last_measurement)});
    };
    const double d00 = associationCost(tracks_[0], detections[0]);
    const double d01 = associationCost(tracks_[0], detections[1]);
    const double d10 = associationCost(tracks_[1], detections[0]);
    const double d11 = associationCost(tracks_[1], detections[1]);
    const double cost_direct = d00 + d11;
    const double cost_swapped = d01 + d10;
    if (cost_direct <= cost_swapped) {
      assignment[0] = 0;
      assignment[1] = 1;
    } else {
      assignment[0] = 1;
      assignment[1] = 0;
    }
  } else {
    // Fallback for partial detection sets: assign each available detection to
    // the currently closest track, without allowing one detection to feed both.
    for (std::size_t d = 0; d < detections.size(); ++d) {
      double best = std::numeric_limits<double>::max();
      int best_track = -1;
      for (std::size_t t = 0; t < tracks_.size(); ++t) {
        if (assignment[t] >= 0) {
          continue;
        }
        const double d_now = distance(detections[d], toPoint(tracks_[t].filter.state()));
        if (d_now < best) {
          best = d_now;
          best_track = static_cast<int>(t);
        }
      }
      if (best_track >= 0) {
        assignment[static_cast<std::size_t>(best_track)] = static_cast<int>(d);
      }
    }
  }

  for (std::size_t t = 0; t < tracks_.size(); ++t) {
    auto & track = tracks_[t];
    const int detection_index = assignment[t];
    bool accepted = false;

    if (detection_index >= 0) {
      const auto & detection = detections[static_cast<std::size_t>(detection_index)];
      const double predicted_distance = distance(detection, toPoint(track.filter.state()));
      const double history_distance = distanceToHistory(detection, track.estimate_history);
      const double last_measurement_distance = distance(detection, track.last_measurement);
      const double reacquisition_distance =
        std::min({predicted_distance, history_distance, last_measurement_distance});
      const bool normal_match = predicted_distance <= association_gate_m_;
      const bool reacquired =
        track.missed_frames > 0 && reacquisition_distance <= reacquisition_gate_m_;
      accepted = normal_match || reacquired;

      if (accepted) {
        track.filter.update(toMeasurement(detection));
        track.last_measurement = detection;
        track.has_measurement = true;
        track.hits++;
        track.missed_frames = 0;
        if (track.hits >= confirmation_hits_) {
          track.confirmed = true;
        }
        track.measurement_history.push_back({timestamp, detection});
      }
    }

    if (!accepted) {
      track.missed_frames++;
      track.has_measurement = false;
    }

    track.estimate_history.push_back({timestamp, toPoint(track.filter.state())});
    pruneHistory(track, timestamp);
  }

  // If a candidate was not consumed by the fixed two-track assignment, do not
  // create a third identity: this demo intentionally exposes only IDs 1 and 2.
  return makeOutput();
}

std::vector<DroneTrack> DroneTracker::makeOutput() const
{
  std::vector<DroneTrack> output;
  output.reserve(tracks_.size());

  for (const auto & track : tracks_) {
    DroneTrack result;
    result.track_id = track.track_id;
    result.position = toPoint(track.filter.state());
    result.measurement = track.last_measurement;
    result.measurement_valid = track.has_measurement;
    result.velocity_x = track.filter.state()(3);
    result.velocity_y = track.filter.state()(4);
    result.velocity_z = track.filter.state()(5);
    result.confirmed = track.confirmed;
    result.visible = track.missed_frames == 0;
    result.hits = track.hits;
    result.missed_frames = track.missed_frames;
    result.measurement_history.assign(track.measurement_history.begin(), track.measurement_history.end());
    result.estimate_history.assign(track.estimate_history.begin(), track.estimate_history.end());
    output.push_back(std::move(result));
  }
  return output;
}

void DroneTracker::reset()
{
  tracks_.clear();
  initialized_ = false;
}

}  // namespace drone_detector
