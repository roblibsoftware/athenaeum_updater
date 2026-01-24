# Test FileMaker Server Admin API login with actual credentials
# This will show exactly what error FileMaker Server returns

param(
    [string]$FileMakerHost = "athenaeum.nz"
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

Write-Host "FileMaker Server Admin API Login Test" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Get credentials
Write-Host "Retrieving credentials..." -ForegroundColor Yellow
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$credFilePath = Join-Path $scriptPath "fmcreds.encrypted"

if (-not (Test-Path $credFilePath)) {
    Write-Host "ERROR: Credential file not found: $credFilePath" -ForegroundColor Red
    Write-Host "Please run store-credentials.cmd first" -ForegroundColor Red
    exit 1
}

try {
    $lines = Get-Content $credFilePath
    # Ensure we get strings, not FileInfo objects
    $fmaccount = [string]$lines[0]
    $encryptedPassword = [string]$lines[1]

    $securePassword = $encryptedPassword | ConvertTo-SecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $fmpassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    Write-Host "Username: $fmaccount" -ForegroundColor Green
    Write-Host "Password length: $($fmpassword.Length) chars" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to decrypt credentials: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test with athenaeum.nz
Write-Host "Test 1: Login using hostname 'athenaeum.nz'" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow
$authUrl = "https://athenaeum.nz/fmi/admin/api/v2/user/auth"
Write-Host "URL: $authUrl"

# FileMaker Admin API uses HTTP Basic Authentication for login
$credentials = "${fmaccount}:${fmpassword}"
$credentialsBytes = [System.Text.Encoding]::ASCII.GetBytes($credentials)
$credentialsBase64 = [System.Convert]::ToBase64String($credentialsBytes)

Write-Host "Using HTTP Basic Authentication" -ForegroundColor Cyan
Write-Host "Authorization: Basic $($credentialsBase64.Substring(0,20))..." -ForegroundColor Gray
Write-Host ""

# Empty body (credentials in Authorization header)
$bodyJson = "{}"
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)

$headers = @{
    'Content-Type' = 'application/json'
    'Authorization' = "Basic $credentialsBase64"
}

try {
    $response = Invoke-WebRequest -Uri $authUrl -Method Post -Headers $headers -Body $bodyBytes -UseBasicParsing
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Green
    $responseObj = $response.Content | ConvertFrom-Json
    Write-Host "Token: $($responseObj.response.token.Substring(0,20))..." -ForegroundColor Green
}
catch {
    Write-Host "FAILED!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        Write-Host "Status Description: $($_.Exception.Response.StatusDescription)" -ForegroundColor Red

        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response Body: $responseBody" -ForegroundColor Red
            $reader.Close()
        }
        catch {
            Write-Host "Could not read response body" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host ""

# Test with localhost
Write-Host "Test 2: Login using 'localhost'" -ForegroundColor Yellow
Write-Host "--------------------------------" -ForegroundColor Yellow
$authUrl = "https://localhost/fmi/admin/api/v2/user/auth"
Write-Host "URL: $authUrl"
Write-Host ""

try {
    $response = Invoke-WebRequest -Uri $authUrl -Method Post -Headers $headers -Body $bodyBytes -UseBasicParsing
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Green
    $responseObj = $response.Content | ConvertFrom-Json
    Write-Host "Token: $($responseObj.response.token.Substring(0,20))..." -ForegroundColor Green
}
catch {
    Write-Host "FAILED!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        Write-Host "Status Description: $($_.Exception.Response.StatusDescription)" -ForegroundColor Red

        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response Body: $responseBody" -ForegroundColor Red
            $reader.Close()
        }
        catch {
            Write-Host "Could not read response body" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Done" -ForegroundColor Cyan
