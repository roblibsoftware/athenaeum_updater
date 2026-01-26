param(
    [string]$DownloadUrl = "https://librarysoftware.co.nz/download/up/athenaeum_clone.fmp12.zip",
    [string]$CloneFile = "athenaeum_clone.fmp12"
)

# Enable ANSI color support
$ESC = [char]27

# Set paths
$ScriptDirectory = $PSScriptRoot
$DownloadZip = Join-Path $ScriptDirectory "$CloneFile.zip"
$CloneDir = Join-Path $ScriptDirectory "clone"
$DownloadFile = Join-Path $CloneDir $CloneFile

# Function to write colored error messages
function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "$ESC[101;93m$Message$ESC[0m"
}

function Write-SuccessMessage {
    param([string]$Message)
    Write-Host "$ESC[102;30m$Message$ESC[0m"
}

# Create clone directory if it doesn't exist
if (-not (Test-Path $CloneDir)) {
    New-Item -ItemType Directory -Path $CloneDir | Out-Null
}

# Clean up previous downloads
Remove-Item "$ScriptDirectory/zip.log" -ErrorAction SilentlyContinue
Remove-Item $DownloadZip -ErrorAction SilentlyContinue
Remove-Item $DownloadFile -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Downloading clone file..."

# Download the zipped clone file using Invoke-WebRequest
try {
    $ProgressPreference = 'SilentlyContinue'  # Speeds up download significantly
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadZip -ErrorAction Stop
    $ProgressPreference = 'Continue'
}
catch {
    Write-ErrorMessage "ERROR: Failed to download file from $DownloadUrl"
    Write-ErrorMessage "Error: $($_.Exception.Message)"
    exit 3
}

# Verify the download exists
if (-not (Test-Path $DownloadZip)) {
    Write-ErrorMessage "ERROR: Downloaded file not found: $DownloadZip"
    exit 4
}

Write-Host "Unzipping file..."

# Unzip it using PowerShell's Expand-Archive
try {
    # Create temporary extraction directory
    $TempExtract = Join-Path $ScriptDirectory "temp_extract"
    if (Test-Path $TempExtract) {
        Remove-Item $TempExtract -Recurse -Force
    }
    New-Item -ItemType Directory -Path $TempExtract | Out-Null

    # Extract the archive
    Expand-Archive -Path $DownloadZip -DestinationPath $TempExtract -Force -ErrorAction Stop

    # Find the clone file in the extracted contents
    $ExtractedFile = Get-ChildItem -Path $TempExtract -Filter $CloneFile -Recurse | Select-Object -First 1

    if (-not $ExtractedFile) {
        Write-ErrorMessage "ERROR: Could not find $CloneFile in the extracted archive"
        Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue
        exit 6
    }

    # Move the file to the clone directory
    Move-Item -Path $ExtractedFile.FullName -Destination $DownloadFile -Force -ErrorAction Stop

    # Clean up temp directory
    Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue

    Write-SuccessMessage "Extraction successful"
}
catch {
    Write-ErrorMessage "ERROR: Failed to unzip file"
    Write-ErrorMessage "Error: $($_.Exception.Message)"
    exit 5
}

# Verify the file was moved successfully
if (-not (Test-Path $DownloadFile)) {
    Write-ErrorMessage "ERROR: Failed to move file to clone folder"
    exit 7
}

# Clean up
Remove-Item $DownloadZip -ErrorAction SilentlyContinue

Write-Host ""
Write-SuccessMessage "Clone file downloaded and extracted successfully"
Write-Host ""

# List files in clone directory
Write-Host "Files in clone directory:"
Write-Host "$ESC[101;93m"
Get-ChildItem -Path $CloneDir -Filter "a*.*" | Where-Object { $_.Name -match "athen" } | ForEach-Object {
    Write-Host $_.Name
}
Write-Host "$ESC[0m"

exit 0
