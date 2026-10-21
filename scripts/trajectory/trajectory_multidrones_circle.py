#!/usr/bin/env python3

import argparse
import math
import time

from pymavlink import mavutil


def set_guided_mode(master):
    mode_map = master.mode_mapping()

    if mode_map is None or "GUIDED" not in mode_map:
        raise RuntimeError("GUIDED mode is not available")

    master.set_mode(mode_map["GUIDED"])
    time.sleep(1.0)


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


def main():
    parser = argparse.ArgumentParser(
        description="Fly an ArduPilot drone in a horizontal circle."
    )

    parser.add_argument(
        "--port",
        type=int,
        required=True,
        help="MAVLink UDP port, e.g. 14550",
    )

    parser.add_argument(
        "--altitude",
        type=float,
        default=3.0,
        help="Altitude in metres",
    )

    parser.add_argument(
        "--radius",
        type=float,
        default=5.0,
        help="Circle radius in metres",
    )

    parser.add_argument(
        "--speed",
        type=float,
        default=1.0,
        help="Approximate tangential speed in m/s",
    )

    parser.add_argument(
       "--center-north",
       type=float,
       default=0.0,
       help="Circle center North coordinate",
    )

    parser.add_argument(
       "--center-east",
       type=float,
       default=5.0,
       help="Circle center East coordinate",
    )

    args = parser.parse_args()

    master = mavutil.mavlink_connection(
        f"udp:127.0.0.1:{args.port}"
    )

    print("Connecting to ArduPilot...")
    master.wait_heartbeat(timeout=10)

    print(
        f"Connected: system={master.target_system}, "
        f"component={master.target_component}"
    )

    set_guided_mode(master)

    altitude = abs(args.altitude)
    radius = abs(args.radius)
    speed = abs(args.speed)

    if radius <= 0.0:
        raise ValueError("Radius must be greater than zero")

    if speed <= 0.0:
        raise ValueError("Speed must be greater than zero")

    down = -altitude

    # Angular velocity:
    # linear speed = radius * angular speed
    angular_speed = speed / radius

    # Send position targets at 10 Hz.
    update_period = 0.1

    angle = 0.0

    print()
    print("Circular trajectory")
    print(f"  Port:      {args.port}")
    print(f"  Altitude:  {altitude:.1f} m")
    print(f"  Radius:    {radius:.1f} m")
    print(f"  Speed:     {speed:.1f} m/s")
    print(f"  Direction: counter-clockwise")
    print("  Stop:      Ctrl+C")
    print()

    try:
        while True:
            north = (
    		    args.center_north + radius * math.cos(angle)
    	    )

            east = (
	            args.center_east + radius * math.sin(angle)
    	    )

            send_position_target(
                master,
                north=north,
                east=east,
                down=down,
            )

            print(
                f"Target N={north:6.2f} "
                f"E={east:6.2f} "
                f"D={down:6.2f}"
            )

            angle += angular_speed * update_period

            if angle >= 2.0 * math.pi:
                angle -= 2.0 * math.pi

            time.sleep(update_period)

    except KeyboardInterrupt:
        print("\nCircular trajectory stopped.")


if __name__ == "__main__":
    main()
