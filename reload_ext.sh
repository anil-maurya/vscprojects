#!/bin/bash

# File to store the last window position
POSITION_FILE="wayland_window_position.txt"

# Default position and size if no previous position is saved
DEFAULT_X=100
DEFAULT_Y=100
DEFAULT_WIDTH=800  # Default window width
DEFAULT_HEIGHT=600 # Default window height

# Global variable to hold the session PID
SESSION_PID=""
SESSION_PGID=""

# Trap signals to avoid script termination
trap '' SIGTERM SIGINT

# Function to save the current window position to a file
save_window_position() {
    local window_id
    window_id=$(wmctrl -l | grep "gnome-shell" | awk '{print $1}')
    
    if [ -n "$window_id" ]; then
        # Extract X, Y, width, and height
        local geometry
        local x y width height
        geometry=$(wmctrl -lG | grep "$window_id" | awk '{print $3","$4","$5","$6}')
        
        x=$(echo $geometry | cut -d',' -f1)
        y=$(echo $geometry | cut -d',' -f2)
        width=$(echo $geometry | cut -d',' -f3)
        height=$(echo $geometry | cut -d',' -f4)
        
        # Adjust Y by subtracting 86 to fix the window drift
        adjusted_y=$((y - 86))
        
        # Save the corrected position
        echo "$x,$adjusted_y,$width,$height" > "$POSITION_FILE"
        echo "Saved window position: $x,$adjusted_y,$width,$height"
    else
        echo "Failed to retrieve window position."
    fi
}

# Function to load the last saved window position
load_window_position() {
    if [ -f "$POSITION_FILE" ]; then
        local position
        position=$(cat "$POSITION_FILE")
        echo "$position"
    else
        echo "$DEFAULT_X,$DEFAULT_Y,$DEFAULT_WIDTH,$DEFAULT_HEIGHT"
    fi
}

# Function to reposition the window to the saved position
reposition_window() {
    # Load the last saved position or use default
    local position
    position=$(load_window_position)

    # Apply the position to the window
    sleep 5
    wmctrl -r "gnome-shell" -e 0,$position
    
    if [ $? -eq 0 ]; then
        echo "Window repositioned to $position"
    else
        echo "Failed to reposition the window."
    fi

    # Set the window to always be on top
    wmctrl -r "gnome-shell" -b add,above
}

# Function to start the nested Wayland session and reposition the window
start_wayland_session() {
    echo "Starting the Wayland session..."
    
    # Start the session in a new process group and get its PID
    dbus-run-session -- gnome-shell --nested --wayland > /dev/null 2>&1 &
    SESSION_PID=$!
    SESSION_PGID=$(ps -o pgid= -p $SESSION_PID | grep -o '[0-9]*')

    echo "Started nested Wayland session with PID $SESSION_PID (PGID $SESSION_PGID)"

    # Reposition the window and make it stay on top
    reposition_window
}

# Function to stop the session (kill the process group)
stop_wayland_session() {
    if [ -n "$SESSION_PGID" ]; then
        echo "Stopping Wayland session with PGID $SESSION_PGID"
        
        # Save the current window position before stopping the session
        save_window_position
        
        kill -TERM -$SESSION_PGID 2>/dev/null
        sleep 2
        
        # Forcefully kill if the process group is still running
        if ps -p $SESSION_PID > /dev/null; then
            echo "Forcefully stopping the Wayland session..."
            kill -9 -$SESSION_PGID 2>/dev/null
        else
            echo "Wayland session stopped gracefully."
        fi
        
        SESSION_PID=""
        SESSION_PGID=""
    else
        echo "No session running."
    fi
}

# Start the initial session
start_wayland_session

# Wait for 'r' key press to reload the session
while true; do
    echo "Press 'r' to reload the Wayland session, or 'q' to quit."
    
    read -n 1 key
    echo ""  # For a new line after keypress

    if [[ $key == "r" ]]; then
        echo "Reloading Wayland session..."
        stop_wayland_session
        start_wayland_session
    elif [[ $key == "q" ]]; then
        echo "Exiting..."
        stop_wayland_session
        break
    else
        echo "Invalid key. Please press 'r' to reload or 'q' to quit."
    fi
done
