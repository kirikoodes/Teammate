#!/bin/bash
# TEAMMATE.POTO — macOS launcher
# Double-click this file to run.
# First launch: installs everything automatically.

cd "$(dirname "$0")"

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

echo ""
echo -e "${BOLD}  TEAMMATE.POTO  —  NSDOS / KOODES${RESET}"
echo "  ──────────────────────────────────"
echo ""

# ── 1. Python 3 ──────────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}  ERROR: python3 not found.${RESET}"
    echo "  Install Python 3.10 or 3.11 from https://python.org"
    echo ""
    read -p "  Press Enter to exit..."
    exit 1
fi

PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo -e "  Python $PY_VERSION detected."

# ── 2. portaudio (required by sounddevice) ───────────────────────────────────
if ! python3 -c "import sounddevice" &>/dev/null; then
    echo ""
    echo "  sounddevice not installed — checking portaudio..."
    if command -v brew &>/dev/null; then
        echo "  Installing portaudio via Homebrew..."
        brew install portaudio --quiet
    else
        echo -e "${YELLOW}  Homebrew not found. Install it from https://brew.sh${RESET}"
        echo "  Then run:  brew install portaudio"
        echo "  Then re-open this file."
        echo ""
        read -p "  Press Enter to exit..."
        exit 1
    fi
fi

# ── 3. Python dependencies ───────────────────────────────────────────────────
STAMP=".deps_installed"
NEEDS_INSTALL=false

if [ ! -f "$STAMP" ]; then
    NEEDS_INSTALL=true
else
    # Re-check if requirements changed since last install
    if [ requirements.txt -nt "$STAMP" ]; then
        NEEDS_INSTALL=true
    fi
fi

if [ "$NEEDS_INSTALL" = true ]; then
    echo ""
    echo "  Installing Python dependencies..."
    if pip3 install -r requirements.txt --quiet; then
        touch "$STAMP"
        echo -e "  ${GREEN}Dependencies installed.${RESET}"
    else
        echo -e "${RED}  ERROR: pip install failed.${RESET}"
        echo "  Try manually:  pip3 install -r requirements.txt"
        echo ""
        read -p "  Press Enter to exit..."
        exit 1
    fi
fi

# ── 4. Optional AI layers check ──────────────────────────────────────────────
MISSING_OPTIONAL=""
python3 -c "import aubio" &>/dev/null   || MISSING_OPTIONAL="$MISSING_OPTIONAL aubio"
python3 -c "import librosa" &>/dev/null || MISSING_OPTIONAL="$MISSING_OPTIONAL librosa"
python3 -c "import torch" &>/dev/null   || MISSING_OPTIONAL="$MISSING_OPTIONAL torch"

if [ -n "$MISSING_OPTIONAL" ]; then
    echo ""
    echo -e "  ${YELLOW}Optional AI layers not installed:${RESET}$MISSING_OPTIONAL"
    echo "  TEAMMATE will run without them (graceful fallback)."
    echo "  To install:  pip3 install aubio librosa"
    echo "  For RAVE:    pip3 install torch --index-url https://download.pytorch.org/whl/cpu"
fi

# ── 5. Launch ─────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}${BOLD}Starting TEAMMATE.POTO...${RESET}"
echo ""

python3 TEAMMATE_MAC.POTO run "$@"

echo ""
read -p "  TEAMMATE stopped. Press Enter to close..."
