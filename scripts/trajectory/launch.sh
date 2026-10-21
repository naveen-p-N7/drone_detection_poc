# Tab 7: Runs Trajectory for Drone 1
gnome-terminal --tab -- bash -c "python3 ~/drone_detection_poc/scripts/trajectory/trajectory_multidrones_circle.py --port 14550 --altitude 4 --radius 3 --speed 2.5; exec bash"

# Tab 8: Runs Trajectory for Drone 2
gnome-terminal --tab -- bash -c "python3 ~/drone_detection_poc/scripts/trajectory/trajectory_multidrones_circle.py --port 14560 --altitude 3 --radius 4 --speed 2.5; exec bash"
