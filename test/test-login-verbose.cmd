@echo off
rem Verbose login test - shows all headers and details

echo Verbose FileMaker Server login test...
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0test-login-verbose.ps1" localhost

echo.
echo.
pause
