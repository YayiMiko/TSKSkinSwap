@echo off
setlocal
chcp 65001 >nul

set "TOOL_DIR=%~dp0"
for %%I in ("%TOOL_DIR%..\..") do set "GAME_DIR=%%~fI"

set "MODE="
if /I "%~1"=="--full" set "MODE=Full"
if /I "%~1"=="--disable" set "MODE=Disable"

if not defined MODE (
    echo TSK Skin Swap
    echo.
    echo [1] Complete uninstall - remove the MOD, downloaded resources, and unused BepInEx files
    echo [2] Disable only - keep downloaded resources for a faster reinstall
    echo [Q] Cancel
    echo.
    choice /C 12Q /N /M "Select an option: "
    if errorlevel 3 exit /b 0
    if errorlevel 2 (
        set "MODE=Disable"
    ) else (
        set "MODE=Full"
    )
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TOOL_DIR%Uninstall-TskSkinSwap.ps1" -GamePath "%GAME_DIR%" -Mode "%MODE%"
set "EXIT_CODE=%ERRORLEVEL%"
echo.

if not "%EXIT_CODE%"=="0" (
    echo Uninstall failed with exit code %EXIT_CODE%.
    echo Close the game, check the message above, and run this file again.
    echo.
    pause
    exit /b %EXIT_CODE%
)

if /I "%MODE%"=="Disable" (
    echo TskSkinSwap is disabled. Run Apply-TskSkinSwap.bat to enable it again.
    echo.
    pause
    exit /b 0
)

if exist "%TOOL_DIR%.git" (
    echo Complete uninstall finished. A Git checkout was detected, so the source folder was preserved.
    echo.
    pause
    exit /b 0
)
echo Complete uninstall finished. The TskSkinSwap folder will now be removed.
powershell.exe -NoProfile -Command "Start-Sleep -Seconds 3"
set "TSK_CLEANUP_DIR=%TOOL_DIR%"
start "" /b powershell.exe -NoProfile -WindowStyle Hidden -Command "$target=[IO.Path]::GetFullPath($env:TSK_CLEANUP_DIR).TrimEnd([IO.Path]::DirectorySeparatorChar); $mods=Split-Path $target -Parent; $game=Split-Path $mods -Parent; Set-Location -LiteralPath $env:TEMP; Start-Sleep -Seconds 2; if ((Split-Path $target -Leaf) -eq 'TskSkinSwap' -and (Split-Path $mods -Leaf) -eq 'mods' -and (Test-Path (Join-Path $game 'twinkle_starknightsX.exe'))) { Remove-Item -LiteralPath $target -Recurse -Force }"
exit /b %EXIT_CODE%
