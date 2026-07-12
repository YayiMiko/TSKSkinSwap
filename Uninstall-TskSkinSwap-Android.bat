@echo off
setlocal EnableExtensions

echo TSK Skin Swap - Android uninstaller
echo Downloaded transform bundles will be kept for reuse.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-TskSkinSwap-Android.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" goto failed
echo Uninstall completed. The original animations are active again.
goto finished

:failed
echo Uninstall failed with exit code %EXIT_CODE%.

:finished
echo.
pause
exit /b %EXIT_CODE%
