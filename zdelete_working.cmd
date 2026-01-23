@echo off
SET ThisScriptsDirectory=%~dp0
SET sourcefolder=%ThisScriptsDirectory%
SET src="%sourcefolder%source\"
SET bak="%sourcefolder%backup\"
SET cln="%sourcefolder%clone\"
SET tgt="%sourcefolder%new\"
SET log="%sourcefolder%log\"
set zip="%sourcefolder%athenaeum_clone.fmp12.zip"

echo.
echo %src%
echo.
del /Q %src%

echo %bak%
echo.

del /Q %bak%

echo %cln%
echo.

del /Q %cln%

echo %tgt%
echo.

del /Q %tgt%

echo %log%
echo.

del /Q %log%

echo %zip%
echo.

del /Q %zip%