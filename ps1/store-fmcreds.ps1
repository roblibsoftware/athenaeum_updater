# store-fmcreds.ps1
# Stores FileMaker admin credentials in encrypted storage using Windows DPAPI
#
# © 2026 Rob Russell, SumWare Consulting
# Creative Commons licence
# Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# https://creativecommons.org/licenses/by-sa/4.0/
#
# This script encrypts credentials using Windows Data Protection API (DPAPI)
# Credentials can only be decrypted by the same Windows user account
#
# USAGE:
#   Run this script once to store credentials
#   .\store-fmcreds.ps1
#
# SECURITY NOTES:
#   - Credentials are encrypted using DPAPI and tied to your Windows user account
#   - Only the Windows user who runs this script can decrypt the credentials
#   - Store the encrypted file (fmcreds.encrypted) in a secure location
#   - Set NTFS permissions on fmcreds.encrypted to restrict access
#   - DO NOT commit fmcreds.encrypted to version control

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Username,

    [Parameter(Mandatory=$false)]
    [SecureString]$Password
)

$ErrorActionPreference = "Stop"

Write-Host "FileMaker Credential Storage Utility" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Path to encrypted credential file (stored in parent directory)
    $parentDir = Split-Path $PSScriptRoot -Parent
    $credFilePath = Join-Path $parentDir "fmcreds.encrypted"

    # Check if credential file already exists
    if (Test-Path $credFilePath) {
        Write-Host "WARNING: Encrypted credential file already exists at:" -ForegroundColor Yellow
        Write-Host "  $credFilePath" -ForegroundColor Yellow
        Write-Host ""
        $overwrite = Read-Host "Do you want to overwrite it? (yes/no)"

        if ($overwrite -ne "yes") {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Get credentials from user if not provided as parameters
    if (-not $Username -or -not $Password) {
        Write-Host "Please enter the FileMaker admin credentials to store securely." -ForegroundColor Green
        Write-Host ""

        # Prompt for credentials
        $cred = Get-Credential -Message "Enter FileMaker admin credentials"

        if (-not $cred) {
            Write-Error "No credentials provided. Operation cancelled."
            exit 1
        }

        $Username = $cred.UserName
        $Password = $cred.Password
    }

    # Validate username
    if ([string]::IsNullOrWhiteSpace($Username)) {
        Write-Error "Username cannot be empty."
        exit 1
    }

    # Encrypt the password using DPAPI (Windows Data Protection API)
    # ConvertFrom-SecureString uses DPAPI by default
    $encryptedPassword = $Password | ConvertFrom-SecureString

    # Store username (plain text) and encrypted password in file
    # Format: Line 1 = username, Line 2 = encrypted password
    $content = @(
        $Username,
        $encryptedPassword
    )

    # Write to file
    $content | Set-Content -Path $credFilePath -Force

    Write-Host ""
    Write-Host "SUCCESS: Credentials encrypted and stored successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "File location: $credFilePath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "IMPORTANT SECURITY NOTES:" -ForegroundColor Yellow
    Write-Host "  1. These credentials can only be decrypted by the Windows user: $env:USERNAME" -ForegroundColor Yellow
    Write-Host "  2. Set NTFS permissions on the file to restrict access (recommended)" -ForegroundColor Yellow
    Write-Host "  3. DO NOT commit fmcreds.encrypted to version control" -ForegroundColor Yellow
    Write-Host "  4. Consider backing up this file in a secure location" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  - Your batch scripts will now retrieve credentials from this encrypted file" -ForegroundColor Cyan
    Write-Host "  - You can delete or secure the old setlog.cmd file" -ForegroundColor Cyan
    Write-Host ""

    # Recommend setting NTFS permissions
    Write-Host "Would you like to restrict NTFS permissions on the encrypted file? (recommended)" -ForegroundColor Green
    Write-Host "This will allow only your user account to read the file." -ForegroundColor Green
    $setPerms = Read-Host "Set permissions? (yes/no)"

    if ($setPerms -eq "yes") {
        try {
            # Get current user
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

            # Remove inheritance and set permissions for current user only
            $acl = Get-Acl $credFilePath
            $acl.SetAccessRuleProtection($true, $false)  # Disable inheritance, don't copy existing

            # Remove all existing access rules
            $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }

            # Add full control for current user
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $currentUser,
                "FullControl",
                "Allow"
            )
            $acl.AddAccessRule($accessRule)

            # Add full control for SYSTEM (needed for some operations)
            $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                "SYSTEM",
                "FullControl",
                "Allow"
            )
            $acl.AddAccessRule($systemRule)

            # Apply the ACL
            Set-Acl -Path $credFilePath -AclObject $acl

            Write-Host ""
            Write-Host "Permissions set successfully. Only $currentUser can access this file." -ForegroundColor Green
        }
        catch {
            Write-Host ""
            Write-Host "WARNING: Failed to set permissions: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "You may need to set permissions manually." -ForegroundColor Yellow
        }
    }

    exit 0
}
catch {
    Write-Error "Failed to store credentials: $($_.Exception.Message)"
    exit 1
}
