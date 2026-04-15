#!/bin/bash
# TEAMMATE.POTO — macOS launcher
# Double-click this file to run

cd "$(dirname "$0")"

# Check Python 3
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 not found. Install from https://python.org"
    read -p "Press Enter to exit..."
    exit 1
fi

# Check dependencies
python3 -c "import numpy, sounddevice, mido" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Installing dependencies..."
    pip3 install -r requirements.txt
fi

# Run
python3 TEAMMATE_MAC.POTO run "$@"
