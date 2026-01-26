@echo off
rem   © 2018-2021 Rob Russell, SumWare Consulting
rem   Creative Commons licence
rem   Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
rem   https://creativecommons.org/licenses/by-sa/4.0/

rem Enable ANSI color support
for /F "delims=" %%A in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%A"

cls

rem Call the PowerShell script to download and extract the clone file
powershell -ExecutionPolicy Bypass -File "%~dp0ps1\download_clone.ps1"
exit /b %ERRORLEVEL%
