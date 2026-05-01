#!/bin/bash
# TEAMMATE.POTO — macOS PyInstaller build
# Produces a standalone binary: dist/TEAMMATE.POTO
#
# Usage:
#   chmod +x build_mac.sh
#   ./build_mac.sh

set -e
cd "$(dirname "$0")"

echo "Installing build tools..."
pip3 install pyinstaller

echo "Building TEAMMATE.POTO..."
pyinstaller \
    --onefile \
    --console \
    --name "TEAMMATE.POTO" \
    --hidden-import mido.backends.rtmidi \
    --hidden-import mido.backends.rtmidi2 \
    TEAMMATE_MAC.POTO

echo ""
echo "Build complete: dist/TEAMMATE.POTO"
echo "Copy dist/TEAMMATE.POTO to your release folder."
