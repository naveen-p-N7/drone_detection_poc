# Drone Detection POC — Simulation Scripts

This directory contains the scripts used to start and connect the
**Gazebo + ArduPilot + ROS 2** simulation for the Drone Detection POC.

The scripts are designed to be run **one by one in separate terminals**.
This makes it easier to see the output of each component and troubleshoot
individual processes.

## Files

| File | Purpose |
|---|---|
| `start_gazebo.sh` | Starts the single-drone Gazebo world |
| `start_two_drone_gazebo.sh` | Starts the two-drone Gazebo world |
| `start_drone1.sh` | Starts ArduCopter SITL instance 0 |
| `start_drone2.sh` | Starts ArduCopter SITL instance 1 |
| `bridge_gazebo_clock.sh` | Bridges Gazebo simulation time to ROS 2 `/clock` |
| `bridge_lidar_pointcloud.sh` | Bridges the Gazebo LiDAR point cloud to ROS 2 |
| `start_rviz.sh` | Starts RViz 2 with simulation time enabled |
| `run_drone_detection_ros.sh` | Builds/runs the ROS 2 drone detection package |
| `mav.tlog` | MAVProxy telemetry log generated during SITL |
| `mav.tlog.raw` | Raw MAVProxy telemetry log |

> `mav.tlog` and `mav.tlog.raw` are runtime-generated files, not startup
> scripts.

---

# 1. Prerequisites

The main POC setup should already be completed.

Expected project:

```text
~/drone_detection_poc
```

Expected external dependencies:

```text
~/ardupilot
~/gz_ws/src/ardupilot_gazebo
```

The project environment is defined in:

```text
~/drone_detection_poc/config/environment.sh
```

ROS 2, Gazebo Harmonic, ArduPilot SITL, and ArduPilot-Gazebo should all be
installed and built successfully before using these scripts.

---

# 2. Recommended Two-Drone Startup Order

For the normal two-drone simulation, start the components in this order:

```text
1. Gazebo
2. Drone 1 SITL
3. Drone 2 SITL
4. Gazebo Clock Bridge
5. LiDAR Point Cloud Bridge
6. RViz
7. Drone Detection ROS
```

Each long-running component should normally be started in a **separate
terminal**.

---

# 3. Terminal 1 — Start Gazebo

```bash
cd ~/drone_detection_poc/scripts/simulation
./start_two_drone_gazebo.sh
```

This starts:

```text
simulation/gazebo/worlds/two_drone.sdf
```

Wait until Gazebo is fully started and the world is visible.

---

# 4. Terminal 2 — Start Drone 1

Open a new terminal:

```bash
cd ~/drone_detection_poc/scripts/simulation
./start_drone1.sh
```

This starts the first ArduCopter SITL instance:

```text
Instance: 0
```

Wait for SITL to finish initializing.

---

# 5. Terminal 3 — Start Drone 2

Open another terminal:

```bash
cd ~/drone_detection_poc/scripts/simulation
./start_drone2.sh
```

This starts the second ArduCopter SITL instance:

```text
Instance: 1
```

At this point, both simulated drones should be running.

---

# 6. Terminal 4 — Start Gazebo Clock Bridge

```bash
cd ~/drone_detection_poc/scripts/simulation
./bridge_gazebo_clock.sh
```

This bridges Gazebo simulation time to ROS 2:

```text
/clock
```

Verify:

```bash
ros2 topic echo /clock --once
```

You should receive a ROS clock message.

ROS nodes that use simulation time should have:

```text
use_sim_time = true
```

---

# 7. Terminal 5 — Start LiDAR Point Cloud Bridge

```bash
cd ~/drone_detection_poc/scripts/simulation
./bridge_lidar_pointcloud.sh
```

The main ROS LiDAR point-cloud topic is:

```text
/fixed_lidar/points/points
```

Check that it exists:

```bash
ros2 topic list | grep fixed_lidar
```

Check the publishing rate:

```bash
ros2 topic hz /fixed_lidar/points/points
```

You can also inspect one message:

```bash
ros2 topic echo /fixed_lidar/points/points --once
```

Because PointCloud2 messages can contain a large amount of binary data,
`ros2 topic echo` may report a large-buffer/sequence-size message while
printing the complete message. This does not necessarily mean the bridge
is broken. Prefer `ros2 topic hz` for a quick publishing check.

---

# 8. Terminal 6 — Start RViz

```bash
cd ~/drone_detection_poc/scripts/simulation
./start_rviz.sh
```

The script starts RViz with:

```text
use_sim_time=true
```

In RViz, add/configure a `PointCloud2` display and use:

```text
/fixed_lidar/points/points
```

Make sure the RViz `Fixed Frame` matches the frame used by the current
simulation configuration.

---

# 9. Terminal 7 — Start Drone Detection ROS

After Gazebo, both drones, the clock bridge, and LiDAR bridge are running:

```bash
cd ~/drone_detection_poc/scripts/simulation
./run_drone_detection_ros.sh
```

This starts the ROS 2 drone detection application.

You can inspect available ROS topics with:

```bash
ros2 topic list
```

---

# 10. Complete Manual Startup Sequence

For quick reference:

```bash
# Terminal 1
./start_two_drone_gazebo.sh

# Terminal 2
./start_drone1.sh

# Terminal 3
./start_drone2.sh

# Terminal 4
./bridge_gazebo_clock.sh

# Terminal 5
./bridge_lidar_pointcloud.sh

# Terminal 6
./start_rviz.sh

# Terminal 7
./run_drone_detection_ros.sh
```

All commands above are intended to run from:

```bash
~/drone_detection_poc/scripts/simulation
```

---

# 11. Basic Verification

## Check ROS nodes

```bash
ros2 node list
```

## Check ROS topics

```bash
ros2 topic list
```

## Check simulation clock

```bash
ros2 topic hz /clock
```

## Check LiDAR publishing

```bash
ros2 topic hz /fixed_lidar/points/points
```

## Check LiDAR topic information

```bash
ros2 topic info /fixed_lidar/points/points
```

## Check Gazebo topics

```bash
gz topic -l
```

---

# 12. Single-Drone Simulation

For a single-drone test, use:

```bash
./start_gazebo.sh
```

instead of:

```bash
./start_two_drone_gazebo.sh
```

Then start only:

```bash
./start_drone1.sh
```

The clock bridge, LiDAR bridge, RViz, and detection application can then
be started as required by the test.

---

# 13. Trajectory Scripts

Trajectory scripts are located separately:

```text
~/drone_detection_poc/scripts/trajectory/
```

Available scripts include:

```text
trajectory.py
trajectory_multidrones.py
trajectory_multidrones_circle.py
```

Start the appropriate trajectory script **after the required ArduPilot SITL
instances are running**.

Example:

```bash
cd ~/drone_detection_poc/scripts/trajectory
python3 trajectory.py
```

For the multidrone scripts, check the script's `--port` argument before
running because each SITL instance can use a different MAVLink port.

---

# 14. Stopping the Simulation

Stop each running process with:

```text
Ctrl+C
```

A clean shutdown order is:

```text
1. Drone Detection ROS
2. RViz
3. LiDAR bridge
4. Clock bridge
5. Drone 2 SITL
6. Drone 1 SITL
7. Gazebo
```

---

# 15. Troubleshooting

## Gazebo cannot find the ArduPilot plugin

Check:

```bash
echo "$GZ_SIM_SYSTEM_PLUGIN_PATH"
```

It should point to the ArduPilot-Gazebo build directory, for example:

```text
~/gz_ws/src/ardupilot_gazebo/build
```

Verify the plugin:

```bash
ls ~/gz_ws/src/ardupilot_gazebo/build/libArduPilotPlugin.so
```

---

## `/clock` is missing

Make sure the clock bridge is running:

```bash
./bridge_gazebo_clock.sh
```

Then:

```bash
ros2 topic echo /clock --once
```

---

## LiDAR topic is missing

Check:

```bash
ros2 topic list | grep fixed_lidar
```

If the topic is missing, verify that:

1. Gazebo is running.
2. The LiDAR exists in the simulation.
3. `bridge_lidar_pointcloud.sh` is running.

Then check:

```bash
ros2 topic hz /fixed_lidar/points/points
```

---

## RViz shows no point cloud

First verify that the topic is publishing:

```bash
ros2 topic hz /fixed_lidar/points/points
```

Then check in RViz:

- `Fixed Frame`
- `PointCloud2` display
- PointCloud2 topic
- `use_sim_time`

---

## ArduPilot SITL does not start

Check the ArduPilot directory:

```bash
ls ~/ardupilot
```

Check the SITL binary:

```bash
ls ~/ardupilot/build/sitl/bin/arducopter
```

Check `sim_vehicle.py`:

```bash
which sim_vehicle.py
```

---

# 16. Environment Configuration

Do not manually duplicate Gazebo plugin/resource paths in individual
simulation terminals.

The central configuration is:

```text
~/drone_detection_poc/config/environment.sh
```

This keeps the POC configuration consistent and avoids depending on old
machine-specific paths in `.bashrc`.

The simulation scripts source the project environment where required.

---

# 17. Runtime Files

ArduPilot/MAVProxy may generate:

```text
mav.tlog
mav.tlog.raw
```

These files contain telemetry/logging data generated during simulation.

They are not required for starting the simulation and may change after
each run.

If the project is committed to Git, consider excluding generated telemetry
files in `.gitignore`.

---

# 18. Quick Reference

```text
                 ┌─────────────────────┐
                 │       Gazebo        │
                 │ two_drone.sdf       │
                 └──────────┬──────────┘
                            │
                 ┌──────────┴──────────┐
                 │                     │
          ┌──────▼──────┐       ┌──────▼──────┐
          │   Drone 1   │       │   Drone 2   │
          │    SITL     │       │    SITL     │
          └─────────────┘       └─────────────┘
                            │
             ┌──────────────┴──────────────┐
             │                             │
      ┌──────▼──────┐               ┌──────▼──────┐
      │ Clock Bridge│               │ LiDAR Bridge│
      │    /clock   │               │  PointCloud2│
      └──────┬──────┘               └──────┬──────┘
             │                             │
             └──────────────┬──────────────┘
                            │
                    ┌───────▼────────┐
                    │      ROS 2     │
                    │                │
                    │ RViz / Detector│
                    └────────────────┘
```

**Recommended order:**

```text
Gazebo
  ↓
Drone 1
  ↓
Drone 2
  ↓
Clock Bridge
  ↓
LiDAR Bridge
  ↓
RViz
  ↓
Drone Detection ROS
```

This is the standard manual startup sequence for the current two-drone
simulation.
