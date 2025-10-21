#!/bin/bash

# Script to find the latest SBO001 log file with dynamic date
# Usage: ./get-latest-sbo-log.sh [log_directory]
# Example: ./get-latest-sbo-log.sh /home/rnd/studio-sdp-roulette/logs

# Default log directory
DEFAULT_LOG_DIR="/home/rnd/studio-sdp-roulette/logs"
LOG_DIR="${1:-$DEFAULT_LOG_DIR}"

# Check if log directory exists
if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Log directory $LOG_DIR does not exist"
    exit 1
fi

# Find the latest SBO001_*.log file based on modification time
LATEST_LOG=$(find "$LOG_DIR" -name "SBO001_*.log" -type f -printf "%T@ %p\n" 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

if [ -z "$LATEST_LOG" ]; then
    echo "Error: No SBO001_*.log files found in $LOG_DIR"
    exit 1
fi

# Extract just the filename for display
FILENAME=$(basename "$LATEST_LOG")

echo "Latest SBO001 log file: $FILENAME"
echo "Full path: $LATEST_LOG"

# Optional: Show file info
if [ "$2" = "--info" ]; then
    echo "File info:"
    ls -la "$LATEST_LOG"
    echo "Last modified: $(stat -c %y "$LATEST_LOG")"
fi

# Return the full path for use in other scripts
echo "$LATEST_LOG"
