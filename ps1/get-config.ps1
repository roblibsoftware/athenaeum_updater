# get-config.ps1
# Reads the updater configuration from config.json (compulsory) and emits a
# single value for the batch scripts to capture.
#
# Usage:
#   get-config.ps1 -Key host    -> prints the FileMaker host name
#   get-config.ps1 -Key live    -> prints the live databases folder
#                                   (forward slashes normalized to \, one trailing \)
#   get-config.ps1 -Key files   -> prints each database file name on its own line
#
# config.json is REQUIRED. A missing file, invalid JSON, or a missing/empty
# host/live/files value is a fatal error (message to stderr, non-zero exit),
# so the calling script aborts instead of running with bad configuration.
#
# © 2026 Rob Russell, SumWare Consulting
# Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('host', 'live', 'files')]
    [string]$Key
)

$ErrorActionPreference = 'Stop'

# config.json lives in the parent folder (this script is in ps1\)
$configPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'config.json'

if (-not (Test-Path $configPath)) {
    [Console]::Error.WriteLine("ERROR: config.json not found at $configPath")
    exit 1
}

try {
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
}
catch {
    [Console]::Error.WriteLine("ERROR: config.json is not valid JSON: $($_.Exception.Message)")
    exit 1
}

switch ($Key) {
    'host' {
        $value = "$($config.host)".Trim()
        if ([string]::IsNullOrWhiteSpace($value)) {
            [Console]::Error.WriteLine("ERROR: config.json is missing a 'host' value")
            exit 1
        }
        Write-Output $value
    }

    'live' {
        $value = "$($config.live)".Trim()
        if ([string]::IsNullOrWhiteSpace($value)) {
            [Console]::Error.WriteLine("ERROR: config.json is missing a 'live' value")
            exit 1
        }
        # Normalize: forward slashes -> backslashes, guarantee exactly one trailing backslash
        $value = ($value -replace '/', '\').TrimEnd('\') + '\'
        Write-Output $value
    }

    'files' {
        $files = @($config.files)
        if ($files.Count -eq 0) {
            [Console]::Error.WriteLine("ERROR: config.json 'files' must be a non-empty array")
            exit 1
        }
        $emitted = 0
        foreach ($f in $files) {
            $name = "$f".Trim()
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                Write-Output $name
                $emitted++
            }
        }
        if ($emitted -eq 0) {
            [Console]::Error.WriteLine("ERROR: config.json 'files' contains no usable file names")
            exit 1
        }
    }
}

exit 0
