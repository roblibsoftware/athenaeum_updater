@echo off
rem Store FileMaker credentials helper
rem This is a wrapper that properly calls the PowerShell script

powershell -ExecutionPolicy Bypass -File "%~dp0store-fmcreds.ps1"

echo.
pause
