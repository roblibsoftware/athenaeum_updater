# clear-fmcreds.ps1
# Removes stored FileMaker admin credentials
#
# © 2026 Rob Russell, SumWare Consulting
# Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "FileMaker Credential Removal Utility" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Path to encrypted credential file (stored in parent directory)
    $parentDir = Split-Path $PSScriptRoot -Parent
    $credFilePath = Join-Path $parentDir "fmcreds.encrypted"

    # Check if credential file exists
    if (-not (Test-Path $credFilePath)) {
        Write-Host "No credential file found at: $credFilePath" -ForegroundColor Yellow
        Write-Host "Nothing to clear." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Found encrypted credential file at:" -ForegroundColor Green
    Write-Host "  $credFilePath" -ForegroundColor Green
    Write-Host ""

    # Confirm deletion unless -Force is used
    if (-not $Force) {
        Write-Host "WARNING: This will delete the encrypted credentials." -ForegroundColor Yellow
        Write-Host "You will need to run ps1\store-fmcreds.ps1 again to re-create them." -ForegroundColor Yellow
        Write-Host ""
        $confirm = Read-Host "Are you sure you want to delete the credentials? (yes/no)"

        if ($confirm -ne "yes") {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Delete the credential file
    Remove-Item -Path $credFilePath -Force

    Write-Host ""
    Write-Host "SUCCESS: Encrypted credentials have been removed." -ForegroundColor Green
    Write-Host ""
    Write-Host "To create new credentials, run:" -ForegroundColor Cyan
    Write-Host "  .\ps1\store-fmcreds.ps1" -ForegroundColor Cyan
    Write-Host ""

    exit 0
}
catch {
    Write-Error "Failed to remove credentials: $($_.Exception.Message)"
    exit 1
}
