@echo off
setlocal EnableExtensions

echo TSK Skin Swap - Android installer
echo.
echo Connect the phone and allow USB debugging when prompted.
echo.

if not exist "%~dp0Apply-TskSkinSwap-Android.ps1" goto missing_files

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-TskSkinSwap-Android.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" goto failed
echo Installation completed. The game has been restarted.
goto finished

:failed
echo Installation failed with exit code %EXIT_CODE%.
echo Check the message above and run this file again.
goto finished

:missing_files
set "EXIT_CODE=2"
echo Required files are missing.
echo Extract the entire release ZIP to a normal folder, then run this BAT again.

:finished
echo.
pause
exit /b %EXIT_CODE%
