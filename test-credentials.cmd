@echo off
rem Test FileMaker credentials helper
rem This retrieves and displays the stored credentials

echo Testing FileMaker Credential Retrieval
echo ========================================
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0get-fmcreds.ps1"

if %ERRORLEVEL% neq 0 (
    echo.
    echo [101;93mERROR: Failed to retrieve credentials[0m
    echo.
    echo Please run store-credentials.cmd to set up credentials first.
) else (
    echo.
    echo [102;30mCredentials retrieved successfully![0m
)

echo.
pause
