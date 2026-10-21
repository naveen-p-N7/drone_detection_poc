#!/usr/bin/env python3
"""
Multi-drone ArduPilot SITL controller.

This script owns the ArduPilot SITL lifecycle for all configured drones.

Workflow:
    1. Start Gazebo separately.
    2. Start this controller.
    3. The controller starts one ArduPilot SITL instance per drone.
    4. Wait for each ArduPilot MAVLink heartbeat.
    5. Set each vehicle to GUIDED mode.
    6. Arm/take off only when required.
    7. Start all circular trajectories concurrently.
    8. Ctrl+C stops trajectories and terminates all SITL processes.

The circular trajectory follows the same position-target approach as the
original trajectory_multidrones_circle.py, with deterministic monotonic
timing so that command timing does not accumulate sleep jitter.

Gazebo is intentionally not started by this script.
"""

from __future__ import annotations

import math
import os
import signal
import subprocess
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Final

from pymavlink import mavutil


# ============================================================================
# Paths and SITL configuration
# ============================================================================

PROJECT_ROOT: Final[Path] = Path(__file__).resolve().parents[2]

ARDUPILOT_ROOT: Final[Path] = (
    Path(
        os.environ.get(
            "ARDUPILOT_DIR",
            str(Path.home() / "ardupilot"),
        )
    )
    .expanduser()
    .resolve()
)

ARDUCOPTER_DIRECTORY: Final[Path] = ARDUPILOT_ROOT / "ArduCopter"

SITL_EXECUTABLE: Final[str] = "sim_vehicle.py"
SITL_VEHICLE: Final[str] = "ArduCopter"
SITL_FRAME: Final[str] = "gazebo-iris"
SITL_MODEL: Final[str] = "JSON"
SITL_WORKING_DIRECTORY: Final[Path] = ARDUCOPTER_DIRECTORY


# ============================================================================
# Controller timing and flight configuration
# ============================================================================

HEARTBEAT_TIMEOUT_SECONDS: Final[float] = 30.0
ALTITUDE_MESSAGE_TIMEOUT_SECONDS: Final[float] = 5.0
SITL_STARTUP_DELAY_SECONDS: Final[float] = 1.0
COMMAND_DELAY_SECONDS: Final[float] = 1.0

# The original trajectory controller sent position targets at 10 Hz.
# A 20 Hz command rate provides ArduPilot with a denser position-target
# stream while retaining the same circular trajectory mathematics.
TRAJECTORY_UPDATE_RATE_HZ: Final[float] = 20.0
TRAJECTORY_UPDATE_PERIOD_SECONDS: Final[float] = (
    1.0 / TRAJECTORY_UPDATE_RATE_HZ
)

STATUS_PRINT_PERIOD_SECONDS: Final[float] = 1.0
ALTITUDE_TOLERANCE_METERS: Final[float] = 0.5

MIN_RADIUS_METERS: Final[float] = 0.1
MIN_SPEED_METERS_PER_SECOND: Final[float] = 0.1
MIN_ALTITUDE_METERS: Final[float] = 0.5

FULL_CIRCLE_RADIANS: Final[float] = 2.0 * math.pi
DOWN_DIRECTION: Final[float] = -1.0

# MAVLink local-NED position target configuration.
MAVLINK_FRAME: Final[int] = mavutil.mavlink.MAV_FRAME_LOCAL_NED

POSITION_TARGET_TYPE_MASK: Final[int] = (
    mavutil.mavlink.POSITION_TARGET_TYPEMASK_VX_IGNORE
    | mavutil.mavlink.POSITION_TARGET_TYPEMASK_VY_IGNORE
    | mavutil.mavlink.POSITION_TARGET_TYPEMASK_VZ_IGNORE
    | mavutil.mavlink.POSITION_TARGET_TYPEMASK_AX_IGNORE
    | mavutil.mavlink.POSITION_TARGET_TYPEMASK_AY_IGNORE
    | mavutil.mavlink.POSITION_TARGET_TYPEMASK_AZ_IGNORE
    | mavutil.mavlink.POSITION_TARGET_TYPEMASK_YAW_IGNORE
    | mavutil.mavlink.POSITION_TARGET_TYPEMASK_YAW_RATE_IGNORE
)


# ============================================================================
# Drone configuration
# ============================================================================

@dataclass(frozen=True)
class DroneConfiguration:
    """Configuration required to start and control one drone."""

    name: str

    # ArduPilot SITL instance number.
    sitl_instance: int

    # UDP port where MAVProxy forwards this vehicle's MAVLink stream.
    mavlink_port: int

    # Flight configuration.
    takeoff_altitude_meters: float
    circle_radius_meters: float
    circle_speed_meters_per_second: float

    # Circle center in the vehicle's local-NED frame.
    circle_center_north_meters: float
    circle_center_east_meters: float


DRONE_CONFIGURATIONS: Final[tuple[DroneConfiguration, ...]] = (
    DroneConfiguration(
        name="drone_1",
        sitl_instance=0,
        mavlink_port=14550,
        takeoff_altitude_meters=4.0,
        circle_radius_meters=3.0,
        circle_speed_meters_per_second=2.5,
        circle_center_north_meters=0.0,
        circle_center_east_meters=5.0,
    ),
    DroneConfiguration(
        name="drone_2",
        sitl_instance=1,
        mavlink_port=14560,
        takeoff_altitude_meters=3.0,
        circle_radius_meters=4.0,
        circle_speed_meters_per_second=2.5,
        circle_center_north_meters=0.0,
        circle_center_east_meters=5.0,
    ),
)


# ============================================================================
# Exceptions
# ============================================================================

class DroneControllerError(RuntimeError):
    """Base exception for controller-related failures."""


# ============================================================================
# SITL process manager
# ============================================================================

class SitlProcess:
    """Own and manage one ArduPilot sim_vehicle.py process."""

    def __init__(self, configuration: DroneConfiguration) -> None:
        self.configuration = configuration
        self.process: subprocess.Popen[str] | None = None

    def start(self) -> None:
        """Start the configured ArduPilot SITL instance."""
        if self.process is not None and self.process.poll() is None:
            raise DroneControllerError(
                f"[{self.configuration.name}] SITL is already running."
            )

        if not SITL_WORKING_DIRECTORY.is_dir():
            raise DroneControllerError(
                "ArduPilot directory was not found: "
                f"{SITL_WORKING_DIRECTORY}"
            )

        command = [
            SITL_EXECUTABLE,
            "-v",
            SITL_VEHICLE,
            "-f",
            SITL_FRAME,
            "--model",
            SITL_MODEL,
            "-I",
            str(self.configuration.sitl_instance),
            "--auto-sysid",
        ]

        print(
            f"[{self.configuration.name}] Starting SITL: "
            f"{' '.join(command)}"
        )

        try:
            self.process = subprocess.Popen(
                command,
                cwd=SITL_WORKING_DIRECTORY,
                env=os.environ.copy(),
                text=True,
            )
        except FileNotFoundError as exc:
            raise DroneControllerError(
                f"[{self.configuration.name}] "
                f"Could not start {SITL_EXECUTABLE}. "
                "Make sure ArduPilot is installed and sim_vehicle.py "
                "is available in PATH."
            ) from exc
        except OSError as exc:
            raise DroneControllerError(
                f"[{self.configuration.name}] "
                f"Failed to start SITL: {exc}"
            ) from exc

        time.sleep(SITL_STARTUP_DELAY_SECONDS)

        if self.process.poll() is not None:
            raise DroneControllerError(
                f"[{self.configuration.name}] "
                "SITL exited immediately with return code "
                f"{self.process.returncode}."
            )

        print(
            f"[{self.configuration.name}] "
            f"SITL started with PID {self.process.pid}."
        )

    def stop(self) -> None:
        """Terminate the SITL process gracefully."""
        if self.process is None:
            return

        if self.process.poll() is not None:
            self.process = None
            return

        print(
            f"[{self.configuration.name}] "
            f"Stopping SITL process {self.process.pid}..."
        )

        self.process.send_signal(signal.SIGINT)

        try:
            self.process.wait(timeout=10.0)
        except subprocess.TimeoutExpired:
            print(
                f"[{self.configuration.name}] "
                "SITL did not stop after SIGINT. Terminating..."
            )
            self.process.terminate()

            try:
                self.process.wait(timeout=5.0)
            except subprocess.TimeoutExpired:
                print(
                    f"[{self.configuration.name}] "
                    "SITL did not terminate. Killing..."
                )
                self.process.kill()
                self.process.wait()

        print(f"[{self.configuration.name}] SITL stopped.")
        self.process = None


# ============================================================================
# MAVLink drone controller
# ============================================================================

class DroneController:
    """Connect to and control one ArduPilot vehicle."""

    def __init__(
        self,
        configuration: DroneConfiguration,
    ) -> None:
        self.configuration = configuration
        self.connection_string = (
            f"udp:127.0.0.1:{configuration.mavlink_port}"
        )
        self.master: mavutil.mavfile | None = None

    def connect(self) -> None:
        """Connect specifically to the ArduPilot vehicle heartbeat."""
        print(
            f"[{self.configuration.name}] "
            f"Waiting for ArduPilot heartbeat on "
            f"{self.connection_string}..."
        )

        self.master = mavutil.mavlink_connection(
            self.connection_string
        )

        deadline = time.monotonic() + HEARTBEAT_TIMEOUT_SECONDS

        while time.monotonic() < deadline:
            remaining_seconds = max(
                0.1,
                deadline - time.monotonic(),
            )

            message = self.master.recv_match(
                type="HEARTBEAT",
                blocking=True,
                timeout=remaining_seconds,
            )

            if message is None:
                break

            if getattr(
                message,
                "autopilot",
                None,
            ) != mavutil.mavlink.MAV_AUTOPILOT_ARDUPILOTMEGA:
                continue

            self.master.target_system = message.get_srcSystem()
            self.master.target_component = message.get_srcComponent()

            print(
                f"[{self.configuration.name}] "
                f"Connected to ArduPilot: "
                f"system={self.master.target_system}, "
                f"component={self.master.target_component}, "
                f"type={message.type}"
            )

            return

        raise DroneControllerError(
            f"[{self.configuration.name}] "
            "Timed out waiting for an ArduPilot vehicle heartbeat "
            f"on UDP port {self.configuration.mavlink_port}."
        )

    def _require_connection(self) -> mavutil.mavfile:
        """Return the MAVLink connection or raise an error."""
        if self.master is None:
            raise DroneControllerError(
                f"[{self.configuration.name}] "
                "MAVLink connection has not been established."
            )

        return self.master

    def set_guided_mode(self) -> None:
        """Set the vehicle to GUIDED mode."""
        master = self._require_connection()

        mode_mapping = master.mode_mapping()

        if mode_mapping is None:
            raise DroneControllerError(
                f"[{self.configuration.name}] "
                "ArduPilot did not provide a mode mapping."
            )

        guided_mode = mode_mapping.get("GUIDED")

        if guided_mode is None:
            raise DroneControllerError(
                f"[{self.configuration.name}] "
                "GUIDED mode is not available."
            )

        master.set_mode(guided_mode)
        time.sleep(COMMAND_DELAY_SECONDS)

        print(
            f"[{self.configuration.name}] "
            "GUIDED mode requested."
        )

    def is_armed(self) -> bool:
        """Return whether the vehicle is currently armed."""
        master = self._require_connection()
        return bool(master.motors_armed())

    def arm_if_needed(self) -> None:
        """Arm only when the vehicle is currently disarmed."""
        master = self._require_connection()

        if self.is_armed():
            print(
                f"[{self.configuration.name}] "
                "Vehicle is already armed. Skipping arm."
            )
            return

        print(
            f"[{self.configuration.name}] "
            "Vehicle is disarmed. Arming..."
        )

        master.arducopter_arm()
        master.motors_armed_wait()

        print(
            f"[{self.configuration.name}] "
            "Vehicle armed."
        )

    def get_relative_altitude(self) -> float:
        """Read relative altitude in metres."""
        master = self._require_connection()

        message = master.recv_match(
            type="GLOBAL_POSITION_INT",
            blocking=True,
            timeout=ALTITUDE_MESSAGE_TIMEOUT_SECONDS,
        )

        if message is None:
            raise DroneControllerError(
                f"[{self.configuration.name}] "
                "Timed out while reading vehicle altitude."
            )

        return message.relative_alt / 1000.0

    def send_takeoff_command(self) -> None:
        """Send a takeoff command to the configured altitude."""
        master = self._require_connection()
        altitude = self.configuration.takeoff_altitude_meters

        master.mav.command_long_send(
            master.target_system,
            master.target_component,
            mavutil.mavlink.MAV_CMD_NAV_TAKEOFF,
            0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            altitude,
        )

    def takeoff_if_needed(self) -> None:
        """Take off only when the vehicle is below target altitude."""
        target_altitude = (
            self.configuration.takeoff_altitude_meters
        )
        current_altitude = self.get_relative_altitude()

        if (
            current_altitude
            >= target_altitude - ALTITUDE_TOLERANCE_METERS
        ):
            print(
                f"[{self.configuration.name}] "
                f"Already airborne at {current_altitude:.2f} m. "
                "Skipping takeoff."
            )
            return

        print(
            f"[{self.configuration.name}] "
            f"Current altitude is {current_altitude:.2f} m. "
            f"Taking off to {target_altitude:.2f} m..."
        )

        self.send_takeoff_command()
        time.sleep(COMMAND_DELAY_SECONDS)
        self.wait_for_altitude()

    def wait_for_altitude(self) -> None:
        """Wait until the vehicle reaches its configured altitude."""
        target_altitude = (
            self.configuration.takeoff_altitude_meters
        )

        print(
            f"[{self.configuration.name}] "
            f"Waiting for altitude {target_altitude:.1f} m..."
        )

        while True:
            current_altitude = self.get_relative_altitude()
            altitude_error = abs(
                target_altitude - current_altitude
            )

            if altitude_error <= ALTITUDE_TOLERANCE_METERS:
                print(
                    f"[{self.configuration.name}] "
                    f"Target altitude reached: "
                    f"{current_altitude:.2f} m."
                )
                return

    def prepare_vehicle(self) -> None:
        """Prepare a vehicle regardless of its starting flight state."""
        self.set_guided_mode()
        self.arm_if_needed()
        self.takeoff_if_needed()

    def send_position_target(
        self,
        north_meters: float,
        east_meters: float,
        down_meters: float,
    ) -> None:
        """Send a local-NED position target."""
        master = self._require_connection()

        timestamp_milliseconds = (
            int(time.time() * 1000) & 0xFFFFFFFF
        )

        master.mav.set_position_target_local_ned_send(
            timestamp_milliseconds,
            master.target_system,
            master.target_component,
            MAVLINK_FRAME,
            POSITION_TARGET_TYPE_MASK,
            north_meters,
            east_meters,
            down_meters,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
        )

    def fly_circle(
        self,
        stop_event: threading.Event,
    ) -> None:
        """
        Command a smooth circular position trajectory.

        The circle is parameterized by elapsed monotonic time:

            angle = angular_speed * elapsed_time

        This avoids cumulative timing drift from repeated sleep() calls.
        Every trajectory thread has its own independent schedule.
        """
        radius = self.configuration.circle_radius_meters
        speed = (
            self.configuration.circle_speed_meters_per_second
        )
        center_north = (
            self.configuration.circle_center_north_meters
        )
        center_east = (
            self.configuration.circle_center_east_meters
        )
        altitude = (
            self.configuration.takeoff_altitude_meters
        )

        angular_speed = speed / radius
        trajectory_start_time = time.monotonic()
        next_update_time = trajectory_start_time
        last_status_time = trajectory_start_time

        print(
            f"[{self.configuration.name}] "
            f"Starting circular trajectory: "
            f"radius={radius:.1f} m, "
            f"speed={speed:.1f} m/s, "
            f"altitude={altitude:.1f} m, "
            f"rate={TRAJECTORY_UPDATE_RATE_HZ:.0f} Hz."
        )

        while not stop_event.is_set():
            current_time = time.monotonic()
            elapsed_time = current_time - trajectory_start_time

            angle = (
                angular_speed * elapsed_time
            ) % FULL_CIRCLE_RADIANS

            north = (
                center_north
                + radius * math.cos(angle)
            )
            east = (
                center_east
                + radius * math.sin(angle)
            )
            down = DOWN_DIRECTION * altitude

            self.send_position_target(
                north_meters=north,
                east_meters=east,
                down_meters=down,
            )

            if (
                current_time - last_status_time
                >= STATUS_PRINT_PERIOD_SECONDS
            ):
                print(
                    f"[{self.configuration.name}] "
                    f"target: "
                    f"N={north:.2f} m, "
                    f"E={east:.2f} m, "
                    f"D={down:.2f} m"
                )
                last_status_time = current_time

            next_update_time += (
                TRAJECTORY_UPDATE_PERIOD_SECONDS
            )

            wait_time = next_update_time - time.monotonic()

            if wait_time > 0.0:
                stop_event.wait(wait_time)
            else:
                # If the process was delayed, resynchronize the scheduler
                # instead of performing a burst of catch-up commands.
                next_update_time = time.monotonic()

        print(
            f"[{self.configuration.name}] "
            "Trajectory stopped."
        )


# ============================================================================
# Validation
# ============================================================================

def validate_configuration(
    configuration: DroneConfiguration,
) -> None:
    """Validate one drone configuration."""
    if not configuration.name.strip():
        raise ValueError("Drone name must not be empty.")

    if configuration.sitl_instance < 0:
        raise ValueError(
            f"[{configuration.name}] "
            "SITL instance must be zero or greater."
        )

    if configuration.mavlink_port <= 0:
        raise ValueError(
            f"[{configuration.name}] "
            "MAVLink UDP port must be greater than zero."
        )

    if (
        configuration.takeoff_altitude_meters
        < MIN_ALTITUDE_METERS
    ):
        raise ValueError(
            f"[{configuration.name}] "
            "Takeoff altitude must be at least "
            f"{MIN_ALTITUDE_METERS:.1f} m."
        )

    if (
        configuration.circle_radius_meters
        < MIN_RADIUS_METERS
    ):
        raise ValueError(
            f"[{configuration.name}] "
            "Circle radius must be at least "
            f"{MIN_RADIUS_METERS:.1f} m."
        )

    if (
        configuration.circle_speed_meters_per_second
        < MIN_SPEED_METERS_PER_SECOND
    ):
        raise ValueError(
            f"[{configuration.name}] "
            "Circle speed must be at least "
            f"{MIN_SPEED_METERS_PER_SECOND:.1f} m/s."
        )


def validate_all_configurations() -> None:
    """Validate all drone configurations."""
    if not DRONE_CONFIGURATIONS:
        raise ValueError(
            "At least one drone must be configured."
        )

    names: set[str] = set()
    instances: set[int] = set()
    ports: set[int] = set()

    for configuration in DRONE_CONFIGURATIONS:
        validate_configuration(configuration)

        if configuration.name in names:
            raise ValueError(
                f"Duplicate drone name: {configuration.name}"
            )

        if configuration.sitl_instance in instances:
            raise ValueError(
                f"Duplicate SITL instance: "
                f"{configuration.sitl_instance}"
            )

        if configuration.mavlink_port in ports:
            raise ValueError(
                f"Duplicate MAVLink port: "
                f"{configuration.mavlink_port}"
            )

        names.add(configuration.name)
        instances.add(configuration.sitl_instance)
        ports.add(configuration.mavlink_port)


# ============================================================================
# Multi-drone orchestration
# ============================================================================

def start_all_sitl_processes(
    sitl_processes: list[SitlProcess],
) -> None:
    """Start all configured SITL processes."""
    print("Starting all ArduPilot SITL instances...")

    started_processes: list[SitlProcess] = []

    try:
        for sitl_process in sitl_processes:
            sitl_process.start()
            started_processes.append(sitl_process)
    except Exception:
        for sitl_process in reversed(started_processes):
            sitl_process.stop()
        raise

    print("All SITL instances started.")


def connect_and_prepare_drones(
    controllers: list[DroneController],
) -> None:
    """Connect and prepare all configured drones."""
    print("Connecting to all configured drones...")

    for controller in controllers:
        controller.connect()

    print("Preparing all drones...")

    for controller in controllers:
        controller.prepare_vehicle()

    print("All drones are ready for trajectory control.")


def run_trajectories(
    controllers: list[DroneController],
    stop_event: threading.Event,
) -> None:
    """Run all drone trajectories concurrently."""
    trajectory_threads: list[threading.Thread] = []

    for controller in controllers:
        thread = threading.Thread(
            target=controller.fly_circle,
            args=(stop_event,),
            name=(
                f"{controller.configuration.name}"
                "_trajectory"
            ),
            daemon=True,
        )

        trajectory_threads.append(thread)
        thread.start()

    print("All trajectories are running.")
    print("Press Ctrl+C to stop.")

    try:
        while not stop_event.is_set():
            stop_event.wait(1.0)
    except KeyboardInterrupt:
        print("\nStopping all trajectories...")
        stop_event.set()

    for thread in trajectory_threads:
        thread.join()

    print("All trajectories stopped.")


def stop_all_sitl_processes(
    sitl_processes: list[SitlProcess],
) -> None:
    """Stop all SITL processes in reverse startup order."""
    print("Stopping all SITL instances...")

    for sitl_process in reversed(sitl_processes):
        sitl_process.stop()

    print("All SITL instances stopped.")


# ============================================================================
# Main entry point
# ============================================================================

def main() -> None:
    """Run the complete multi-drone simulation controller."""
    validate_all_configurations()

    sitl_processes = [
        SitlProcess(configuration)
        for configuration in DRONE_CONFIGURATIONS
    ]

    controllers = [
        DroneController(configuration)
        for configuration in DRONE_CONFIGURATIONS
    ]

    stop_event = threading.Event()

    try:
        start_all_sitl_processes(sitl_processes)
        connect_and_prepare_drones(controllers)
        run_trajectories(
            controllers,
            stop_event,
        )

    except KeyboardInterrupt:
        print("\nController interrupted.")

    except Exception as exc:
        print(f"\nController error: {exc}")
        raise

    finally:
        stop_event.set()
        stop_all_sitl_processes(sitl_processes)


if __name__ == "__main__":
    main()
