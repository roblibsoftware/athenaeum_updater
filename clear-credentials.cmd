@echo off
rem Clear FileMaker credentials helper
rem This is a wrapper that properly calls the PowerShell script

rem Enable ANSI color support
for /F "delims=" %%A in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%A"

echo FileMaker Credential Removal
echo ================================
echo.
echo This will delete the encrypted credential file: fmcreds.encrypted
echo You will need to run store-credentials.cmd again to recreate them.
echo.

set /p confirm="Are you sure you want to delete the credentials? (yes/no): "

if /i "%confirm%"=="yes" (
    if exist fmcreds.encrypted (
        del /q fmcreds.encrypted
        echo.
        echo %ESC%[102;30mSUCCESS: Encrypted credentials have been removed.%ESC%[0m
        echo.
        echo To create new credentials, run: store-credentials.cmd
    ) else (
        echo.
        echo %ESC%[101;93mNo credential file found.%ESC%[0m
        echo Nothing to clear.
    )
) else (
    echo.
    echo Operation cancelled.
)

echo.
pause
