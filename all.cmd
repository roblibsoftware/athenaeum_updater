@echo off
rem   © 2018-2021 Rob Russell, SumWare Consulting
rem   Creative Commons licence
rem   Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
rem   https://creativecommons.org/licenses/by-sa/4.0/

rem Enable ANSI color support
for /F "delims=" %%A in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%A"

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

SET clonefile=athenaeum_clone.fmp12
SET ThisScriptsDirectory=%~dp0
SET clonepath="%sourcefolder%clone\%clonefile%"

rem Retrieve credentials from encrypted storage using PowerShell
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0get-fmcreds.ps1"') do %%i
if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to retrieve credentials%ESC%[0m
    exit /b 1
)


IF NOT EXIST %clonepath% (
    Echo %ESC%[101;93m%clonepath not downloaded, aborting%ESC%[0m
    exit /b 1
 )

rem Remove previous skipped file log
IF EXIST skipped.txt del skipped.txt

echo.
echo %ESC%[102;30mStarting batch update of all databases...%ESC%[0m
echo.

rem Note: Client disconnect is now handled by update.cmd for each specific database
rem This ensures only clients connected to the database being updated are disconnected

rem Read master_file_list.txt, skipping blank lines and comments
for /F "usebackq tokens=1,2" %%i in (master_file_list.txt) do (
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
                echo Processing: %%i %%j
                call update.cmd %%i %%j

                rem Check if update.cmd failed
                if %ERRORLEVEL% neq 0 (
                    echo %ESC%[101;93mWARNING: update.cmd failed for %%i %%j with error code %ERRORLEVEL%%ESC%[0m
                    echo %%i %%j failed with error code %ERRORLEVEL% >> skipped.txt
                    rem Uncomment next line to abort on first update.cmd error:
                    rem exit /b %ERRORLEVEL%
                )
            )
        )
    )
)

rem List log lines that include "open", "close", "Start"
echo.
echo.
echo %ESC%[102;30mSummary of operations:%ESC%[0m
findstr /I "open clos Start" log\*.txt

echo.
echo %ESC%[101;93m
IF EXIST skipped.txt (
    echo Files that failed to update:
    TYPE skipped.txt
) ELSE (
    echo All files updated successfully
)
echo %ESC%[0m

echo.
echo %ESC%[102;30mBatch update process complete.%ESC%[0m
exit /b 0
