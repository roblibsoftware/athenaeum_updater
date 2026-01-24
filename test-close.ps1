# Test database close operation with verbose output
param(
    [string]$DatabaseName = "trial_athenaeum.fmp12",
    [string]$FileMakerHost = "localhost"
)

$ErrorActionPreference = "Stop"

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
$credFilePath = Join-Path $scriptPath "fmcreds.encrypted"

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

# Try close operation
Write-Host "Attempting to close database..." -ForegroundColor Yellow
Write-Host ""

$closeBody = @{
    messageText = "Test close"
    force = $true
} | ConvertTo-Json

# Test 1: PUT /databases/{id}/close
Write-Host "Test 1: PUT /databases/$dbId/close" -ForegroundColor Cyan
$closeUrl1 = "https://$FileMakerHost/fmi/admin/api/v2/databases/$dbId/close"
Write-Host "URL: $closeUrl1"
try {
    $closeResponse = Invoke-WebRequest -Uri $closeUrl1 -Method Put -Headers $headers -Body $closeBody -UseBasicParsing
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host $closeResponse.Content
}
catch {
    Write-Host "FAILED: $($_.Exception.Response.StatusCode.value__) - $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        $stream.Position = 0
        $reader = New-Object System.IO.StreamReader($stream)
        Write-Host "Response: $($reader.ReadToEnd())" -ForegroundColor Gray
        $reader.Close()
    } catch {}
}
Write-Host ""

# Test 2: PATCH /databases/{id}
Write-Host "Test 2: PATCH /databases/$dbId" -ForegroundColor Cyan
$closeUrl2 = "https://$FileMakerHost/fmi/admin/api/v2/databases/$dbId"
$patchBody = @{ status = "CLOSED"; force = $true } | ConvertTo-Json
Write-Host "URL: $closeUrl2"
try {
    $closeResponse = Invoke-WebRequest -Uri $closeUrl2 -Method Patch -Headers $headers -Body $patchBody -UseBasicParsing
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host $closeResponse.Content
}
catch {
    Write-Host "FAILED: $($_.Exception.Response.StatusCode.value__) - $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
}
Write-Host ""

# Test 3: PUT /databases/{id}
Write-Host "Test 3: PUT /databases/$dbId with status=CLOSED" -ForegroundColor Cyan
Write-Host "URL: $closeUrl2"
try {
    $closeResponse = Invoke-WebRequest -Uri $closeUrl2 -Method Put -Headers $headers -Body $patchBody -UseBasicParsing
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host $closeResponse.Content
}
catch {
    Write-Host "FAILED: $($_.Exception.Response.StatusCode.value__) - $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
}
Write-Host ""

# Test 4: POST /databases/{id}/close
Write-Host "Test 4: POST /databases/$dbId/close" -ForegroundColor Cyan
Write-Host "URL: $closeUrl1"
try {
    $closeResponse = Invoke-WebRequest -Uri $closeUrl1 -Method Post -Headers $headers -Body $closeBody -UseBasicParsing
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host $closeResponse.Content
}
catch {
    Write-Host "FAILED: $($_.Exception.Response.StatusCode.value__) - $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
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
