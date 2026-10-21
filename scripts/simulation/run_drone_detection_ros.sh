cd ~/drone_detection_poc

source /opt/ros/jazzy/setup.bash

colcon build --symlink-install

source ~/drone_detection_poc/install/setup.bash

ros2 run drone_detector drone_detector_node
