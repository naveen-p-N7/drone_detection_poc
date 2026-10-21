# Drone Detection POC

A ROS 2 + Gazebo + ArduPilot SITL proof-of-concept for detecting simulated drones using a fixed ground LiDAR.

## Prerequisites

- Ubuntu 22.04
- ROS 2 Jazzy
- Gazebo Sim 8
- ArduPilot SITL
- Python 3
- `pymavlink`

Make sure ArduPilot is available, for example:

```bash
export ARDUPILOT_DIR=$HOME/ardupilot
```

## 1. Build

```bash
cd ~/drone_detection_poc

source /opt/ros/jazzy/setup.bash

colcon build --packages-select drone_detector

source install/setup.bash
```

## 2. Start Gazebo

Open **Terminal 1**:

```bash
cd ~/drone_detection_poc
./scripts/simulation/start_two_drone_gazebo.sh
```

Leave Gazebo running.

## 3. Start the Drones

Open **Terminal 2**:

```bash
cd ~/drone_detection_poc
./scripts/trajectory/multi_drone_controller.py
```

This starts and manages both ArduPilot SITL instances and runs the drone trajectories.

You do **not** need to start `start_drone1.sh` or `start_drone2.sh` separately.

## 4. Start ROS 2 Detection

Open **Terminal 3**:

```bash
source /opt/ros/jazzy/setup.bash

cd ~/drone_detection_poc
source install/setup.bash

ros2 launch drone_detector drone_detection_sim.launch.py
```

This starts the ROS 2 detection stack and RViz2.

## 5. Stop the POC

Press `Ctrl+C` in each terminal.

- Controller: stops both SITL instances.
- ROS 2: stops the detection stack.
- Gazebo: stops the simulation.

## Quick Start

After the initial build, the normal startup is simply:

```text
Terminal 1 → start_two_drone_gazebo.sh
Terminal 2 → multi_drone_controller.py
Terminal 3 → ros2 launch drone_detector drone_detection_sim.launch.py
```

## Troubleshooting

### ArduPilot not found

```bash
export ARDUPILOT_DIR=$HOME/ardupilot
```

### Rebuild after changes

```bash
cd ~/drone_detection_poc
source /opt/ros/jazzy/setup.bash
colcon build --packages-select drone_detector
source install/setup.bash
```
