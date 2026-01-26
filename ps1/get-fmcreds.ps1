# get-fmcreds.ps1
# Retrieves FileMaker admin credentials from encrypted storage
# and outputs SET commands for use in batch files
#
# © 2026 Rob Russell, SumWare Consulting
# Creative Commons licence
# Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# https://creativecommons.org/licenses/by-sa/4.0/
#
# This script uses Windows Data Protection API (DPAPI) to decrypt credentials
# Credentials can only be decrypted by the same Windows user account that encrypted them

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

try {
    # Path to encrypted credential file (stored in parent directory)
    $parentDir = Split-Path $PSScriptRoot -Parent
    $credFilePath = Join-Path $parentDir "fmcreds.encrypted"

    # Check if credential file exists
    if (-not (Test-Path $credFilePath)) {
        Write-Error "Credential file not found at: $credFilePath`nPlease run ps1\store-fmcreds.ps1 first to store credentials."
        exit 1
    }

    # Read encrypted credential file
    # Format: Line 1 = username, Line 2 = encrypted password
    $lines = Get-Content $credFilePath

    if ($lines.Count -lt 2) {
        Write-Error "Invalid credential file format. Please run ps1\store-fmcreds.ps1 again."
        exit 1
    }

    # Ensure we get strings, not FileInfo objects
    $username = [string]$lines[0]
    $encryptedPassword = [string]$lines[1]

    # Decrypt the password using DPAPI (Windows Data Protection API)
    $securePassword = $encryptedPassword | ConvertTo-SecureString

    # Convert SecureString to plain text for use in batch file
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    # Output SET commands for batch file to execute
    Write-Output "set `"fmaccount=$username`""
    Write-Output "set `"fmpassword=$password`""

    exit 0
}
catch {
    Write-Error "Failed to retrieve credentials: $($_.Exception.Message)"
    Write-Error "This may occur if you're running under a different Windows user account than the one that stored the credentials."
    exit 1
}
