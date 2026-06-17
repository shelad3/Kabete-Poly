#!/usr/bin/env bash
# setup.sh — One-command setup for KNP Admin Tool
# Detects OS, creates venv, installs deps, launches the app.

set -e

echo "=== KNP Admin Tool — Setup ==="

# ---- Detect OS ----
OS="linux"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || -n "$WINDIR" ]]; then
    OS="windows"
fi

echo "Detected OS: $OS"

# ---- Find Python ----
if command -v python3 &>/dev/null; then
    PYTHON=python3
elif command -v python &>/dev/null; then
    PYTHON=python
else
    echo "ERROR: Python not found. Install Python 3.12+ from python.org"
    exit 1
fi

echo "Using: $($PYTHON --version)"

# ---- Create venv if missing ----
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    $PYTHON -m venv venv
fi

# ---- Activate ----
if [[ "$OS" == "windows" ]]; then
    source venv/Scripts/activate
else
    source venv/bin/activate
fi

# ---- Install dependencies ----
echo "Installing dependencies..."
pip install -r requirements.txt

# ---- Linux: install libxcb-cursor0 if missing ----
if [[ "$OS" == "linux" ]]; then
    if ! ldconfig -p | grep -q libxcb-cursor; then
        echo "Installing libxcb-cursor0 (required for PyQt6)..."
        if command -v sudo &>/dev/null; then
            sudo apt install -y libxcb-cursor0
        else
            echo "WARNING: libxcb-cursor0 not found. Run: sudo apt install libxcb-cursor0"
        fi
    fi
fi

# ---- Launch ----
echo ""
echo "=== Launching KNP Admin Tool ==="
$PYTHON main.py
