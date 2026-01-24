@echo off
rem Test FileMaker Server Admin API connectivity

echo Testing FileMaker Server Admin API connectivity...
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0test-api.ps1"

echo.
pause
