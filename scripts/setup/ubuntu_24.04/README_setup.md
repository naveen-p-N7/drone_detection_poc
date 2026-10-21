# Drone Detection POC — Setup Scripts

This directory contains the installation and setup scripts required to
prepare the Drone Detection POC environment.

The setup is split into individual scripts so each component can be
installed and verified separately. There is also a top-level script that
runs the complete Ubuntu 24.04 setup automatically in the correct order.

---

## Directory Structure

```text
scripts/setup/
└── ubuntu_24.04/
    ├── prereq.sh
    ├── ros2_jazzy_setup.sh
    ├── gazebo_harmonic_setup.sh
    ├── ardupilot_setup.sh
    ├── ardupilot_gazebo_setup.sh
    ├── project_setup.sh
    └── setup_ubuntu_24.04.sh
```

This README explains the purpose and recommended execution order of these
scripts.

---

# 1. Supported Environment

This setup directory is for:

```text
Ubuntu 24.04 LTS
ROS 2 Jazzy
Gazebo Harmonic
ArduPilot SITL
ArduPilot-Gazebo
Drone Detection POC
```

The project is expected at:

```text
~/drone_detection_poc
```

The external dependencies are intentionally kept outside the POC project:

```text
~/ardupilot
~/gz_ws/src/ardupilot_gazebo
```

---

# 2. Two Ways to Run the Setup

There are two supported approaches.

## Option A — Run everything automatically

Use:

```bash
./setup_ubuntu_24.04.sh
```

This is the recommended method for setting up a new Ubuntu 24.04 machine.

The script executes all setup stages in the correct order.

---

## Option B — Run each setup script separately

Use this when:

- debugging a failed installation
- installing components manually
- verifying each dependency independently
- modifying a particular setup stage
- resuming setup after one stage failed

The scripts should be executed in the order described below.

---

# 3. Recommended Order — Individual Execution

From the Ubuntu 24.04 setup directory:

```bash
cd ~/drone_detection_poc/scripts/setup/ubuntu_24.04
```

Run:

```text
1. prereq.sh
2. ros2_jazzy_setup.sh
3. gazebo_harmonic_setup.sh
4. ardupilot_setup.sh
5. ardupilot_gazebo_setup.sh
6. project_setup.sh
```

In command form:

```bash
./prereq.sh
./ros2_jazzy_setup.sh
./gazebo_harmonic_setup.sh
./ardupilot_setup.sh
./ardupilot_gazebo_setup.sh
./project_setup.sh
```

Do not change the order unless you know that the dependency requirements
for the setup have also been changed.

---

# 4. Step 1 — `prereq.sh`

Purpose:

```text
Install and prepare general Ubuntu prerequisites required by the remaining
setup scripts.
```

Run:

```bash
./prereq.sh
```

This is the first script because the later setup stages may depend on
packages installed during this stage.

---

# 5. Step 2 — `ros2_jazzy_setup.sh`

Purpose:

```text
Install and configure ROS 2 Jazzy and the ROS tooling required by the POC.
```

Run:

```bash
./ros2_jazzy_setup.sh
```

This stage also configures the ROS tooling used later by the project setup.

Important checks after installation:

```bash
source /opt/ros/jazzy/setup.bash
echo $ROS_DISTRO
```

Expected:

```text
jazzy
```

You can also verify:

```bash
ros2 --version
colcon --version
rosdep --version
```

---

# 6. Step 3 — `gazebo_harmonic_setup.sh`

Purpose:

```text
Install Gazebo Harmonic and the dependencies required to build/use
ArduPilot-Gazebo.
```

Run:

```bash
./gazebo_harmonic_setup.sh
```

Verify Gazebo:

```bash
gz sim --version
```

The POC uses:

```text
Gazebo Harmonic
Gazebo Sim 8
```

The setup does not require Gazebo Classic for the POC.

---

# 7. Step 4 — `ardupilot_setup.sh`

Purpose:

```text
Install/build ArduPilot and prepare ArduCopter SITL.
```

Run:

```bash
./ardupilot_setup.sh
```

The ArduPilot repository is maintained outside the POC:

```text
~/ardupilot
```

The SITL binary is expected at:

```text
~/ardupilot/build/sitl/bin/arducopter
```

Verify:

```bash
ls ~/ardupilot/build/sitl/bin/arducopter
```

The setup stage also prepares the tools required to run:

```bash
sim_vehicle.py
```

---

# 8. Step 5 — `ardupilot_gazebo_setup.sh`

Purpose:

```text
Build the ArduPilot-Gazebo integration against Gazebo Harmonic.
```

Run:

```bash
./ardupilot_gazebo_setup.sh
```

The repository is maintained outside the POC:

```text
~/gz_ws/src/ardupilot_gazebo
```

The build output is expected in:

```text
~/gz_ws/src/ardupilot_gazebo/build
```

Important plugin:

```text
libArduPilotPlugin.so
```

Verify:

```bash
ls ~/gz_ws/src/ardupilot_gazebo/build/libArduPilotPlugin.so
```

The POC uses the ArduPilot-Gazebo build directory directly.

The setup does **not** need to copy the plugin `.so` files into the POC.

---

# 9. Step 6 — `project_setup.sh`

Purpose:

```text
Build and configure the Drone Detection POC itself.
```

Run:

```bash
./project_setup.sh
```

This stage is intentionally last because it depends on the required ROS,
Gazebo, ArduPilot, and ArduPilot-Gazebo components being available.

The ROS workspace is built using:

```bash
colcon build --symlink-install
```

After successful setup, the project should contain the normal ROS 2
workspace output:

```text
build/
install/
log/
```

The setup also verifies the `drone_detector` package.

---

# 10. Run Everything with `setup_ubuntu_24.04.sh`

For a new Ubuntu 24.04 machine, the easiest method is:

```bash
cd ~/drone_detection_poc/scripts/setup/ubuntu_24.04
./setup_ubuntu_24.04.sh
```

The top-level script runs:

```text
setup_ubuntu_24.04.sh
        │
        ├── prereq.sh
        │
        ├── ros2_jazzy_setup.sh
        │
        ├── gazebo_harmonic_setup.sh
        │
        ├── ardupilot_setup.sh
        │
        ├── ardupilot_gazebo_setup.sh
        │
        └── project_setup.sh
```

If any required stage fails, the top-level setup stops rather than
continuing with a potentially incomplete environment.

---

# 11. When Should I Use Each Method?

### New machine

Use:

```bash
./setup_ubuntu_24.04.sh
```

This is the simplest approach.

### Debugging

Run the individual scripts:

```bash
./prereq.sh
./ros2_jazzy_setup.sh
./gazebo_harmonic_setup.sh
./ardupilot_setup.sh
./ardupilot_gazebo_setup.sh
./project_setup.sh
```

This makes it clear which component failed.

### Re-running after a failure

You normally do **not** need to start from the beginning.

For example, if:

```text
ardupilot_gazebo_setup.sh
```

fails, fix the issue and rerun that stage:

```bash
./ardupilot_gazebo_setup.sh
```

Then continue with:

```bash
./project_setup.sh
```

Similarly, if only the ROS project build failed, you can usually rerun:

```bash
./project_setup.sh
```

---

# 12. Environment Configuration

The POC keeps its environment configuration centralized.

Main configuration:

```text
~/drone_detection_poc/config/environment.sh
```

Important external dependency paths include:

```text
ARDUPILOT_DIR
ARDUPILOT_GAZEBO_DIR
```

Gazebo configuration includes:

```text
GZ_VERSION=harmonic
GZ_SIM_SYSTEM_PLUGIN_PATH
GZ_SIM_RESOURCE_PATH
```

The setup scripts should not require manually adding these paths to
`.bashrc`.

This keeps the POC setup reproducible and avoids machine-specific shell
configuration.

---

# 13. External Dependencies

The POC intentionally does not copy external repositories into the
project.

Keep:

```text
~/ardupilot
```

and:

```text
~/gz_ws/src/ardupilot_gazebo
```

outside:

```text
~/drone_detection_poc
```

The project refers to these external installations through its environment
configuration.

This separation makes it easier to:

- update the POC
- update external dependencies independently
- keep the POC repository smaller
- avoid committing generated build artifacts
- reproduce the environment on another machine

---

# 14. No `.bashrc` Dependency

The setup is designed so that project-specific Gazebo paths do not have to
be permanently added to:

```text
~/.bashrc
```

When running project scripts, the required environment is loaded from:

```text
config/environment.sh
```

For ROS commands in a new terminal, source the installed ROS distribution
when necessary:

```bash
source /opt/ros/jazzy/setup.bash
```

After building the project, source:

```bash
source ~/drone_detection_poc/install/setup.bash
```

---

# 15. Permissions

If the scripts are not executable, run:

```bash
cd ~/drone_detection_poc/scripts/setup/ubuntu_24.04
chmod +x *.sh
```

Then:

```bash
ls -l *.sh
```

The scripts should have executable permissions.

The top-level setup script also prepares the individual stage scripts as
needed.

---

# 16. Recommended Verification After Complete Setup

After:

```bash
./setup_ubuntu_24.04.sh
```

successfully finishes, verify the major components.

## ROS 2

```bash
source /opt/ros/jazzy/setup.bash
echo $ROS_DISTRO
```

Expected:

```text
jazzy
```

## Gazebo

```bash
gz sim --version
```

Expected Gazebo release:

```text
Harmonic
```

## ArduPilot SITL

```bash
ls ~/ardupilot/build/sitl/bin/arducopter
```

## ArduPilot-Gazebo

```bash
ls ~/gz_ws/src/ardupilot_gazebo/build/libArduPilotPlugin.so
```

## POC ROS package

```bash
source ~/drone_detection_poc/install/setup.bash
ros2 pkg list | grep drone_detector
```

Expected:

```text
drone_detector
```

---

# 17. What Setup Does NOT Do

The setup scripts prepare the development/simulation environment.

They do not mean that the complete simulation is permanently running.

After setup completes, use the simulation scripts located at:

```text
~/drone_detection_poc/scripts/simulation/
```

For the two-drone simulation, follow:

```text
simulation/README.md
```

The normal simulation startup sequence is:

```text
Gazebo
  ↓
Drone 1 SITL
  ↓
Drone 2 SITL
  ↓
Gazebo Clock Bridge
  ↓
LiDAR Point Cloud Bridge
  ↓
RViz
  ↓
Drone Detection ROS
```

---

# 18. Setup vs Simulation

It is important to distinguish these two directories.

### Setup

```text
scripts/setup/
```

Used to install/build/configure dependencies and the POC.

### Simulation

```text
scripts/simulation/
```

Used to actually start Gazebo, SITL, ROS bridges, RViz, and the detection
application.

In other words:

```text
SETUP
  ↓
Install + Build + Configure
  ↓
SIMULATION
  ↓
Run Gazebo + Drones + Sensors + ROS Detection
```

---

# 19. Quick Reference

## Complete automatic setup

```bash
cd ~/drone_detection_poc/scripts/setup/ubuntu_24.04
./setup_ubuntu_24.04.sh
```

## Individual setup

```bash
cd ~/drone_detection_poc/scripts/setup/ubuntu_24.04

./prereq.sh
./ros2_jazzy_setup.sh
./gazebo_harmonic_setup.sh
./ardupilot_setup.sh
./ardupilot_gazebo_setup.sh
./project_setup.sh
```

## After setup

Go to:

```bash
cd ~/drone_detection_poc/scripts/simulation
```

Then follow:

```text
README.md
```

for the simulation startup order.

---

# 20. Summary

The Ubuntu 24.04 setup has six individual stages:

```text
1. prereq.sh
       ↓
2. ros2_jazzy_setup.sh
       ↓
3. gazebo_harmonic_setup.sh
       ↓
4. ardupilot_setup.sh
       ↓
5. ardupilot_gazebo_setup.sh
       ↓
6. project_setup.sh
```

Or use the single command:

```bash
./setup_ubuntu_24.04.sh
```

The single setup script is the preferred method for a clean/new machine,
while the individual scripts are useful for troubleshooting, development,
and rerunning a specific failed stage.
