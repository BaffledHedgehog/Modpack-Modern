@echo off
setlocal EnableExtensions

cd /d "%~dp0"

set "PACK_DIR=%CD%"
set "SERVER_DIR=C:\Users\yarik_temp\Desktop\terrafirmagreg_server"
set "BUILD_DIR=%PACK_DIR%\build"
set "LOG_FILE=%BUILD_DIR%\pakku-server-build.log"
set "SRC_MODS=%PACK_DIR%\mods"
set "DST_MODS=%SERVER_DIR%\mods"

echo [1/6] Checking requirements...
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

if not exist "%BUILD_DIR%" (
  mkdir "%BUILD_DIR%"
)

echo [2/6] Fetching mods required for server export...
echo ===== %DATE% %TIME% : pakku fetch =====> "%LOG_FILE%"
java -jar pakku.jar -y fetch -r 3 >> "%LOG_FILE%" 2>&1
if errorlevel 1 (
  echo ERROR: pakku fetch failed. See log: "%LOG_FILE%"
  powershell -NoProfile -Command "Get-Content -Path $env:LOG_FILE -Tail 60"
  exit /b 1
)

echo [3/6] Preparing server folder...
if not exist "%SERVER_DIR%" (
  mkdir "%SERVER_DIR%"
  if errorlevel 1 (
    echo ERROR: Failed to create "%SERVER_DIR%".
    exit /b 1
  )
)

echo [4/6] Syncing shared/server overrides (world is preserved)...
call :mirror_dir config
if errorlevel 1 exit /b 1
call :mirror_dir defaultconfigs
if errorlevel 1 exit /b 1
call :mirror_dir kubejs
if errorlevel 1 exit /b 1
call :mirror_dir tacz
if errorlevel 1 exit /b 1

if exist "%SERVER_DIR%\kubejs\assets" rmdir /s /q "%SERVER_DIR%\kubejs\assets"
if exist "%SERVER_DIR%\kubejs\probe" rmdir /s /q "%SERVER_DIR%\kubejs\probe"
if exist "%SERVER_DIR%\defaultconfigs\tfc-server.toml" del /q "%SERVER_DIR%\defaultconfigs\tfc-server.toml"
if exist "%SERVER_DIR%\config\ftbbackups2.json" del /q "%SERVER_DIR%\config\ftbbackups2.json"
if exist "%SERVER_DIR%\defaultconfigs\ftbranks\ranks.snbt" del /q "%SERVER_DIR%\defaultconfigs\ftbranks\ranks.snbt"

robocopy "%PACK_DIR%\.pakku\server-overrides" "%SERVER_DIR%" /E /R:2 /W:2 /NFL /NDL /NP /NJH /NJS ^
  /XF "eula.txt" "server.properties" "usercache.json" "ops.json" "whitelist.json" "banned-ips.json" "banned-players.json"
if errorlevel 8 (
  echo ERROR: Failed to sync server overrides.
  exit /b 1
)

call :patch_fss_config
if errorlevel 1 exit /b 1

echo.
echo [5/6] Building server mods list from pakku-lock.json...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $lock = Get-Content -Raw (Join-Path $env:PACK_DIR 'pakku-lock.json') | ConvertFrom-Json; $src = Join-Path $env:PACK_DIR 'mods'; $dst = Join-Path $env:SERVER_DIR 'mods'; New-Item -ItemType Directory -Path $dst -Force | Out-Null; Get-ChildItem -Path $dst -File -ErrorAction SilentlyContinue | Remove-Item -Force; $copied = 0; $missing = 0; foreach($prj in $lock.projects){ if($prj.type -ne 'MOD' -or $prj.side -eq 'CLIENT'){ continue }; $picked = $null; foreach($f in $prj.files){ if(-not $f.file_name){ continue }; $candidate = Join-Path $src $f.file_name; if(Test-Path -LiteralPath $candidate){ $picked = $candidate; break } }; if($picked){ Copy-Item -LiteralPath $picked -Destination (Join-Path $dst ([System.IO.Path]::GetFileName($picked))) -Force; $copied++ } else { $missing++ } }; Write-Host ('Copied server-side mods: ' + $copied); if($missing -gt 0){ Write-Warning ('Missing files for projects: ' + $missing) }"
if errorlevel 1 (
  echo ERROR: Failed to build server mod list from pakku-lock.json.
  exit /b 1
)

echo [6/6] Finalizing...

echo Done.
echo Server is ready in: "%SERVER_DIR%"
echo Server start file: "%SERVER_DIR%\start_server.bat"
echo Build log: "%LOG_FILE%"
echo World data was not touched.

exit /b 0

:mirror_dir
set "SUBDIR=%~1"
if exist "%PACK_DIR%\%SUBDIR%" (
  robocopy "%PACK_DIR%\%SUBDIR%" "%SERVER_DIR%\%SUBDIR%" /MIR /R:2 /W:2 /NFL /NDL /NP /NJH /NJS >nul
  if errorlevel 8 (
    echo ERROR: Failed to sync "%SUBDIR%".
    exit /b 1
  )
)
exit /b 0

:patch_fss_config
set "FORGE_AUTO=%SERVER_DIR%\forge-auto-install.txt"
if not exist "%FORGE_AUTO%" exit /b 0

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $lock = Get-Content -Raw (Join-Path $env:PACK_DIR 'pakku-lock.json') | ConvertFrom-Json; $mc = $lock.mc_versions[0]; if(-not $mc){ throw 'No mc_versions in pakku-lock.json' }; $loaderName = $null; $loaderVersion = $null; foreach($p in $lock.loaders.PSObject.Properties){ $loaderName = $p.Name; $loaderVersion = [string]$p.Value; break }; if(-not $loaderName -or -not $loaderVersion){ throw 'No loaders in pakku-lock.json' }; $loaderType = switch ($loaderName.ToLower()) { 'forge' { 'Forge' } 'neoforge' { 'NeoForge' } default { $loaderName } }; $file = Join-Path $env:SERVER_DIR 'forge-auto-install.txt'; $text = Get-Content -Raw $file; $text = $text.Replace('minecraftVersion=MINECRAFT_VERSION', 'minecraftVersion=' + $mc); $text = $text.Replace('loaderType=LOADER_TYPE', 'loaderType=' + $loaderType); $text = $text.Replace('loaderVersion=LOADER_VERSION', 'loaderVersion=' + $loaderVersion); Set-Content -Path $file -Value $text -NoNewline; Write-Host ('Patched forge-auto-install.txt: mc=' + $mc + ', loader=' + $loaderType + ' ' + $loaderVersion)"
if errorlevel 1 (
  echo ERROR: Failed to patch forge-auto-install.txt from pakku-lock.json.
  exit /b 1
)
exit /b 0
