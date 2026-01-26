@echo off
echo Testing close then open (no file replacement)...
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0test-close-open.ps1"

echo.
pause
