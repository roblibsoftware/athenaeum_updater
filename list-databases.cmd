@echo off
rem List all databases on FileMaker Server
rem Helps diagnose database name issues

rem Enable ANSI color support
for /F "delims=" %%A in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%A"

echo.
echo %ESC%[102;30mFileMaker Server Database List%ESC%[0m
echo ================================
echo.

rem Retrieve credentials from encrypted storage using PowerShell
rem Redirect stderr to prevent error messages from being executed as commands
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0ps1\get-fmcreds.ps1" 2^>nul') do %%i
if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to retrieve credentials%ESC%[0m
    echo %ESC%[101;93mPlease run store-credentials.cmd to set up credentials first%ESC%[0m
    pause
    exit /b 1
)

rem Read FileMaker host from host.txt, default to localhost if not found
if exist "%~dp0host.txt" (
    set /p fmhost=<"%~dp0host.txt"
) else (
    set fmhost=localhost
)

echo Connecting to: %fmhost%
echo.

rem Get authentication token
rem Redirect stderr to prevent error messages from being executed as commands
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0ps1\fmadmin-api.ps1" -Operation login -FileMakerHost "%fmhost%" -Username "%fmaccount%" -Password "%fmpassword%" 2^>nul') do set fmtoken=%%i

if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to authenticate%ESC%[0m
    pause
    exit /b 1
)

echo Authentication successful
echo.
echo Fetching database list...
echo.

rem List databases via the shared Admin API helper (uses the compiled cert
rem callback, which handles the server's TLS renegotiation reliably)
powershell -ExecutionPolicy Bypass -File "%~dp0ps1\fmadmin-api.ps1" -Operation list -FileMakerHost "%fmhost%" -Token "%fmtoken%"

echo.
echo.

rem Logout
powershell -ExecutionPolicy Bypass -File "%~dp0ps1\fmadmin-api.ps1" -Operation logout -FileMakerHost "%fmhost%" -Token "%fmtoken%" >nul 2>&1

echo.
pause
