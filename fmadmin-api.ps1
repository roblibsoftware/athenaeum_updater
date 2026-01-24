# fmadmin-api.ps1
# FileMaker Server Admin API helper
# Handles authentication, database operations via REST API
#
# © 2026 Rob Russell, SumWare Consulting
# Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('login', 'close', 'open', 'logout', 'get-status')]
    [string]$Operation,

    [Parameter(Mandatory=$false)]
    [string]$FileMakerHost = "localhost",

    [Parameter(Mandatory=$false)]
    [string]$Username,

    [Parameter(Mandatory=$false)]
    [string]$Password,

    [Parameter(Mandatory=$false)]
    [string]$Token,

    [Parameter(Mandatory=$false)]
    [string]$DatabaseName,

    [Parameter(Mandatory=$false)]
    [switch]$ForceDisconnect,

    [Parameter(Mandatory=$false)]
    [int]$GracePeriod = 0
)

$ErrorActionPreference = "Stop"

# Load System.Web assembly for URL encoding
Add-Type -AssemblyName System.Web

# FileMaker Server Admin API base URL
$baseUrl = "https://$FileMakerHost/fmi/admin/api/v2"

# Ignore SSL certificate errors (for self-signed certs - remove in production if using valid certs)
if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
    Add-Type @"
        using System;
        using System.Net;
        using System.Net.Security;
        using System.Security.Cryptography.X509Certificates;
        public class ServerCertificateValidationCallback {
            public static void Ignore() {
                ServicePointManager.ServerCertificateValidationCallback =
                    delegate(
                        Object obj,
                        X509Certificate certificate,
                        X509Chain chain,
                        SslPolicyErrors errors
                    ) { return true; };
            }
        }
"@
}
[ServerCertificateValidationCallback]::Ignore()

# Set TLS version
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    switch ($Operation) {
        'login' {
            # Authenticate and get token
            $authUrl = "$baseUrl/user/auth"

            # Log the request details (don't log password!)
            Write-Host "=== LOGIN REQUEST ===" -ForegroundColor Cyan
            Write-Host "Request URL: $authUrl"
            Write-Host "Method: POST"
            Write-Host "Username: $Username"
            Write-Host "=====================" -ForegroundColor Cyan

            $body = @{
                username = $Username
                password = $Password
            } | ConvertTo-Json

            $headers = @{
                'Content-Type' = 'application/json'
            }

            $response = Invoke-RestMethod -Uri $authUrl -Method Post -Headers $headers -Body $body

            if ($response.response.token) {
                # Output just the token for batch script to capture
                Write-Output $response.response.token
                exit 0
            } else {
                Write-Error "Failed to obtain authentication token"
                exit 1
            }
        }

        'close' {
            # Close a database (with optional force disconnect)
            if (-not $Token) {
                Write-Error "Token required for close operation"
                exit 1
            }

            if (-not $DatabaseName) {
                Write-Error "DatabaseName required for close operation"
                exit 1
            }

            # URL encode the database name
            $encodedDbName = [System.Web.HttpUtility]::UrlEncode($DatabaseName)
            $closeUrl = "$baseUrl/databases/$encodedDbName/close"

            # Log the request details
            Write-Host "=== CLOSE DATABASE REQUEST ===" -ForegroundColor Cyan
            Write-Host "Database Name (original): $DatabaseName"
            Write-Host "Database Name (URL encoded): $encodedDbName"
            Write-Host "Request URL: $closeUrl"
            Write-Host "Method: PUT"

            $headers = @{
                'Content-Type' = 'application/json'
                'Authorization' = "Bearer $Token"
            }

            $body = @{
                messageText = "Database closing for update"
            }

            if ($ForceDisconnect) {
                $body.force = $true
            }

            if ($GracePeriod -gt 0) {
                $body.gracePeriod = $GracePeriod
            }

            $bodyJson = $body | ConvertTo-Json
            Write-Host "Request Body: $bodyJson"
            Write-Host "==============================" -ForegroundColor Cyan

            $response = Invoke-RestMethod -Uri $closeUrl -Method Put -Headers $headers -Body $bodyJson

            if ($response.messages[0].code -eq "0") {
                Write-Output "Database closed successfully: $DatabaseName"
                exit 0
            } else {
                Write-Error "Failed to close database: $($response.messages[0].message)"
                exit 1
            }
        }

        'open' {
            # Open a database
            if (-not $Token) {
                Write-Error "Token required for open operation"
                exit 1
            }

            if (-not $DatabaseName) {
                Write-Error "DatabaseName required for open operation"
                exit 1
            }

            $encodedDbName = [System.Web.HttpUtility]::UrlEncode($DatabaseName)
            $openUrl = "$baseUrl/databases/$encodedDbName/open"

            # Log the request details
            Write-Host "=== OPEN DATABASE REQUEST ===" -ForegroundColor Cyan
            Write-Host "Database Name (original): $DatabaseName"
            Write-Host "Database Name (URL encoded): $encodedDbName"
            Write-Host "Request URL: $openUrl"
            Write-Host "Method: PUT"
            Write-Host "=============================" -ForegroundColor Cyan

            $headers = @{
                'Content-Type' = 'application/json'
                'Authorization' = "Bearer $Token"
            }

            $body = @{} | ConvertTo-Json

            $response = Invoke-RestMethod -Uri $openUrl -Method Put -Headers $headers -Body $body

            if ($response.messages[0].code -eq "0") {
                Write-Output "Database opened successfully: $DatabaseName"
                exit 0
            } else {
                Write-Error "Failed to open database: $($response.messages[0].message)"
                exit 1
            }
        }

        'get-status' {
            # Get database status
            if (-not $Token) {
                Write-Error "Token required for get-status operation"
                exit 1
            }

            if (-not $DatabaseName) {
                Write-Error "DatabaseName required for get-status operation"
                exit 1
            }

            $encodedDbName = [System.Web.HttpUtility]::UrlEncode($DatabaseName)
            $statusUrl = "$baseUrl/databases/$encodedDbName"

            $headers = @{
                'Content-Type' = 'application/json'
                'Authorization' = "Bearer $Token"
            }

            $response = Invoke-RestMethod -Uri $statusUrl -Method Get -Headers $headers

            if ($response.response.status) {
                Write-Output $response.response.status
                exit 0
            } else {
                Write-Error "Failed to get database status"
                exit 1
            }
        }

        'logout' {
            # Logout and invalidate token
            # Log the request details
            Write-Host "=== LOGOUT REQUEST ===" -ForegroundColor Cyan
            Write-Host "Token received: '$Token'"
            Write-Host "Token length: $($Token.Length)"

            if (-not $Token) {
                Write-Host "ERROR: Token is null or empty!" -ForegroundColor Red
                Write-Error "Token required for logout operation"
                exit 1
            }

            $logoutUrl = "$baseUrl/user/auth/$Token"
            Write-Host "Request URL: $logoutUrl"
            Write-Host "Method: DELETE"
            Write-Host "======================" -ForegroundColor Cyan

            $headers = @{
                'Content-Type' = 'application/json'
            }

            $response = Invoke-RestMethod -Uri $logoutUrl -Method Delete -Headers $headers

            if ($response.messages[0].code -eq "0") {
                Write-Output "Logged out successfully"
                exit 0
            } else {
                Write-Error "Logout failed: $($response.messages[0].message)"
                exit 1
            }
        }
    }
}
catch {
    Write-Error "API operation '$Operation' failed: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Error "Response: $responseBody"
    }
    exit 1
}
