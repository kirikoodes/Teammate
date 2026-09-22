@echo off
REM ============================================================
REM  SYNAPSE - instrument d'ambiance par prompt (voix ou texte)
REM  Demarre le serveur local + ouvre l'appli en mode application
REM ============================================================
setlocal
cd /d "%~dp0"
set PORT=8778
set "URL=http://localhost:%PORT%/Synapse.html"

set "PY=python"
where python >nul 2>nul || set "PY=py"

set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"

for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":%PORT%" ^| findstr LISTENING') do taskkill /F /PID %%P >nul 2>nul

start "Serveur SYNAPSE - NE PAS FERMER" %PY% serveur_synapse.py

echo.
echo   Demarrage du serveur, patiente...
for /l %%i in (1,1,12) do (
  %PY% -c "import urllib.request; urllib.request.urlopen('%URL%',timeout=1)" >nul 2>nul && goto :ready
  ping -n 2 127.0.0.1 >nul
)
:ready

REM profil dedie = la permission micro est memorisee
if exist "%CHROME%" (
  start "" "%CHROME%" --app=%URL% --user-data-dir="%LOCALAPPDATA%\SynapseProfile"
) else (
  start "" "%URL%"
)
timeout /t 3 >nul
endlocal
