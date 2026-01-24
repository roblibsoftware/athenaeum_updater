# Verbose login test - shows all request/response details
param(
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

Write-Host "VERBOSE FileMaker Server Login Test" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Get credentials
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$credFilePath = Join-Path $scriptPath "fmcreds.encrypted"

$lines = @(Get-Content $credFilePath)
$fmaccount = $lines[0].ToString()
$encryptedPassword = $lines[1].ToString()

$securePassword = $encryptedPassword | ConvertTo-SecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$fmpassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

Write-Host "Credentials loaded" -ForegroundColor Green
Write-Host ""

$authUrl = "https://$FileMakerHost/fmi/admin/api/v2/user/auth"

# FileMaker Admin API uses HTTP Basic Authentication
$credentials = "${fmaccount}:${fmpassword}"
$credentialsBytes = [System.Text.Encoding]::ASCII.GetBytes($credentials)
$credentialsBase64 = [System.Convert]::ToBase64String($credentialsBytes)

# Empty body (credentials in Authorization header)
$bodyJson = "{}"
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)

Write-Host "REQUEST DETAILS:" -ForegroundColor Yellow
Write-Host "URL: $authUrl"
Write-Host "Method: POST"
Write-Host "Authentication: HTTP Basic Auth"
Write-Host "Authorization: Basic $($credentialsBase64.Substring(0,30))..."
Write-Host "Body: $bodyJson"
Write-Host "Body Length: $($bodyBytes.Length) bytes"
Write-Host "Content-Type: application/json"
Write-Host ""

$headers = @{
    'Content-Type' = 'application/json'
    'Authorization' = "Basic $credentialsBase64"
}

try {
    $response = Invoke-WebRequest -Uri $authUrl -Method Post -Headers $headers -Body $bodyBytes -UseBasicParsing

    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host ""
    Write-Host "RESPONSE DETAILS:" -ForegroundColor Yellow
    Write-Host "Status: $($response.StatusCode) $($response.StatusDescription)"
    Write-Host ""
    Write-Host "Response Headers:" -ForegroundColor Yellow
    foreach ($header in $response.Headers.Keys) {
        Write-Host "  $header : $($response.Headers[$header])"
    }
    Write-Host ""
    Write-Host "Response Body:" -ForegroundColor Yellow
    Write-Host $response.Content

    $responseObj = $response.Content | ConvertFrom-Json
    Write-Host ""
    Write-Host "Token: $($responseObj.response.token.Substring(0,20))..." -ForegroundColor Green
}
catch {
    Write-Host "FAILED!" -ForegroundColor Red
    Write-Host ""
    Write-Host "ERROR DETAILS:" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)"

    if ($_.Exception.Response) {
        Write-Host ""
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode.value__) - $($_.Exception.Response.StatusDescription)"

        Write-Host ""
        Write-Host "Response Headers:" -ForegroundColor Yellow
        foreach ($header in $_.Exception.Response.Headers) {
            Write-Host "  $header : $($_.Exception.Response.Headers[$header])"
        }

        Write-Host ""
        Write-Host "Attempting to read response body..." -ForegroundColor Yellow
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $stream.Position = 0
            $reader = New-Object System.IO.StreamReader($stream)
            $responseBody = $reader.ReadToEnd()

            if ([string]::IsNullOrWhiteSpace($responseBody)) {
                Write-Host "  (Response body is empty)" -ForegroundColor Gray
            } else {
                Write-Host "Response Body:" -ForegroundColor Yellow
                Write-Host $responseBody
            }

            $reader.Close()
        }
        catch {
            Write-Host "  Could not read response body: $($_.Exception.Message)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "Full Exception:" -ForegroundColor Gray
    Write-Host $_.Exception | Format-List -Force | Out-String
}
