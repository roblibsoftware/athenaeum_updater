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

# Helper function to write debug output to stderr (so it doesn't interfere with stdout captures)
function Write-DebugLog {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
}

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
            Write-DebugLog "=== LOGIN REQUEST ==="
            Write-DebugLog "Request URL: $authUrl"
            Write-DebugLog "Method: POST"
            Write-DebugLog "Username: $Username"
            Write-DebugLog "Password length: $($Password.Length) chars"
            Write-DebugLog "====================="

            # FileMaker Admin API uses HTTP Basic Authentication for login
            # Create Base64 encoded credentials for Authorization header
            $credentials = "${Username}:${Password}"
            $credentialsBytes = [System.Text.Encoding]::ASCII.GetBytes($credentials)
            $credentialsBase64 = [System.Convert]::ToBase64String($credentialsBytes)

            $headers = @{
                'Content-Type' = 'application/json'
                'Authorization' = "Basic $credentialsBase64"
            }

            Write-DebugLog "Using HTTP Basic Authentication"

            # Empty body (credentials are in Authorization header)
            $body = @{} | ConvertTo-Json

            try {
                $webResponse = Invoke-WebRequest -Uri $authUrl -Method Post -Headers $headers -Body $body -UseBasicParsing
                Write-DebugLog "HTTP Status: $($webResponse.StatusCode)"
                Write-DebugLog "Response Content: $($webResponse.Content)"

                $response = $webResponse.Content | ConvertFrom-Json
            }
            catch {
                Write-DebugLog "=== LOGIN FAILED ==="
                Write-DebugLog "Status Code: $($_.Exception.Response.StatusCode.value__)"
                Write-DebugLog "Status Description: $($_.Exception.Response.StatusDescription)"

                # Try to read response body if available
                if ($_.Exception.Response) {
                    try {
                        $result = $_.Exception.Response.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($result)
                        $responseText = $reader.ReadToEnd()
                        Write-DebugLog "Response Body: $responseText"
                        $reader.Close()
                    }
                    catch {
                        Write-DebugLog "Could not read response stream"
                    }
                }

                Write-DebugLog "=================="
                throw
            }

            if ($response.response.token) {
                # Write token to temporary file AND output to stdout
                $tokenFile = Join-Path $PSScriptRoot "fmtoken.tmp"
                $response.response.token | Set-Content -Path $tokenFile -NoNewline -Force

                # Also output to stdout for backwards compatibility
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

            # First, get the database ID by listing databases
            Write-DebugLog "=== LOOKING UP DATABASE ID ==="
            Write-DebugLog "Database Name: $DatabaseName"

            $headers = @{
                'Content-Type' = 'application/json'
                'Authorization' = "Bearer $Token"
            }

            $listUrl = "$baseUrl/databases"
            Write-DebugLog "List URL: $listUrl"

            try {
                $listResponse = Invoke-RestMethod -Uri $listUrl -Method Get -Headers $headers
                $database = $listResponse.response.databases | Where-Object { $_.filename -eq $DatabaseName }

                if (-not $database) {
                    Write-DebugLog "ERROR: Database not found in server list!"
                    Write-DebugLog "Available databases:"
                    foreach ($db in $listResponse.response.databases) {
                        Write-DebugLog "  - $($db.filename) (ID: $($db.id), Status: $($db.status))"
                    }
                    Write-Error "Database '$DatabaseName' not found on FileMaker Server"
                    exit 1
                }

                $databaseId = $database.id
                Write-DebugLog "Found Database ID: $databaseId"
                Write-DebugLog "Status: $($database.status)"
                Write-DebugLog "=============================="
            }
            catch {
                Write-Error "Failed to list databases: $($_.Exception.Message)"
                exit 1
            }

            # Now close using the database ID
            $closeUrl = "$baseUrl/databases/$databaseId/close"

            # Log the request details
            Write-DebugLog "=== CLOSE DATABASE REQUEST ==="
            Write-DebugLog "Database Name: $DatabaseName"
            Write-DebugLog "Database ID: $databaseId"
            Write-DebugLog "Request URL: $closeUrl"
            Write-DebugLog "Method: PUT"

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
            Write-DebugLog "Request Body: $bodyJson"
            Write-DebugLog "=============================="

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

            # First, get the database ID by listing databases
            Write-DebugLog "=== LOOKING UP DATABASE ID ==="
            Write-DebugLog "Database Name: $DatabaseName"

            $headers = @{
                'Content-Type' = 'application/json'
                'Authorization' = "Bearer $Token"
            }

            $listUrl = "$baseUrl/databases"
            Write-DebugLog "List URL: $listUrl"

            try {
                $listResponse = Invoke-RestMethod -Uri $listUrl -Method Get -Headers $headers
                $database = $listResponse.response.databases | Where-Object { $_.filename -eq $DatabaseName }

                if (-not $database) {
                    Write-DebugLog "ERROR: Database not found in server list!"
                    Write-DebugLog "Available databases:"
                    foreach ($db in $listResponse.response.databases) {
                        Write-DebugLog "  - $($db.filename) (ID: $($db.id), Status: $($db.status))"
                    }
                    Write-Error "Database '$DatabaseName' not found on FileMaker Server"
                    exit 1
                }

                $databaseId = $database.id
                Write-DebugLog "Found Database ID: $databaseId"
                Write-DebugLog "Status: $($database.status)"
                Write-DebugLog "=============================="
            }
            catch {
                Write-Error "Failed to list databases: $($_.Exception.Message)"
                exit 1
            }

            # Now open using the database ID
            $openUrl = "$baseUrl/databases/$databaseId/open"

            # Log the request details
            Write-DebugLog "=== OPEN DATABASE REQUEST ==="
            Write-DebugLog "Database Name: $DatabaseName"
            Write-DebugLog "Database ID: $databaseId"
            Write-DebugLog "Request URL: $openUrl"
            Write-DebugLog "Method: PUT"
            Write-DebugLog "============================="

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
            Write-DebugLog "=== LOGOUT REQUEST ==="
            Write-DebugLog "Token received: '$Token'"
            Write-DebugLog "Token length: $($Token.Length)"

            if (-not $Token) {
                Write-DebugLog "ERROR: Token is null or empty!"
                Write-Error "Token required for logout operation"
                exit 1
            }

            $logoutUrl = "$baseUrl/user/auth/$Token"
            Write-DebugLog "Request URL: $logoutUrl"
            Write-DebugLog "Method: DELETE"
            Write-DebugLog "======================"

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
    Write-DebugLog "=== ERROR DETAILS ==="
    Write-DebugLog "Operation: $Operation"
    Write-DebugLog "Error Message: $($_.Exception.Message)"

    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-DebugLog "HTTP Status: $($_.Exception.Response.StatusCode)"
            Write-DebugLog "Response Body: $responseBody"
            $reader.Close()
        }
        catch {
            Write-DebugLog "Could not read response body"
        }
    }
    Write-DebugLog "===================="

    Write-Error "API operation '$Operation' failed: $($_.Exception.Message)"
    exit 1
}
