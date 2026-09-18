@echo off
REM ============================================================
REM  POSE MIROIR - lanceur
REM  Sert le dossier en local (la camera exige localhost) et ouvre
REM  l'appli en mode application Chrome.
REM ============================================================
setlocal
cd /d "%~dp0"
set PORT=8790
set "URL=http://localhost:%PORT%/PoseMiroir.html"

set "PY=python"
where python >nul 2>nul || set "PY=py"

set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"

for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":%PORT%" ^| findstr LISTENING') do taskkill /F /PID %%P >nul 2>nul

start "Serveur PoseMiroir - NE PAS FERMER" %PY% -m http.server %PORT% --bind 127.0.0.1
ping -n 3 127.0.0.1 >nul

if exist "%CHROME%" (
  start "" "%CHROME%" --app=%URL% --user-data-dir="%LOCALAPPDATA%\PoseMiroirProfile"
) else (
  start "" "%URL%"
)
endlocal
