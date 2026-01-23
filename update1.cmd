@echo off
rem Enable ANSI color support
for /F "tokens=* USEBACKQ" %%F in (`powershell -NoProfile -Command "write-host([char]27) -NoNewLine"`) do (set "ESC=%%F")

rem Download clone file first
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

rem Read one_file_list.txt, skipping blank lines and comments
for /F "usebackq tokens=1,2" %%i in (one_file_list.txt) do (
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

                rem Optional: Check if update.cmd failed
                if %ERRORLEVEL% neq 0 (
                    echo %ESC%[101;93mWARNING: update.cmd failed for %%i %%j with error code %ERRORLEVEL%%ESC%[0m
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
