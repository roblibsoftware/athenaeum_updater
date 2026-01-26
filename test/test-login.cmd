@echo off
rem Test FileMaker Server Admin API login with actual credentials

echo Testing FileMaker Server login...
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0test-login.ps1"

echo.
pause
