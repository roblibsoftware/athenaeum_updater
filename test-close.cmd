@echo off
echo Testing database close operation...
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0test-close.ps1"

echo.
pause
