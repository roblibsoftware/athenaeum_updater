@echo off
rem   © 2018-2021 Rob Russell, SumWare Consulting
rem   Creative Commons licence
rem   Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
rem   https://creativecommons.org/licenses/by-sa/4.0/

call download_clone.cmd

SET clonefile=athenaeum_clone.fmp12
SET ThisScriptsDirectory=%~dp0
SET clonepath="%sourcefolder%clone\%clonefile%"
call "B:\up\setlog.cmd"


IF NOT EXIST %clonepath% (
    Echo [101;93m%clonepath not downloaded, aborting[0m
    exit /b
 )

rem                 remove previous skipped file log
IF EXIST skipped.txt del skipped.txt

rem    in production would force disconnect all users here (with no timeout)
fmsadmin DISCONNECT CLIENT -f -y -t 0 -u%fmaccount% -p%fmpassword%

rem    master_file_list.txt has a list of files and folder names to process

for /F "tokens=1,2" %%i in (master_file_list.txt) do (

    rem echo %%i %%j

    IF NOT "%%i"=="#" call update.cmd %%i %%j

)

rem list log lines that include "open", "close", "Start"
echo.
echo.
findstr /I "open clos Start" log\*.txt

echo [101;93m 
IF EXIST skipped.txt (TYPE skipped.txt)
echo [0m


fmsadmin OPEN -u%fmaccount% -p%fmpassword%