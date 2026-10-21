#include "drone_detector/ukf_3d_cv.hpp"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace drone_detector
{

Ukf3dCv::Ukf3dCv(
  const double alpha,
  const double beta,
  const double kappa,
  const double position_process_noise,
  const double velocity_process_noise,
  const double measurement_noise)
: alpha_(alpha),
  beta_(beta),
  kappa_(kappa),
  lambda_(alpha * alpha * (kStateDimension + kappa) - kStateDimension),
  process_noise_(Covariance::Zero()),
  measurement_noise_(MeasurementCovariance::Identity() * measurement_noise)
{
  if (alpha_ <= 0.0) {
    throw std::invalid_argument("UKF alpha must be > 0");
  }

  const double scale = kStateDimension + lambda_;
  if (scale <= 0.0) {
    throw std::invalid_argument("UKF n + lambda must be > 0");
  }

  weights_mean_.setConstant(1.0 / (2.0 * scale));
  weights_covariance_.setConstant(1.0 / (2.0 * scale));
  weights_mean_(0) = lambda_ / scale;
  weights_covariance_(0) = lambda_ / scale + (1.0 - alpha_ * alpha_ + beta_);

  process_noise_.diagonal().head<3>().setConstant(position_process_noise);
  process_noise_.diagonal().tail<3>().setConstant(velocity_process_noise);
}

void Ukf3dCv::initialize(const Measurement & position)
{
  state_.setZero();
  state_.head<3>() = position;
  covariance_.setIdentity();
  covariance_.diagonal().head<3>().setConstant(0.25);
  covariance_.diagonal().tail<3>().setConstant(1.0);
  innovation_.setZero();
  predicted_measurement_ = position;
  kalman_gain_.setZero();
  predicted_sigma_points_.setZero();
  initialized_ = true;
  prediction_ready_ = false;
}

Ukf3dCv::SigmaPoints Ukf3dCv::createSigmaPoints() const
{
  const double scale = kStateDimension + lambda_;
  Covariance scaled = scale * covariance_;
  scaled = 0.5 * (scaled + scaled.transpose());

  Eigen::LLT<Covariance> llt(scaled);
  if (llt.info() != Eigen::Success) {
    Covariance regularized = scaled;
    regularized.diagonal().array() += 1e-9;
    llt.compute(regularized);
    if (llt.info() != Eigen::Success) {
      throw std::runtime_error("UKF covariance is not positive definite");
    }
  }

  const Eigen::Matrix<double, 6, 6> root = llt.matrixL();
  SigmaPoints sigma;
  sigma.row(0) = state_.transpose();
  for (int i = 0; i < kStateDimension; ++i) {
    sigma.row(i + 1) = (state_ + root.col(i)).transpose();
    sigma.row(i + 1 + kStateDimension) = (state_ - root.col(i)).transpose();
  }
  return sigma;
}

Ukf3dCv::State Ukf3dCv::processModel(const State & state, const double dt) const
{
  State result = state;
  result.head<3>() += state.tail<3>() * dt;
  return result;
}

Ukf3dCv::Measurement Ukf3dCv::measurementModel(const State & state) const
{
  return state.head<3>();
}

void Ukf3dCv::predict(const double dt)
{
  if (!initialized_) {
    return;
  }

  const double safe_dt = std::max(0.0, std::min(dt, 1.0));
  const SigmaPoints sigma = createSigmaPoints();

  for (int i = 0; i < kSigmaPointCount; ++i) {
    predicted_sigma_points_.row(i) = processModel(sigma.row(i).transpose(), safe_dt).transpose();
  }

  state_.setZero();
  for (int i = 0; i < kSigmaPointCount; ++i) {
    state_ += weights_mean_(i) * predicted_sigma_points_.row(i).transpose();
  }

  covariance_.setZero();
  for (int i = 0; i < kSigmaPointCount; ++i) {
    const State deviation = predicted_sigma_points_.row(i).transpose() - state_;
    covariance_ += weights_covariance_(i) * (deviation * deviation.transpose());
  }
  covariance_ += process_noise_;
  covariance_ = 0.5 * (covariance_ + covariance_.transpose());
  prediction_ready_ = true;
}

void Ukf3dCv::update(const Measurement & position)
{
  if (!initialized_) {
    initialize(position);
    return;
  }

  if (!prediction_ready_) {
    predicted_sigma_points_ = createSigmaPoints();
  }

  Eigen::Matrix<double, kSigmaPointCount, 3> measurement_sigma;
  for (int i = 0; i < kSigmaPointCount; ++i) {
    measurement_sigma.row(i) = measurementModel(predicted_sigma_points_.row(i).transpose()).transpose();
  }

  predicted_measurement_.setZero();
  for (int i = 0; i < kSigmaPointCount; ++i) {
    predicted_measurement_ += weights_mean_(i) * measurement_sigma.row(i).transpose();
  }

  MeasurementCovariance innovation_covariance = measurement_noise_;
  Eigen::Matrix<double, 6, 3> cross_covariance = Eigen::Matrix<double, 6, 3>::Zero();

  for (int i = 0; i < kSigmaPointCount; ++i) {
    const Measurement z_deviation = measurement_sigma.row(i).transpose() - predicted_measurement_;
    const State x_deviation = predicted_sigma_points_.row(i).transpose() - state_;
    innovation_covariance += weights_covariance_(i) * (z_deviation * z_deviation.transpose());
    cross_covariance += weights_covariance_(i) * (x_deviation * z_deviation.transpose());
  }

  kalman_gain_ = cross_covariance * innovation_covariance.ldlt().solve(MeasurementCovariance::Identity());
  innovation_ = position - predicted_measurement_;
  state_ += kalman_gain_ * innovation_;
  covariance_ -= kalman_gain_ * innovation_covariance * kalman_gain_.transpose();
  covariance_ = 0.5 * (covariance_ + covariance_.transpose());
  for (int i = 0; i < kStateDimension; ++i) {
    covariance_(i, i) = std::max(covariance_(i, i), 1e-12);
  }
  prediction_ready_ = false;
}

}  // namespace drone_detector
