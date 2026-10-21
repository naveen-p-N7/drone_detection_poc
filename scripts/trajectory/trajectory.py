#!/usr/bin/env python3

import argparse
import time

from pymavlink import mavutil


MAVLINK_ADDRESS = "udp:127.0.0.1:14550"


def set_guided_mode(master):
    mode_map = master.mode_mapping()

    if mode_map is None or "GUIDED" not in mode_map:
        raise RuntimeError("GUIDED mode is not available")

    master.set_mode(mode_map["GUIDED"])
    time.sleep(1)


def send_position_target(master, north, east, down):
    type_mask = (
        mavutil.mavlink.POSITION_TARGET_TYPEMASK_VX_IGNORE
        | mavutil.mavlink.POSITION_TARGET_TYPEMASK_VY_IGNORE
        | mavutil.mavlink.POSITION_TARGET_TYPEMASK_VZ_IGNORE
        | mavutil.mavlink.POSITION_TARGET_TYPEMASK_AX_IGNORE
        | mavutil.mavlink.POSITION_TARGET_TYPEMASK_AY_IGNORE
        | mavutil.mavlink.POSITION_TARGET_TYPEMASK_AZ_IGNORE
        | mavutil.mavlink.POSITION_TARGET_TYPEMASK_YAW_IGNORE
        | mavutil.mavlink.POSITION_TARGET_TYPEMASK_YAW_RATE_IGNORE
    )

    master.mav.set_position_target_local_ned_send(
        int(time.time() * 1000) & 0xFFFFFFFF,
        master.target_system,
        master.target_component,
        mavutil.mavlink.MAV_FRAME_LOCAL_NED,
        type_mask,
        north,
        east,
        down,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        0.0, 0.0,
    )


def wait_until_reached(master, target_north, target_east, target_down):
    tolerance = 1.0

    while True:
        msg = master.recv_match(
            type="LOCAL_POSITION_NED",
            blocking=True,
            timeout=2.0,
        )

        if msg is None:
            print("Waiting for LOCAL_POSITION_NED...")
            continue

        dn = target_north - msg.x
        de = target_east - msg.y
        dd = target_down - msg.z

        distance = (dn * dn + de * de + dd * dd) ** 0.5

        print(
            f"Current NED=({msg.x:.2f}, {msg.y:.2f}, {msg.z:.2f}) "
            f"target=({target_north:.2f}, {target_east:.2f}, {target_down:.2f}) "
            f"error={distance:.2f} m"
        )

        if distance <= tolerance:
            return


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--altitude", type=float, default=3.0)
    parser.add_argument("--distance", type=float, default=40.0)
    args = parser.parse_args()

    print("Connecting to ArduPilot...")
    master = mavutil.mavlink_connection(MAVLINK_ADDRESS)
    master.wait_heartbeat(timeout=10)

    print(f"Connected: system={master.target_system}")

    set_guided_mode(master)

    down = -abs(args.altitude)

    print()
    print("Trajectory:")
    print(f"  Altitude: {args.altitude:.1f} m")
    print(f"  Distance: {args.distance:.1f} m")
    print("  Pattern: 0 -> distance -> 0")
    print("  Press Ctrl+C to stop")
    print()

    try:
        while True:
            print(f"Going to North={args.distance:.1f} m")
            send_position_target(
                master,
                north=args.distance,
                east=0.0,
                down=down,
            )
            wait_until_reached(
                master,
                args.distance,
                0.0,
                down,
            )

            print("Reached end point.")
            time.sleep(1.0)

            print("Returning to North=0.0 m")
            send_position_target(
                master,
                north=0.0,
                east=0.0,
                down=down,
            )
            wait_until_reached(
                master,
                0.0,
                0.0,
                down,
            )

            print("Reached start point.")
            time.sleep(1.0)

    except KeyboardInterrupt:
        print("\nTrajectory stopped by user.")


if __name__ == "__main__":
    main()
