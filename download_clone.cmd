@echo off
rem   © 2018-2021 Rob Russell, SumWare Consulting
rem   Creative Commons licence
rem   Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
rem   https://creativecommons.org/licenses/by-sa/4.0/

rem Enable ANSI color support
for /F "delims=" %%A in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%A"

cls

rem Retrieve credentials from encrypted storage using PowerShell
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0get-fmcreds.ps1"') do %%i
if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to retrieve credentials%ESC%[0m
    exit /b 1
)

rem Call the PowerShell script to download and extract the clone file
powershell -ExecutionPolicy Bypass -File "%~dp0download_clone.ps1"
exit /b %ERRORLEVEL%
