@echo off
setlocal EnableExtensions

cd /d "%~dp0"

echo [1/2] Building client...
call "%~dp0build_client_only.bat"
if errorlevel 1 (
  echo ERROR: Client build failed.
  exit /b 1
)

echo.
echo [2/2] Building server...
call "%~dp0build_server_only.bat"
if errorlevel 1 (
  echo ERROR: Server build failed.
  exit /b 1
)

echo.
echo Done.
exit /b 0
