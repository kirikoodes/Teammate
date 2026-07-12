@echo off
REM ============================================================
REM  CAPTURE INSTA - lanceur tout-en-un
REM  Demarre le serveur (conversion auto ffmpeg) + ouvre l'appli
REM  en mode application (fenetre propre, toujours a jour).
REM ============================================================
setlocal
cd /d "%~dp0"
REM Si les fichiers sont ranges dans un sous-dossier, on s'y place
if exist "CaptureInsta_App\serveur_insta.py" cd /d "%~dp0CaptureInsta_App"
set PORT=8777
set "URL=http://localhost:%PORT%/CaptureInsta.html"

REM --- Choisit python ou py ---
set "PY=python"
where python >nul 2>nul || set "PY=py"

REM --- Localise Chrome ---
set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"

REM --- Libere le port (tue tout ancien serveur encore actif) ---
for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":%PORT%" ^| findstr LISTENING') do taskkill /F /PID %%P >nul 2>nul

REM --- Demarre le serveur dans sa propre fenetre (a garder ouverte) ---
start "Serveur CaptureInsta - NE PAS FERMER" %PY% serveur_insta.py

REM --- Attend que le serveur reponde (max ~12s) ---
echo.
echo   Demarrage du serveur, patiente...
for /l %%i in (1,1,12) do (
  %PY% -c "import urllib.request; urllib.request.urlopen('%URL%',timeout=1)" >nul 2>nul && goto :ready
  ping -n 2 127.0.0.1 >nul
)
echo   (le serveur met du temps a repondre, on ouvre quand meme)
:ready

REM --- Ouvre l'appli en mode application (profil dedie = permissions memorisees) ---
if exist "%CHROME%" (
  start "" "%CHROME%" --app=%URL% --user-data-dir="%LOCALAPPDATA%\CaptureInstaProfile"
) else (
  start "" "%URL%"
)

echo.
echo   C'est parti ! Tes videos finales arrivent dans :
echo   %USERPROFILE%\Videos\CaptureInsta
echo.
timeout /t 4 >nul
endlocal
