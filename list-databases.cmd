@echo off
rem List all databases on FileMaker Server
rem Helps diagnose database name issues

rem Enable ANSI color support
for /F "delims=" %%A in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%A"

echo.
echo %ESC%[102;30mFileMaker Server Database List%ESC%[0m
echo ================================
echo.

rem Retrieve credentials from encrypted storage using PowerShell
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0get-fmcreds.ps1"') do %%i
if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to retrieve credentials%ESC%[0m
    pause
    exit /b 1
)

rem FileMaker Server settings
set fmhost=athenaeum.nz

echo Connecting to: %fmhost%
echo.

rem Get authentication token
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation login -FileMakerHost "%fmhost%" -Username "%fmaccount%" -Password "%fmpassword%"') do set fmtoken=%%i

if %ERRORLEVEL% neq 0 (
    echo %ESC%[101;93mERROR: Failed to authenticate%ESC%[0m
    pause
    exit /b 1
)

echo Authentication successful
echo.
echo Fetching database list...
echo.

rem List databases using PowerShell and FileMaker Admin API
powershell -ExecutionPolicy Bypass -Command "$token='%fmtoken%'; $baseUrl='https://%fmhost%/fmi/admin/api/v2'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) { Add-Type @\"using System; using System.Net; using System.Net.Security; using System.Security.Cryptography.X509Certificates; public class ServerCertificateValidationCallback { public static void Ignore() { ServicePointManager.ServerCertificateValidationCallback = delegate { return true; }; } }\"@; [ServerCertificateValidationCallback]::Ignore() }; $headers = @{ 'Content-Type' = 'application/json'; 'Authorization' = \"Bearer $token\" }; try { $response = Invoke-RestMethod -Uri \"$baseUrl/databases\" -Method Get -Headers $headers; Write-Host \"`nDatabases on %fmhost%:\" -ForegroundColor Green; Write-Host \"================================\" -ForegroundColor Green; foreach ($db in $response.response.databases) { Write-Host \"`nFilename: $($db.filename)\" -ForegroundColor Cyan; Write-Host \"  Status: $($db.status)\"; Write-Host \"  Clients: $($db.clients)\"; if ($db.folder) { Write-Host \"  Folder: $($db.folder)\" } } Write-Host \"`nTotal databases: $($response.response.databases.Count)\" -ForegroundColor Yellow } catch { Write-Host \"Error: $($_.Exception.Message)\" -ForegroundColor Red }"

echo.
echo.

rem Logout
powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation logout -FileMakerHost "%fmhost%" -Token "%fmtoken%" >nul 2>&1

echo.
pause
