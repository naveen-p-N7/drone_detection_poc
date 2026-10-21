#include "drone_detector/drone_detector.hpp"

#include <iostream>
#include <memory>
#include <string_view>
#include <vector>

int main(int argc, char * argv[])
{
  // Keep this application-specific option out of rclcpp's argument parser.
  bool ransac_enabled = true;
  std::vector<char *> ros_arguments;
  ros_arguments.reserve(static_cast<std::size_t>(argc));
  ros_arguments.push_back(argv[0]);

  for (int index = 1; index < argc; ++index) {
    const std::string_view argument(argv[index]);
    if (argument != "--ransac") {
      ros_arguments.push_back(argv[index]);
      continue;
    }

    if (index + 1 >= argc) {
      std::cerr << "Missing value for --ransac; use 0 or 1.\n";
      return 1;
    }

    const std::string_view value(argv[++index]);
    if (value == "0") {
      ransac_enabled = false;
    } else if (value == "1") {
      ransac_enabled = true;
    } else {
      std::cerr << "Invalid value for --ransac: " << value
                << "; use 0 or 1.\n";
      return 1;
    }
  }

  int ros_argc = static_cast<int>(ros_arguments.size());
  rclcpp::init(ros_argc, ros_arguments.data());

  rclcpp::spin(
    std::make_shared<drone_detector::DroneDetectorNode>(ransac_enabled));

  rclcpp::shutdown();
  return 0;
}
