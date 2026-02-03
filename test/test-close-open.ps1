# Test close then immediately open (no file replacement)
# This tests if the open operation works at all

param(
    [string]$DatabaseName = "trial_athenaeum.fmp12",
    [string]$FileMakerHost
)

$ErrorActionPreference = "Stop"

# Read FileMaker host from host.txt if not provided, default to localhost
if (-not $FileMakerHost) {
    $hostFile = Join-Path $PSScriptRoot "..\host.txt"
    if (Test-Path $hostFile) {
        $FileMakerHost = (Get-Content $hostFile -First 1).Trim()
    } else {
        $FileMakerHost = "localhost"
    }
}

# Ignore SSL certificate errors
if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
    Add-Type @"
        using System;
        using System.Net;
        using System.Net.Security;
        using System.Security.Cryptography.X509Certificates;
        public class ServerCertificateValidationCallback {
            public static void Ignore() {
                ServicePointManager.ServerCertificateValidationCallback =
                    delegate { return true; };
            }
        }
"@
}
[ServerCertificateValidationCallback]::Ignore()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "FileMaker Server Close/Open Test (No File Replacement)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Get credentials and login
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$credFilePath = Join-Path (Split-Path -Parent $scriptPath) "fmcreds.encrypted"

$lines = @(Get-Content $credFilePath)
$fmaccount = $lines[0].ToString()
$encryptedPassword = $lines[1].ToString()

$securePassword = $encryptedPassword | ConvertTo-SecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$fmpassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

# Login
Write-Host "Step 1: Logging in..." -ForegroundColor Yellow
$authUrl = "https://$FileMakerHost/fmi/admin/api/v2/user/auth"
$credentials = "${fmaccount}:${fmpassword}"
$credentialsBytes = [System.Text.Encoding]::ASCII.GetBytes($credentials)
$credentialsBase64 = [System.Convert]::ToBase64String($credentialsBytes)

$loginHeaders = @{
    'Content-Type' = 'application/json'
    'Authorization' = "Basic $credentialsBase64"
}

$loginResponse = Invoke-WebRequest -Uri $authUrl -Method Post -Headers $loginHeaders -Body "{}" -UseBasicParsing
$responseObj = $loginResponse.Content | ConvertFrom-Json
$token = $responseObj.response.token
Write-Host "  Login successful" -ForegroundColor Green
Write-Host ""

# Headers for API operations
$headers = @{
    'Content-Type' = 'application/json'
    'Authorization' = "Bearer $token"
}

# Get database ID
Write-Host "Step 2: Looking up database..." -ForegroundColor Yellow
$listUrl = "https://$FileMakerHost/fmi/admin/api/v2/databases"
$listResponse = Invoke-WebRequest -Uri $listUrl -Method Get -Headers $headers -UseBasicParsing
$listObj = $listResponse.Content | ConvertFrom-Json
$database = $listObj.response.databases | Where-Object { $_.filename -eq $DatabaseName }

$dbId = $database.id
Write-Host "  Database: $DatabaseName" -ForegroundColor Green
Write-Host "  ID: $dbId" -ForegroundColor Green
Write-Host "  Initial Status: $($database.status)" -ForegroundColor Green
Write-Host ""

# Close database
Write-Host "Step 3: Closing database..." -ForegroundColor Yellow
$dbUrl = "https://$FileMakerHost/fmi/admin/api/v2/databases/$dbId"
$closeBody = @{
    status = "CLOSED"
    force = $true
} | ConvertTo-Json

Write-Host "  PATCH $dbUrl"
Write-Host "  Body: $closeBody"

try {
    $closeResponse = Invoke-WebRequest -Uri $dbUrl -Method Patch -Headers $headers -Body $closeBody -UseBasicParsing
    $closeObj = $closeResponse.Content | ConvertFrom-Json
    Write-Host "  Close successful!" -ForegroundColor Green
    Write-Host "  Status: $($closeObj.response.database.status)" -ForegroundColor Green
}
catch {
    Write-Host "  Close FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Wait a moment
Write-Host "Step 4: Waiting 2 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
Write-Host ""

# Open database
Write-Host "Step 5: Opening database..." -ForegroundColor Yellow
$openBody = @{
    status = "NORMAL"
} | ConvertTo-Json

Write-Host "  PATCH $dbUrl"
Write-Host "  Body: $openBody"

try {
    $openResponse = Invoke-WebRequest -Uri $dbUrl -Method Patch -Headers $headers -Body $openBody -UseBasicParsing
    $openObj = $openResponse.Content | ConvertFrom-Json
    Write-Host "  Open successful!" -ForegroundColor Green
    Write-Host "  Status: $($openObj.response.database.status)" -ForegroundColor Green
}
catch {
    Write-Host "  Open FAILED: $($_.Exception.Response.StatusCode.value__) - $($_.Exception.Response.StatusDescription)" -ForegroundColor Red

    try {
        $stream = $_.Exception.Response.GetResponseStream()
        $stream.Position = 0
        $reader = New-Object System.IO.StreamReader($stream)
        $errorBody = $reader.ReadToEnd()
        if (-not [string]::IsNullOrWhiteSpace($errorBody)) {
            Write-Host "  Error Response:" -ForegroundColor Red
            Write-Host "  $errorBody" -ForegroundColor Gray
        }
        $reader.Close()
    } catch {}

    Write-Host ""
    Write-Host "  Open operation failed. Trying to reopen original file..." -ForegroundColor Yellow
    # Logout first
    $logoutUrl = "https://$FileMakerHost/fmi/admin/api/v2/user/auth/$token"
    Invoke-WebRequest -Uri $logoutUrl -Method Delete -Headers @{'Content-Type'='application/json'} -UseBasicParsing | Out-Null

    exit 1
}
Write-Host ""

# Verify status
Write-Host "Step 6: Verifying status..." -ForegroundColor Yellow
$verifyResponse = Invoke-WebRequest -Uri $listUrl -Method Get -Headers $headers -UseBasicParsing
$verifyObj = $verifyResponse.Content | ConvertFrom-Json
$verifyDb = $verifyObj.response.databases | Where-Object { $_.id -eq $dbId }
Write-Host "  Final Status: $($verifyDb.status)" -ForegroundColor Green
Write-Host ""

# Logout
Write-Host "Step 7: Logging out..." -ForegroundColor Yellow
$logoutUrl = "https://$FileMakerHost/fmi/admin/api/v2/user/auth/$token"
Invoke-WebRequest -Uri $logoutUrl -Method Delete -Headers @{'Content-Type'='application/json'} -UseBasicParsing | Out-Null
Write-Host "  Logout successful" -ForegroundColor Green
Write-Host ""

Write-Host "=== TEST COMPLETED SUCCESSFULLY ===" -ForegroundColor Green
