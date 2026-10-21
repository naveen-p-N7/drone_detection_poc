cmake_minimum_required(VERSION 3.8)

project(drone_detector)

# Point-cloud processing is CPU-intensive; use optimized code for normal
# colcon builds unless a build type was explicitly selected by the caller.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 17)
endif()

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rosidl_default_generators REQUIRED)
find_package(Eigen3 REQUIRED)

find_package(rclcpp REQUIRED)
find_package(tf2 REQUIRED)
find_package(tf2_ros REQUIRED)
find_package(tf2_geometry_msgs REQUIRED)
find_package(sensor_msgs REQUIRED)
find_package(std_msgs REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(visualization_msgs REQUIRED)
find_package(pcl_conversions REQUIRED)


rosidl_generate_interfaces(${PROJECT_NAME}
  "msg/TrackedDrone.msg"
  "msg/TrackedDroneArray.msg"
  DEPENDENCIES std_msgs geometry_msgs
)

find_package(PCL REQUIRED COMPONENTS
  common
  filters
  sample_consensus
  segmentation
)

add_executable(drone_detector_node
  src/main.cpp
  src/drone_detector.cpp
  src/point_cloud_preprocessor.cpp
  src/ransac_segmenter.cpp
  src/euclidean_clusterer.cpp
  src/dbscan_clusterer.cpp
  src/cluster_features.cpp
  src/marker_visualizer.cpp
  src/drone_tracker.cpp
  src/ukf_3d_cv.cpp
  src/track_visualizer.cpp
)

target_include_directories(drone_detector_node PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${PCL_INCLUDE_DIRS}
  ${EIGEN3_INCLUDE_DIRS}
)

ament_target_dependencies(drone_detector_node
  rclcpp
  sensor_msgs
  std_msgs
  geometry_msgs
  visualization_msgs
  pcl_conversions
)

rosidl_get_typesupport_target(cpp_typesupport_target ${PROJECT_NAME} "rosidl_typesupport_cpp")

target_link_libraries(drone_detector_node
  ${PCL_LIBRARIES}
  Eigen3::Eigen
  "${cpp_typesupport_target}"
)

add_dependencies(drone_detector_node ${PROJECT_NAME}__rosidl_generator_cpp)

add_executable(ptz_controller_node
  src/ptz_controller.cpp
)

target_include_directories(ptz_controller_node PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)

ament_target_dependencies(ptz_controller_node
  rclcpp
  sensor_msgs
  geometry_msgs
  tf2
  tf2_ros
  tf2_geometry_msgs
)

target_link_libraries(ptz_controller_node
  "${cpp_typesupport_target}"
)

add_dependencies(ptz_controller_node ${PROJECT_NAME}__rosidl_generator_cpp)

add_definitions(${PCL_DEFINITIONS})

install(
  TARGETS drone_detector_node ptz_controller_node
  DESTINATION lib/${PROJECT_NAME}
)

install(
  PROGRAMS
    ${CMAKE_CURRENT_SOURCE_DIR}/scripts/ptz_joint_state_bridge.py
  DESTINATION
    lib/${PROJECT_NAME}
)

install(
  DIRECTORY
    ${CMAKE_CURRENT_SOURCE_DIR}/launch/
  DESTINATION
    share/${PROJECT_NAME}/launch
)

install(
  DIRECTORY
    ${CMAKE_CURRENT_SOURCE_DIR}/robot_description/
  DESTINATION
    share/${PROJECT_NAME}/robot_description
)

ament_package()
