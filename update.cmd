@echo off
rem   © 2018-2021 Rob Russell, SumWare Consulting
rem   Creative Commons licence
rem   Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
rem   https://creativecommons.org/licenses/by-sa/4.0/

rem Enable ANSI color support on Windows 10+ (Virtual Terminal Processing)
rem Generate ESC character (ASCII 27) for ANSI color codes
for /F "delims=" %%A in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%A"

rem %1 is file name  %2 is folder name

IF "%1"=="" exit /b

echo.
echo             processing %ESC%[101;93m%1%ESC%[0m in folder %2


SET ThisScriptsDirectory=%~dp0
SET sourcefolder=%ThisScriptsDirectory%
SET src="%sourcefolder%source\%1.fmp12"
SET bak="%sourcefolder%backup\"
SET cln="%sourcefolder%clone\athenaeum_clone.fmp12"
SET tgt="%sourcefolder%new\%1.fmp12"
SET log="%sourcefolder%log\%1.txt"

rem ============================================
rem Create required directories if they don't exist
rem ============================================
echo Checking required directories...

if NOT EXIST "%sourcefolder%source" (
    echo Creating source directory...
    mkdir "%sourcefolder%source"
    if %ERRORLEVEL% neq 0 (
        echo %ESC%[101;93mERROR: Failed to create source directory%ESC%[0m
        exit /b 1
    )
)

if NOT EXIST "%sourcefolder%backup" (
    echo Creating backup directory...
    mkdir "%sourcefolder%backup"
    if %ERRORLEVEL% neq 0 (
        echo %ESC%[101;93mERROR: Failed to create backup directory%ESC%[0m
        exit /b 1
    )
)

if NOT EXIST "%sourcefolder%clone" (
    echo Creating clone directory...
    mkdir "%sourcefolder%clone"
    if %ERRORLEVEL% neq 0 (
        echo %ESC%[101;93mERROR: Failed to create clone directory%ESC%[0m
        exit /b 1
    )
)

if NOT EXIST "%sourcefolder%new" (
    echo Creating new directory...
    mkdir "%sourcefolder%new"
    if %ERRORLEVEL% neq 0 (
        echo %ESC%[101;93mERROR: Failed to create new directory%ESC%[0m
        exit /b 1
    )
)

if NOT EXIST "%sourcefolder%log" (
    echo Creating log directory...
    mkdir "%sourcefolder%log"
    if %ERRORLEVEL% neq 0 (
        echo %ESC%[101;93mERROR: Failed to create log directory%ESC%[0m
        exit /b 1
    )
)

echo All required directories present
echo.

echo "delete log file %log%"
del /q %log%
set live=A:\live_databases\

rem Retrieve credentials from encrypted storage using PowerShell
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0get-fmcreds.ps1"') do %%i
if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to retrieve credentials%ESC%[0m
    exit /b 1
)

set myaccount=migrate
set mypassword=migrate

rem FileMaker Server settings
set fmhost=localhost
set dbfilename=%1.fmp12

if "%~1"=="" goto END0
if "%~2"=="" goto END0

rem ============================================
rem Step 1: Login to FileMaker Server Admin API
rem ============================================
echo.
echo %ESC%[102;30mStep 1: Authenticating with FileMaker Server...%ESC%[0m

for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation login -FileMakerHost "%fmhost%" -Username "%fmaccount%" -Password "%fmpassword%"') do set fmtoken=%%i

if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to authenticate with FileMaker Server%ESC%[0m
    echo %ESC%[101;93mCannot proceed with update%ESC%[0m
    exit /b 1
)

echo Token obtained successfully >> %log%

rem ============================================
rem Step 2: Close the database (force disconnect)
rem ============================================
echo.
echo %ESC%[102;30mStep 2: Closing database %dbfilename%...%ESC%[0m
echo Attempting to close: %dbfilename% >> %log%
echo FileMaker Host: %fmhost% >> %log%
echo. >> %log%

powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation close -FileMakerHost "%fmhost%" -Token "%fmtoken%" -DatabaseName "%dbfilename%" -ForceDisconnect -GracePeriod 0 >> %log% 2>&1

if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to close database %dbfilename%%ESC%[0m
    echo %ESC%[101;93mCannot proceed with update - database may be in use or not found%ESC%[0m
    echo.
    echo Check the log file for details: %log%
    echo.

    rem Logout from API
    powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation logout -FileMakerHost "%fmhost%" -Token "%fmtoken%" >> %log% 2>&1

    goto END0
)

echo Database closed successfully
echo Database closed successfully >> %log%

rem ============================================
rem Step 3: Copy live database to source folder
rem ============================================
echo.
echo %ESC%[102;30mStep 3: Copying live database to working directory...%ESC%[0m

echo "copy live to source folder"
copy "%live%%2\%1.fmp12" "%sourcefolder%source\" >> %log% 2>&1

if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to copy live database to source folder%ESC%[0m

    rem Try to reopen the database before exiting
    echo Attempting to reopen database...
    powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation open -FileMakerHost "%fmhost%" -Token "%fmtoken%" -DatabaseName "%dbfilename%" >> %log% 2>&1

    rem Logout from API
    powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation logout -FileMakerHost "%fmhost%" -Token "%fmtoken%" >> %log% 2>&1

    exit /b 1
)

rem ============================================
rem Step 4: Prepare for migration
rem ============================================
For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
set backup_stamp=%mydate%

echo "delete previous target %tgt%"
del /q "%tgt%" 2>nul

rem ============================================
rem Step 5: Run FileMaker Data Migration
rem ============================================
echo.
echo %ESC%[102;30mStep 4: Running FileMaker Data Migration...%ESC%[0m
echo "migrating"

FMDataMigration -src_path %src% -clone_path %cln% -src_account %myaccount% -src_pwd %mypassword% -clone_account %myaccount% -clone_pwd %mypassword% -target_path %tgt% -ignore_valuelists >>%log% 2>&1

if %ERRORLEVEL% neq 0 (
    echo.
    echo %ESC%[101;93mERROR: FileMaker Data Migration FAILED%ESC%[0m
    echo %ESC%[101;93m
    findstr /C:"error" /C:"Error" /C:"ERROR" /C:"failed" /C:"Failed" %log%
    echo %ESC%[0m

    rem Discard changes - delete failed target
    echo Discarding failed migration output...
    del /q "%tgt%" 2>nul

    rem Reopen the original database
    echo Reopening original database...
    powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation open -FileMakerHost "%fmhost%" -Token "%fmtoken%" -DatabaseName "%dbfilename%" >> %log% 2>&1

    if %ERRORLEVEL% neq 0 (
        echo %ESC%[101;93mWARNING: Failed to reopen database - manual intervention required%ESC%[0m
    ) else (
        echo Database reopened successfully
    )

    rem Logout from API
    powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation logout -FileMakerHost "%fmhost%" -Token "%fmtoken%" >> %log% 2>&1

    echo.
    echo %ESC%[101;93mUpdate aborted due to migration failure%ESC%[0m
    exit /b 1
)

echo.
echo "Migration completed - checking for errors..."
echo %ESC%[101;93m
findstr "error not invalid" %log%
echo %ESC%[0m
echo.

rem ============================================
rem Step 6: Remove old database from live folder
rem ============================================
echo.
echo %ESC%[102;30mStep 5: Removing old database from server...%ESC%[0m

echo "delete (old) live"
del "%live%%2\%1.fmp12" >> %log% 2>&1

if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mWARNING: Failed to delete old database file%ESC%[0m
    rem Continue anyway - we'll try to overwrite
)

rem ============================================
rem Step 7: Copy updated database to live folder
rem ============================================
echo.
echo %ESC%[102;30mStep 6: Copying updated database to server...%ESC%[0m

echo "copy updated file back to live"
copy "%tgt%" "%live%%2\" >> %log% 2>&1

if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to copy updated database to live folder%ESC%[0m
    echo %ESC%[101;93mCRITICAL: Database is closed but new version not deployed%ESC%[0m

    rem Logout from API
    powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation logout -FileMakerHost "%fmhost%" -Token "%fmtoken%" >> %log% 2>&1

    exit /b 1
)

rem ============================================
rem Step 8: Open the updated database
rem ============================================
echo.
echo %ESC%[102;30mStep 7: Opening updated database...%ESC%[0m

powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation open -FileMakerHost "%fmhost%" -Token "%fmtoken%" -DatabaseName "%dbfilename%" >> %log% 2>&1

if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to open updated database%ESC%[0m
    echo %ESC%[101;93mManual intervention may be required%ESC%[0m

    rem Logout from API
    powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation logout -FileMakerHost "%fmhost%" -Token "%fmtoken%" >> %log% 2>&1

    exit /b 1
)

echo Database opened successfully
echo Database opened successfully >> %log%

rem Wait for database to fully open
timeout /t 6 /nobreak

rem ============================================
rem Step 9: Logout from FileMaker Server Admin API
rem ============================================
echo.
echo %ESC%[102;30mStep 8: Logging out from FileMaker Server...%ESC%[0m

powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation logout -FileMakerHost "%fmhost%" -Token "%fmtoken%" >> %log% 2>&1

if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mWARNING: Logout failed (token may expire automatically)%ESC%[0m
)

echo.
echo %ESC%[102;30m===================================================%ESC%[0m
echo %ESC%[102;30mUpdate completed successfully for %dbfilename%%ESC%[0m
echo %ESC%[102;30m===================================================%ESC%[0m
echo.

GOTO END0

:END0

echo.
echo.
