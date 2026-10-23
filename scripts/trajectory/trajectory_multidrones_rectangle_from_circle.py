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


def altitude_at(elapsed, min_altitude, max_altitude, period):
    """Smoothly oscillate from min to max and back to min over one period."""
    phase = 2.0 * math.pi * (elapsed % period) / period
    return min_altitude + 0.5 * (max_altitude - min_altitude) * (1.0 - math.cos(phase))


def current_altitude(args, start_time):
    if args.min_altitude is None:
        return abs(args.altitude)
    return altitude_at(
        time.monotonic() - start_time,
        args.min_altitude,
        args.max_altitude,
        args.altitude_period,
    )


def hold_corner(master, north, east, args, start_time, seconds, update_period):
    end_time = time.monotonic() + seconds

    while time.monotonic() < end_time:
        altitude = current_altitude(args, start_time)
        down = -altitude
        send_position_target(master, north, east, down)

        remaining = max(0.0, end_time - time.monotonic())

        print(
            f"\rHolding corner: {remaining:4.1f}s "
            f"N={north:6.2f} E={east:6.2f} Alt={altitude:4.2f}m",
            end="",
            flush=True,
        )

        time.sleep(min(update_period, remaining))

    print()


def main():
    parser = argparse.ArgumentParser(
        description="Fly an ArduPilot drone around a rectangle centered on the lidar."
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
        help="Fixed altitude in metres (used when no altitude range is given)",
    )

    parser.add_argument(
        "--min-altitude", "--minaltitude",
        dest="min_altitude",
        type=float,
        help="Minimum altitude in metres; use together with --max-altitude",
    )

    parser.add_argument(
        "--max-altitude", "--maxaltitude",
        dest="max_altitude",
        type=float,
        help="Maximum altitude in metres; use together with --min-altitude",
    )

    parser.add_argument(
        "--altitude-period",
        type=float,
        default=20.0,
        help="Seconds for one smooth min-to-max-to-min altitude cycle (default: 20)",
    )

    parser.add_argument(
        "--length",
        type=float,
        default=10.0,
        help="Rectangle length in metres (North direction)",
    )

    parser.add_argument(
        "--width",
        "--breadth",
        dest="width",
        type=float,
        default=10.0,
        help="Rectangle width/breadth in metres (East direction)",
    )

    parser.add_argument(
        "--speed",
        type=float,
        default=1.0,
        help="Approximate trajectory speed in m/s",
    )

    # IMPORTANT:
    # These defaults intentionally match the supplied working circle script.
    parser.add_argument(
        "--center-north",
        type=float,
        default=0.0,
        help="Rectangle center North coordinate",
    )

    parser.add_argument(
        "--center-east",
        type=float,
        default=5.0,
        help="Rectangle center East coordinate",
    )

    parser.add_argument(
        "--corner-hold",
        type=float,
        default=3.0,
        help="Seconds to hold at each corner before turning",
    )

    parser.add_argument(
        "--cycles",
        type=int,
        default=0,
        help="Number of complete rectangle cycles; 0 = continuous",
    )

    args = parser.parse_args()

    length = abs(args.length)
    width = abs(args.width)
    speed = abs(args.speed)

    if (args.min_altitude is None) != (args.max_altitude is None):
        raise ValueError("Specify both --min-altitude and --max-altitude")

    if args.min_altitude is not None:
        if args.min_altitude <= 0.0 or args.max_altitude <= 0.0:
            raise ValueError("Minimum and maximum altitudes must be greater than zero")
        if args.min_altitude >= args.max_altitude:
            raise ValueError("Minimum altitude must be less than maximum altitude")
        if args.altitude_period <= 0.0:
            raise ValueError("Altitude period must be greater than zero")
        altitude_description = (
            f"{args.min_altitude:.1f}–{args.max_altitude:.1f} m "
            f"(period {args.altitude_period:.1f} s)"
        )
    else:
        altitude_description = f"{abs(args.altitude):.1f} m (fixed)"

    if length <= 0.0:
        raise ValueError("Length must be greater than zero")

    if width <= 0.0:
        raise ValueError("Width/breadth must be greater than zero")

    if speed <= 0.0:
        raise ValueError("Speed must be greater than zero")

    if args.corner_hold < 0.0:
        raise ValueError("Corner hold cannot be negative")

    if args.cycles < 0:
        raise ValueError("Cycles cannot be negative")

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

    trajectory_start_time = time.monotonic()

    # Same 10 Hz update rate as the supplied circle script.
    update_period = 0.1

    # ---------------------------------------------------------
    # IMPORTANT:
    #
    # Use exactly the same center convention as the supplied
    # working circle trajectory:
    #
    #   center_north = 0
    #   center_east  = 5
    #
    # The rectangle is built around THIS center.
    #
    # length -> North dimension
    # width  -> East dimension
    #
    #                C ---------------- D
    #                |                  |
    #                |       LIDAR      |
    #                |         +        |
    #                |                  |
    #                A ---------------- B
    #
    #                A -> B -> D -> C -> A
    # ---------------------------------------------------------

    half_length = length / 2.0
    half_width = width / 2.0

    center_north = args.center_north
    center_east = args.center_east

    A = (
        center_north - half_length,
        center_east - half_width,
    )

    B = (
        center_north + half_length,
        center_east - half_width,
    )

    D = (
        center_north + half_length,
        center_east + half_width,
    )

    C = (
        center_north - half_length,
        center_east + half_width,
    )

    print()
    print("Rectangular trajectory")
    print(f"  Port:        {args.port}")
    print(f"  Altitude:    {altitude_description}")
    print(f"  Length:      {length:.1f} m")
    print(f"  Width:       {width:.1f} m")
    print(f"  Speed:       {speed:.1f} m/s")
    print(f"  Center:      N={center_north:.2f} E={center_east:.2f}")
    print(f"  Corner hold: {args.corner_hold:.1f} s")
    print(
        f"  Cycles:      "
        f"{'continuous' if args.cycles == 0 else args.cycles}"
    )
    print()
    print("  Corners:")
    print(f"    A: N={A[0]:6.2f} E={A[1]:6.2f}")
    print(f"    B: N={B[0]:6.2f} E={B[1]:6.2f}")
    print(f"    D: N={D[0]:6.2f} E={D[1]:6.2f}")
    print(f"    C: N={C[0]:6.2f} E={C[1]:6.2f}")
    print()
    print("  Path: A -> B -> D -> C -> A")
    print("  Stop: Ctrl+C")
    print()

    segments = [
        ("A -> B", A, B),
        ("B -> D", B, D),
        ("D -> C", D, C),
        ("C -> A", C, A),
    ]

    completed_cycles = 0

    try:
        while True:
            for segment_name, start, end in segments:
                start_north, start_east = start
                end_north, end_east = end

                delta_north = end_north - start_north
                delta_east = end_east - start_east

                distance = (
                    delta_north * delta_north
                    + delta_east * delta_east
                ) ** 0.5

                travel_time = distance / speed
                steps = max(1, int(travel_time / update_period))

                print(f"Moving {segment_name}")

                for step in range(1, steps + 1):
                    progress = step / steps

                    north = (
                        start_north
                        + delta_north * progress
                    )

                    east = (
                        start_east
                        + delta_east * progress
                    )

                    altitude = current_altitude(args, trajectory_start_time)
                    down = -altitude

                    send_position_target(
                        master,
                        north=north,
                        east=east,
                        down=down,
                    )

                    print(
                        f"\rTarget N={north:6.2f} "
                        f"E={east:6.2f} "
                        f"Alt={altitude:4.2f}m",
                        end="",
                        flush=True,
                    )

                    time.sleep(update_period)

                print()
                print(
                    f"Reached corner: "
                    f"N={end_north:.2f} E={end_east:.2f}"
                )

                if args.corner_hold > 0.0:
                    hold_corner(
                        master,
                        end_north,
                        end_east,
                        args,
                        trajectory_start_time,
                        args.corner_hold,
                        update_period,
                    )

            completed_cycles += 1

            print(
                f"Completed rectangle cycle "
                f"{completed_cycles}"
            )

            if (
                args.cycles > 0
                and completed_cycles >= args.cycles
            ):
                print("Requested cycles completed.")
                break

    except KeyboardInterrupt:
        print("\nRectangular trajectory stopped.")


if __name__ == "__main__":
    main()
