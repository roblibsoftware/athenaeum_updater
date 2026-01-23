@echo off
rem   © 2018-2021 Rob Russell, SumWare Consulting
rem   Creative Commons licence
rem   Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
rem   https://creativecommons.org/licenses/by-sa/4.0/

cls
SET downloadurl="https://librarysoftware.co.nz/download/up/athenaeum_clone.fmp12.zip"
SET clonefile=athenaeum_clone.fmp12
SET ThisScriptsDirectory=%~dp0
SET sourcefolder=%ThisScriptsDirectory%
SET downloadzip="%sourcefolder%%clonefile%.zip"
SET downloadfile="%sourcefolder%clone\%clonefile%"

SET curl="C:\Program Files\curl\bin\curl.exe"
SET unzipper="C:\Program Files\7-Zip\7z.exe"

del /q zip.log
del /q %downloadzip%
del /q %downloadfile%

echo.

rem     download the zipped clone file
%curl% %downloadurl% --output %downloadzip%

rem     unzip it
%unzipper% x %downloadzip% %clonefile% > zip.log

echo [101;93m 
findstr /c:"Everything is Ok" zip.log
echo [0m

rem     move it into the clone folder
move /y %clonefile% clone

del /q %downloadzip%

echo.
echo.

rem     case insensitive grep the directory looking for the word "athen" (as in "athenaeum")
echo [101;93m 
dir clone\a*.* | findstr /I "athen" 
echo [0m

dir *.cmd