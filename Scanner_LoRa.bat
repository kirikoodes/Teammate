@echo off
REM Lanceur du scanner de noeuds Meshtastic 868.
REM Double-clique simplement sur ce fichier.
cd /d "%~dp0"

REM Cherche Python : d'abord le launcher 'py', sinon le chemin d'install connu
where py >nul 2>nul
if %errorlevel%==0 (
    py scan_lora_868.py --secs 60
) else if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" (
    "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" scan_lora_868.py --secs 60
) else (
    echo [!] Python introuvable. Reinstalle Python ou corrige le chemin dans ce .bat
)

echo.
pause
