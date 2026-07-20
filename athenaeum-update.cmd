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
rem Normal run: download the clone file first
rem ============================================
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

rem Read file_list.txt, skipping blank lines and comments
for /F "usebackq tokens=1" %%i in ("%~dp0file_list.txt") do (
    rem Skip lines starting with # ; or rem (comments)
    echo %%i | findstr /b /r "^#" >nul && (
        echo Skipping comment: %%i
    ) || (
        echo %%i | findstr /b /r "^;" >nul && (
            echo Skipping comment: %%i
        ) || (
            echo %%i | findstr /b /r /i "^rem" >nul && (
                echo Skipping comment: %%i
            ) || (
                echo Processing: %%i
                call update.cmd %%i

                rem Optional: Check if update.cmd failed
                if %ERRORLEVEL% neq 0 (
                    echo %ESC%[101;93mWARNING: update.cmd failed for %%i with error code %ERRORLEVEL%%ESC%[0m
                    rem Uncomment next line to abort on update.cmd errors:
                    rem exit /b %ERRORLEVEL%
                )
            )
        )
    )
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

rem --- Step 1: configuration files ---
echo %ESC%[102;30mStep 1: Checking configuration files...%ESC%[0m

if exist "%~dp0host.txt" (
    set /p fmhost=<"%~dp0host.txt"
    echo   [OK] host.txt found
) else (
    set fmhost=localhost
    echo %ESC%[101;93m  [!] host.txt not found - would default to localhost%ESC%[0m
)
echo       FileMaker host: %fmhost%

if exist "%~dp0live.txt" (
    set /p livepath=<"%~dp0live.txt"
)
if exist "%~dp0live.txt" (
    echo   [OK] live.txt found
    echo       Live folder: %livepath%
) else (
    echo %ESC%[101;93m  [!] live.txt not found - update.cmd would use its built-in default%ESC%[0m
)

if exist "%~dp0file_list.txt" (
    echo   [OK] file_list.txt found
) else (
    echo %ESC%[101;93m  [X] ERROR: file_list.txt not found%ESC%[0m
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
    echo %ESC%[101;93m      Check host.txt, network connectivity, and credentials%ESC%[0m
    echo.
    pause
    exit /b 1
)
echo   [OK] Authenticated with %fmhost%
echo.

rem --- Step 4: list databases on the server (uses the token from step 3) ---
echo %ESC%[102;30mStep 4: Databases on the FileMaker Server...%ESC%[0m
echo       (compare these names against file_list.txt)
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
