@echo off
echo Testing database open operation...
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0test-open.ps1"

echo.
pause
