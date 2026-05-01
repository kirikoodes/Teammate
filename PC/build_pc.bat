@echo off
chcp 65001 >nul
echo.
echo   TEAMMATE.POTO — Windows build
echo   ──────────────────────────────
echo.

:: Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo   ERROR: Python not found.
    echo   Install Python 3.10, 3.11 or 3.12 from https://python.org
    echo   Make sure to check "Add Python to PATH" during install.
    pause
    exit /b 1
)

echo   Installing dependencies...
pip install numpy sounddevice mido python-rtmidi librosa pyinstaller --quiet
if errorlevel 1 (
    echo   ERROR: pip install failed.
    pause
    exit /b 1
)

echo.
echo   Building TEAMMATE.POTO.exe ...
pyinstaller TEAMMATE.POTO.spec --noconfirm
if errorlevel 1 (
    echo.
    echo   ERROR: PyInstaller build failed.
    pause
    exit /b 1
)

echo.
echo   Done! Your exe is in:  dist\TEAMMATE.POTO.exe
echo   Copy dist\TEAMMATE.POTO.exe + a rave_models\ folder to distribute.
echo.
pause
