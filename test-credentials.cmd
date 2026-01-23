@echo off
rem Test FileMaker credentials helper
rem This retrieves and displays the stored credentials

rem Enable ANSI color support
for /F "delims=" %%A in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%A"

echo Testing FileMaker Credential Retrieval
echo ========================================
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0get-fmcreds.ps1"

if %ERRORLEVEL% neq 0 (
    echo.
    echo %ESC%[101;93mERROR: Failed to retrieve credentials%ESC%[0m
    echo.
    echo Please run store-credentials.cmd to set up credentials first.
) else (
    echo.
    echo %ESC%[102;30mCredentials retrieved successfully!%ESC%[0m
)

echo.
pause
