# Test database open operation with various body parameters
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

Write-Host "FileMaker Server Database Open Test" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
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

Write-Host "Login successful" -ForegroundColor Green
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

# Try various open operations
Write-Host "Attempting to open database..." -ForegroundColor Yellow
Write-Host ""

$openUrl = "https://$FileMakerHost/fmi/admin/api/v2/databases/$dbId"

function Test-Open {
    param($TestName, $Body)

    Write-Host "Test: $TestName" -ForegroundColor Cyan
    Write-Host "Body: $Body"

    try {
        $response = Invoke-WebRequest -Uri $openUrl -Method Patch -Headers $headers -Body $Body -UseBasicParsing
        Write-Host "SUCCESS!" -ForegroundColor Green
        Write-Host $response.Content
        return $true
    }
    catch {
        Write-Host "FAILED: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
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
        return $false
    }
    Write-Host ""
}

# Test 1: Just status=NORMAL
$body1 = '{"status":"NORMAL"}'
if (Test-Open "status=NORMAL" $body1) { exit 0 }
Write-Host ""

# Test 2: status=OPENED
$body2 = '{"status":"OPENED"}'
if (Test-Open "status=OPENED" $body2) { exit 0 }
Write-Host ""

# Test 3: status=NORMAL with empty messageText
$body3 = '{"status":"NORMAL","messageText":""}'
if (Test-Open "status=NORMAL with messageText" $body3) { exit 0 }
Write-Host ""

# Test 4: Empty body
$body4 = '{}'
if (Test-Open "Empty body" $body4) { exit 0 }
Write-Host ""

# Test 5: Just messageText
$body5 = '{"messageText":"Opening database"}'
if (Test-Open "Just messageText" $body5) { exit 0 }
Write-Host ""

# Test 6: status=NORMAL without force
$body6 = @{status = "NORMAL"} | ConvertTo-Json
if (Test-Open "PowerShell hashtable status=NORMAL" $body6) { exit 0 }
Write-Host ""

Write-Host ""
Write-Host "All tests failed. Logging out..." -ForegroundColor Yellow
$logoutUrl = "https://$FileMakerHost/fmi/admin/api/v2/user/auth/$token"
try {
    Invoke-WebRequest -Uri $logoutUrl -Method Delete -Headers @{'Content-Type'='application/json'} -UseBasicParsing | Out-Null
    Write-Host "Logout successful" -ForegroundColor Green
}
catch {
    Write-Host "Logout failed" -ForegroundColor Gray
}
