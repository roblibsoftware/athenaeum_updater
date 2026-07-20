@echo off
rem Enable ANSI color support
for /F "delims=" %%A in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%A"

rem ============================================
rem Parse arguments - detect dry-run mode
rem A dry run validates configuration, credentials, download capability
rem and the server connection, and lists the databases on the server -
rem without downloading the clone or changing any database.
rem   Usage:  athenaeum-update.cmd /dryrun
rem ============================================
set "DRYRUN="
if /i "%~1"=="/dryrun"   set "DRYRUN=1"
if /i "%~1"=="-dryrun"   set "DRYRUN=1"
if /i "%~1"=="--dry-run" set "DRYRUN=1"
if /i "%~1"=="/d"        set "DRYRUN=1"

if defined DRYRUN goto DRYRUN

rem ============================================
rem Normal run: validate config, download the clone, then update each file
rem ============================================

rem Validate configuration up front (config.json is compulsory)
set "fmhost="
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0ps1\get-config.ps1" -Key host') do set "fmhost=%%i"
if not defined fmhost (
    echo.
    echo %ESC%[101;93mERROR: Could not read configuration from config.json%ESC%[0m
    echo %ESC%[101;93mAborting update process.%ESC%[0m
    echo.
    pause
    exit /b 1
)

call download_clone.cmd

rem Check if download_clone failed
if %ERRORLEVEL% neq 0 (
    echo.
    echo %ESC%[101;93mERROR: download_clone.cmd failed with error code %ERRORLEVEL%%ESC%[0m
    echo %ESC%[101;93mAborting update process.%ESC%[0m
    echo.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo %ESC%[102;30mStarting file updates...%ESC%[0m
echo.

rem Read the list of files to update from config.json
set "ANYFILE="
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0ps1\get-config.ps1" -Key files') do (
    set "ANYFILE=1"
    echo Processing: %%i
    call update.cmd %%i

    rem Optional: Check if update.cmd failed
    if %ERRORLEVEL% neq 0 (
        echo %ESC%[101;93mWARNING: update.cmd failed for %%i with error code %ERRORLEVEL%%ESC%[0m
        rem Uncomment next line to abort on update.cmd errors:
        rem exit /b %ERRORLEVEL%
    )
)

if not defined ANYFILE (
    echo %ESC%[101;93mERROR: config.json has no files to process%ESC%[0m
    exit /b 1
)

echo.
echo %ESC%[102;30mUpdate process complete.%ESC%[0m
exit /b 0

rem ============================================
rem Dry run: pre-flight checks (no changes made)
rem ============================================
:DRYRUN
echo.
echo %ESC%[103;30m*** DRY RUN - validating setup, no changes will be made ***%ESC%[0m
echo.

rem --- Step 1: configuration (config.json) ---
echo %ESC%[102;30mStep 1: Checking config.json...%ESC%[0m

set "fmhost="
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0ps1\get-config.ps1" -Key host') do set "fmhost=%%i"
if not defined fmhost (
    echo %ESC%[101;93m  [X] ERROR: could not read 'host' from config.json%ESC%[0m
    echo.
    pause
    exit /b 1
)
echo   [OK] host: %fmhost%

set "livepath="
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0ps1\get-config.ps1" -Key live') do set "livepath=%%i"
if not defined livepath (
    echo %ESC%[101;93m  [X] ERROR: could not read 'live' from config.json%ESC%[0m
    echo.
    pause
    exit /b 1
)
echo   [OK] live: %livepath%

set "ANYFILE="
echo   Files to update:
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0ps1\get-config.ps1" -Key files') do (
    set "ANYFILE=1"
    echo       - %%i
)
if not defined ANYFILE (
    echo %ESC%[101;93m  [X] ERROR: config.json has no files to process%ESC%[0m
    echo.
    pause
    exit /b 1
)
echo.

rem --- Step 2: stored credentials ---
echo %ESC%[102;30mStep 2: Checking stored credentials...%ESC%[0m
set "fmaccount="
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0ps1\get-fmcreds.ps1" 2^>nul') do %%i
if not defined fmaccount (
    echo %ESC%[101;93m  [X] ERROR: Could not retrieve credentials%ESC%[0m
    echo %ESC%[101;93m      Run store-credentials.cmd to set them up%ESC%[0m
    echo.
    pause
    exit /b 1
)
echo   [OK] Credentials retrieved successfully
echo.

rem --- Step 3: connect to FileMaker Server ---
echo %ESC%[102;30mStep 3: Connecting to FileMaker Server...%ESC%[0m
set "fmtoken="
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0ps1\fmadmin-api.ps1" -Operation login -FileMakerHost "%fmhost%" -Username "%fmaccount%" -Password "%fmpassword%" 2^>nul') do set fmtoken=%%i
if not defined fmtoken (
    echo %ESC%[101;93m  [X] ERROR: Could not authenticate with %fmhost%%ESC%[0m
    echo %ESC%[101;93m      Check the host in config.json, network connectivity, and credentials%ESC%[0m
    echo.
    pause
    exit /b 1
)
echo   [OK] Authenticated with %fmhost%
echo.

rem --- Step 4: list databases on the server (uses the token from step 3) ---
echo %ESC%[102;30mStep 4: Databases on the FileMaker Server...%ESC%[0m
echo       (compare these names against the files in config.json)
powershell -ExecutionPolicy Bypass -File "%~dp0ps1\fmadmin-api.ps1" -Operation list -FileMakerHost "%fmhost%" -Token "%fmtoken%"

rem Log out and clean up the temporary token file
powershell -ExecutionPolicy Bypass -File "%~dp0ps1\fmadmin-api.ps1" -Operation logout -FileMakerHost "%fmhost%" -Token "%fmtoken%" >nul 2>&1
if exist "%~dp0fmtoken.tmp" del /q "%~dp0fmtoken.tmp"
echo.

rem --- Step 5: download capability (confirm the host domain is reachable / not firewall-blocked) ---
echo %ESC%[102;30mStep 5: Testing download capability...%ESC%[0m
powershell -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { $r = Invoke-WebRequest -Uri 'https://librarysoftware.co.nz/downloads/build.txt' -UseBasicParsing -ErrorAction Stop; Write-Host \"  [OK] Download capability confirmed (test file: $($r.Content.Trim()))\" -ForegroundColor Green } catch { Write-Host \"  [X] Download test failed: $($_.Exception.Message)\" -ForegroundColor Red; exit 1 }"
if errorlevel 1 (
    echo %ESC%[101;93m      Check network connectivity to librarysoftware.co.nz%ESC%[0m
)
echo.

echo %ESC%[103;30mDry run complete - no changes were made.%ESC%[0m
exit /b 0
