@echo off
setlocal EnableExtensions

cd /d "%~dp0"

set "PACK_DIR=%CD%"

echo [1/2] Checking requirements...
where java >nul 2>nul
if errorlevel 1 (
  echo ERROR: Java not found in PATH. Install Java 17+ and run this file again.
  exit /b 1
)

if not exist "pakku.jar" (
  echo ERROR: pakku.jar not found in "%PACK_DIR%".
  exit /b 1
)

if not exist "pakku.json" (
  echo ERROR: pakku.json not found in "%PACK_DIR%".
  exit /b 1
)

echo [2/2] Fetching client mods into "%PACK_DIR%\mods"...
java -jar pakku.jar -y fetch -r 3
if errorlevel 1 (
  echo ERROR: pakku fetch failed.
  exit /b 1
)

echo.
echo Done.
echo Client is ready in: "%PACK_DIR%"
exit /b 0
