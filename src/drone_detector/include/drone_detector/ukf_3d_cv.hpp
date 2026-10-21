#pragma once

#include <Eigen/Dense>

namespace drone_detector
{

class Ukf3dCv
{
public:
  using State = Eigen::Matrix<double, 6, 1>;
  using Covariance = Eigen::Matrix<double, 6, 6>;
  using Measurement = Eigen::Matrix<double, 3, 1>;
  using MeasurementCovariance = Eigen::Matrix<double, 3, 3>;

  static constexpr int kStateDimension = 6;
  static constexpr int kSigmaPointCount = 13;

  explicit Ukf3dCv(
    double alpha = 0.5,
    double beta = 2.0,
    double kappa = 0.0,
    double position_process_noise = 0.01,
    double velocity_process_noise = 0.10,
    double measurement_noise = 0.10);

  void initialize(const Measurement & position);
  void predict(double dt);
  void update(const Measurement & position);

  bool isInitialized() const { return initialized_; }
  const State & state() const { return state_; }
  const Covariance & covariance() const { return covariance_; }
  const Measurement & innovation() const { return innovation_; }
  const Measurement & predictedMeasurement() const { return predicted_measurement_; }
  const Eigen::Matrix<double, 6, 3> & kalmanGain() const { return kalman_gain_; }

private:
  using SigmaPoints = Eigen::Matrix<double, kSigmaPointCount, kStateDimension>;

  SigmaPoints createSigmaPoints() const;
  State processModel(const State & state, double dt) const;
  Measurement measurementModel(const State & state) const;

  double alpha_;
  double beta_;
  double kappa_;
  double lambda_;
  Eigen::Matrix<double, kSigmaPointCount, 1> weights_mean_;
  Eigen::Matrix<double, kSigmaPointCount, 1> weights_covariance_;
  Covariance process_noise_;
  MeasurementCovariance measurement_noise_;

  State state_ = State::Zero();
  Covariance covariance_ = Covariance::Identity();
  Measurement innovation_ = Measurement::Zero();
  Measurement predicted_measurement_ = Measurement::Zero();
  Eigen::Matrix<double, 6, 3> kalman_gain_ = Eigen::Matrix<double, 6, 3>::Zero();
  SigmaPoints predicted_sigma_points_ = SigmaPoints::Zero();
  bool initialized_{false};
  bool prediction_ready_{false};
};

}  // namespace drone_detector
