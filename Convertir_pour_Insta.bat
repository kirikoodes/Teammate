@echo off
REM ============================================================
REM  Convertir pour Insta
REM  - Double-clic : convertit la DERNIERE capture du dossier Telechargements
REM  - Glisser-deposer un fichier sur l'icone : convertit ce fichier
REM  Sortie : ..._INSTA.mp4 (H.264 + AAC, lisible partout + Instagram)
REM ============================================================
setlocal enabledelayedexpansion

REM Localise ffmpeg (PATH, sinon chemin d'installation winget)
set "FF=ffmpeg"
where ffmpeg >nul 2>nul || set "FF=%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.2-full_build\bin\ffmpeg.exe"

REM Fichier d'entree : argument glisse-depose, sinon derniere capture
set "IN=%~1"
if "%IN%"=="" (
  for /f "delims=" %%F in ('dir /b /a-d /o-d "%USERPROFILE%\Downloads\capture-insta-*.mp4" 2^>nul ^| findstr /v /i "_INSTA"') do (
    set "IN=%USERPROFILE%\Downloads\%%F"
    goto :found
  )
)
:found
if "%IN%"=="" (
  echo Aucune video trouvee. Glisse un fichier sur cette icone, ou enregistre d'abord une capture.
  echo.
  pause
  exit /b
)

set "OUT=%~dpn1"
if "%~1"=="" set "OUT=%IN:.mp4=%"
set "OUT=%OUT%_INSTA.mp4"

echo.
echo   Entree : %IN%
echo   Sortie : %OUT%
echo   Conversion en cours...
echo.

REM Essai rapide : on garde la video H.264 telle quelle, on convertit juste l'audio en AAC
"%FF%" -y -i "%IN%" -c:v copy -c:a aac -b:a 192k -movflags +faststart "%OUT%"
if errorlevel 1 (
  echo.
  echo   Re-encodage complet necessaire...
  "%FF%" -y -i "%IN%" -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart "%OUT%"
)

echo.
echo   ====================================================
echo   Termine ! Fichier pret pour Instagram :
echo   %OUT%
echo   ====================================================
echo.
pause
endlocal
