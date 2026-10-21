# Tracked-drone output topic

The detector now publishes a machine-readable `drone_detector/msg/TrackedDroneArray`
on `/drone_detection/tracks`, separate from the RViz marker topics.

Each message contains the point-cloud header (including frame ID and timestamp)
and a list of tracks with track ID, UKF estimate, last LiDAR measurement,
velocity, confirmation/visibility state, and missed-frame count.

Inspect it with:

```bash
ros2 topic list | grep drone_detection
ros2 topic info /drone_detection/tracks
ros2 topic echo /drone_detection/tracks
```

The `position` is the UKF estimate in the message's `header.frame_id`; the
controller should transform it into the PTZ base frame with TF2 before deriving
pan/tilt angles. `visible=false` means the tracker is currently predicting the
track because a measurement was missed.

Build with ROS 2 Jazzy after installing normal dependencies:

```bash
source /opt/ros/jazzy/setup.bash
cd ~/drone_detection_poc
colcon build --packages-select drone_detector --symlink-install
source install/setup.bash
```
