# Test database close operation using PATCH method
# FileMaker Database Update Tools v4.1.0 (Build: 2026-02-09)
param(
    [string]$DatabaseName = "trial_athenaeum.fmp12",
    [string]$FileMakerHost
)

$ErrorActionPreference = "Stop"

# Display version
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FileMaker Database Update Tools v4.1.0" -ForegroundColor Cyan
Write-Host "Build: 2026-02-09" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

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

Write-Host "FileMaker Server Database Close Test" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
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
Write-Host "Logging in..." -ForegroundColor Yellow
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

Write-Host "Login successful. Token: $($token.Substring(0,20))..." -ForegroundColor Green
Write-Host ""

# List databases to get ID
Write-Host "Looking up database ID..." -ForegroundColor Yellow
$listUrl = "https://$FileMakerHost/fmi/admin/api/v2/databases"
$headers = @{
    'Content-Type' = 'application/json'
    'Authorization' = "Bearer $token"
}

$listResponse = Invoke-WebRequest -Uri $listUrl -Method Get -Headers $headers -UseBasicParsing
$listObj = $listResponse.Content | ConvertFrom-Json
$database = $listObj.response.databases | Where-Object { $_.filename -eq $DatabaseName }

if (-not $database) {
    Write-Host "ERROR: Database not found!" -ForegroundColor Red
    exit 1
}

$dbId = $database.id
Write-Host "Found database: $DatabaseName" -ForegroundColor Green
Write-Host "  ID: $dbId" -ForegroundColor Green
Write-Host "  Status: $($database.status)" -ForegroundColor Green
Write-Host ""

# Close database using PATCH method
Write-Host "Attempting to close database..." -ForegroundColor Yellow
Write-Host ""

$dbUrl = "https://$FileMakerHost/fmi/admin/api/v2/databases/$dbId"
$closeBody = @{
    status = "CLOSED"
    force = $true
} | ConvertTo-Json

Write-Host "PATCH $dbUrl" -ForegroundColor Cyan
Write-Host "Body: $closeBody"
Write-Host ""

try {
    $closeResponse = Invoke-WebRequest -Uri $dbUrl -Method Patch -Headers $headers -Body $closeBody -UseBasicParsing
    $closeObj = $closeResponse.Content | ConvertFrom-Json
    Write-Host "SUCCESS! Database closed." -ForegroundColor Green
    Write-Host "Status: $($closeObj.response.database.status)" -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Response.StatusCode.value__) - $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        $stream.Position = 0
        $reader = New-Object System.IO.StreamReader($stream)
        $errorBody = $reader.ReadToEnd()
        if (-not [string]::IsNullOrWhiteSpace($errorBody)) {
            Write-Host "Response: $errorBody" -ForegroundColor Gray
        }
        $reader.Close()
    } catch {}

    # Logout and exit
    Write-Host ""
    Write-Host "Logging out..." -ForegroundColor Yellow
    $logoutUrl = "https://$FileMakerHost/fmi/admin/api/v2/user/auth/$token"
    try {
        Invoke-WebRequest -Uri $logoutUrl -Method Delete -Headers @{'Content-Type'='application/json'} -UseBasicParsing | Out-Null
    } catch {}
    exit 1
}
Write-Host ""

Write-Host ""
Write-Host "Logging out..." -ForegroundColor Yellow
$logoutUrl = "https://$FileMakerHost/fmi/admin/api/v2/user/auth/$token"
try {
    Invoke-WebRequest -Uri $logoutUrl -Method Delete -Headers @{'Content-Type'='application/json'} -UseBasicParsing | Out-Null
    Write-Host "Logout successful" -ForegroundColor Green
}
catch {
    Write-Host "Logout failed (token may auto-expire)" -ForegroundColor Gray
}
