@echo off
rem   © 2018-2021 Rob Russell, SumWare Consulting
rem   Creative Commons licence
rem   Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
rem   https://creativecommons.org/licenses/by-sa/4.0/

rem %1 is file name  %2 is folder name

rem cls 

IF "%1"=="" exit /b

echo.
echo             processing [101;93m%1[0m in folder %2 


SET ThisScriptsDirectory=%~dp0
SET sourcefolder=%ThisScriptsDirectory%
SET src="%sourcefolder%source\%1.fmp12"
SET bak="%sourcefolder%backup\"
SET cln="%sourcefolder%clone\athenaeum_clone.fmp12"
SET tgt="%sourcefolder%new\%1.fmp12"
SET log="%sourcefolder%log\%1.txt"

echo "delete log file %log%"
del /q %log%
set live=A:\live_databases\
call "B:\up\setlog.cmd"
set myaccount=migrate
set mypassword=migrate


if "%~1"=="" goto END0
if "%~2"=="" goto END0


fmsadmin list files -u%fmaccount% -p%fmpassword% >> %log%

rem close the file if it is in the list of open files written to the log
findstr /i "%1.fmp12" %log% >> test.txt
if %errorlevel%==0 GOTO CLOSEFILE 

:CLOSE0


For /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
set backup_stamp=%mydate%

echo "delete %tgt%"
del /q "%tgt%"

if NOT EXIST %bak% (mkdir "%bak%")

rem copy file to backup and old directory

echo "copy live to source folder"
copy "%live%%2\%1.fmp12" "%sourcefolder%source\"

rem     6 Nov 2023 changed to overwrite backup
rem     9 Feb 2025 turned off backup
rem     copy "%live%%2\%1.fmp12" "%bak%\%1.fmp12.%backup_stamp%"
rem copy "%live%%2\%1.fmp12" "%bak%\"

echo "migrating"
FMDataMigration -src_path %src% -clone_path %cln% -src_account %myaccount% -src_pwd %mypassword% -clone_account %myaccount% -clone_pwd %mypassword% -target_path %tgt% -ignore_valuelists  >>%log%

echo.

echo [101;93m 

findstr "error not invalid" %log%
echo [0m
echo.

rem put into production
echo "delete (old) live" 
del "%live%%2\%1.fmp12"

echo "copy updated file back to live"
copy "%tgt%" "%live%%2\"
@echo off

fmsadmin open %1.fmp12  -yf -u%fmaccount% -p%fmpassword% >> %log%
timeout /t 6 /nobreak
rem ping -n 4 127.0.0.1>nul






GOTO END0



:CLOSEFILE

rem only force disconnect when updating all clients out of business hours
rem echo "force disconnect clients"
rem fmsadmin disconnect client -yf -t 0 -u%fmaccount% -p%fmpassword% >> %log%

echo "closing %1"
fmsadmin close %1.fmp12  -y -f -t 0 -u%fmaccount% -p%fmpassword% >> %log%
timeout /t 12 /nobreak


echo.

rem check that the file actually closed
rem type %log% | findstr "File Closed: %1.fmp12"
findstr "File Closed: %1.fmp12" %log%
if NOT %errorlevel%==0 GOTO CANTCLOSE

GOTO CLOSE0



:CANTCLOSE

echo [101;93m 
echo "can't close %1.fmp12"
echo [0m
echo "can't close %1.fmp12" >> %log%
fmsadmin open %1.fmp12  -yf -u%fmaccount% -p%fmpassword%

echo "skipped file %1.fmp12" >> %log%
echo "skipped file %1.fmp12" >> skipped.txt

echo "end %1"

:END0

echo.
echo.

rem type %log%

