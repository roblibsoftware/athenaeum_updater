@echo off
rem   © 2018-2021 Rob Russell, SumWare Consulting
rem   Creative Commons licence
rem   Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
rem   https://creativecommons.org/licenses/by-sa/4.0/

rem Enable ANSI color support
for /F "delims=" %%A in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%A"

cls
SET downloadurl="https://librarysoftware.co.nz/download/up/athenaeum_clone.fmp12.zip"
SET clonefile=athenaeum_clone.fmp12
SET ThisScriptsDirectory=%~dp0
SET sourcefolder=%ThisScriptsDirectory%
SET downloadzip="%sourcefolder%%clonefile%.zip"
SET downloadfile="%sourcefolder%clone\%clonefile%"

SET curl="C:\Program Files\curl\bin\curl.exe"
SET unzipper="C:\Program Files\7-Zip\7z.exe"

rem Check if required tools exist
if not exist %curl% (
    echo %ESC%[101;93mERROR: curl.exe not found at %curl%%ESC%[0m
    exit /b 1
)

if not exist %unzipper% (
    echo %ESC%[101;93mERROR: 7z.exe not found at %unzipper%%ESC%[0m
    exit /b 2
)

rem Create clone directory if it doesn't exist
if not exist clone mkdir clone

del /q zip.log 2>nul
del /q %downloadzip% 2>nul
del /q %downloadfile% 2>nul

echo.
echo Downloading clone file...

rem Download the zipped clone file
%curl% %downloadurl% --output %downloadzip% --fail --silent --show-error
if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to download file from %downloadurl%%ESC%[0m
    echo %ESC%[101;93mCurl exit code: %ERRORLEVEL%%ESC%[0m
    exit /b 3
)

rem Verify the download exists
if not exist %downloadzip% (
    echo %ESC%[101;93mERROR: Downloaded file not found: %downloadzip%%ESC%[0m
    exit /b 4
)

echo Unzipping file...

rem Unzip it
%unzipper% x %downloadzip% %clonefile% -o"%sourcefolder%" -y > zip.log 2>&1
if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to unzip file%ESC%[0m
    echo %ESC%[101;93m7-Zip exit code: %ERRORLEVEL%%ESC%[0m
    type zip.log
    exit /b 5
)

rem Check for successful extraction
findstr /c:"Everything is Ok" zip.log >nul
if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Extraction did not complete successfully%ESC%[0m
    type zip.log
    exit /b 6
)

echo %ESC%[102;30mExtraction successful%ESC%[0m

rem Move it into the clone folder
move /y %clonefile% clone >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to move file to clone folder%ESC%[0m
    exit /b 7
)

rem Clean up
del /q %downloadzip% 2>nul
del /q zip.log 2>nul

echo.
echo %ESC%[102;30mClone file downloaded and extracted successfully%ESC%[0m
echo.

rem Case insensitive grep the directory looking for the word "athen"
echo Files in clone directory:
echo %ESC%[101;93m
dir clone\a*.* | findstr /I "athen"
echo %ESC%[0m

exit /b 0
