# Test FileMaker Server Admin API connectivity
# Tests basic connectivity and API version

param(
    [string]$FileMakerHost = "athenaeum.nz"
)

$ErrorActionPreference = "Continue"

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

Write-Host "Testing FileMaker Server Admin API" -ForegroundColor Cyan
Write-Host "Host: $FileMakerHost" -ForegroundColor Cyan
Write-Host ""

# Test v2 API base endpoint
Write-Host "Test 1: API v2 base endpoint" -ForegroundColor Yellow
$v2BaseUrl = "https://$FileMakerHost/fmi/admin/api/v2"
try {
    $response = Invoke-WebRequest -Uri $v2BaseUrl -Method Get -UseBasicParsing
    Write-Host "  Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "  Response: $($response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)))"
}
catch {
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "  Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    }
}

Write-Host ""

# Test v1 API (maybe they need v1 instead?)
Write-Host "Test 2: API v1 base endpoint" -ForegroundColor Yellow
$v1BaseUrl = "https://$FileMakerHost/fmi/admin/api/v1"
try {
    $response = Invoke-WebRequest -Uri $v1BaseUrl -Method Get -UseBasicParsing
    Write-Host "  Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "  Response: $($response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)))"
}
catch {
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "  Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    }
}

Write-Host ""

# Test auth endpoint specifically
Write-Host "Test 3: Auth endpoint (v2)" -ForegroundColor Yellow
$authUrl = "https://$FileMakerHost/fmi/admin/api/v2/user/auth"
try {
    # Try without credentials first to see what error we get
    $response = Invoke-WebRequest -Uri $authUrl -Method Get -UseBasicParsing
    Write-Host "  Status: $($response.StatusCode)" -ForegroundColor Green
}
catch {
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "  Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        Write-Host "  Status Description: $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Done" -ForegroundColor Cyan
