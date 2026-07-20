# FileMaker Updater Script Improvements

## Overview

This document describes the improvements made to the FileMaker database updater scripts on 2026-01-23. The primary focus was adding robust error handling, validation, and comment filtering capabilities to ensure reliable operation and better failure recovery.

## Modified Files

### 1. download_clone.cmd

**Purpose:** Downloads and extracts the FileMaker clone database file from the web server.

**Key Improvements:**

#### Error Detection and Handling
- **Download Validation:**
  - Downloads the clone with PowerShell `Invoke-WebRequest`
  - Verifies downloaded file actually exists on disk
  - Exit code 3: download failed
  - Exit code 4: downloaded file not found
- **Extraction Validation:**
  - Extracts with PowerShell `Expand-Archive`
  - Confirms the clone file is present in the extracted archive
  - Exit code 5: extraction failed
  - Exit code 6: clone file not found in archive
- **File Move Validation:**
  - Verifies file successfully moved to clone folder
  - Exit code 7: move operation failed

#### User Experience Improvements
- Color-coded error messages (red background) for visibility
- Color-coded success messages (green background)
- Progress messages during download and extraction
- Detailed error reporting with specific exit codes
- Automatic creation of clone directory if missing
- Cleaner output with suppressed error messages for cleanup operations

#### Robustness
- All critical operations now check return codes
- Each failure type has a unique exit code for debugging
- Script exits immediately on any critical failure
- Returns exit code 0 only on complete success

### 2. athenaeum-update.cmd

**Purpose:** Orchestrates the update process by downloading the clone file and processing files listed in file_list.txt.

**Key Improvements:**

#### Error Detection and Handling
- **Download Validation:**
  - Checks ERRORLEVEL after calling download_clone.cmd
  - Aborts entire update process if download_clone.cmd fails
  - Displays error code to help diagnose the failure
  - Includes pause for user acknowledgment before exit
  - Returns the same error code as download_clone.cmd

#### Comment and Line Filtering
- **Comment Support:**
  - Skips lines starting with `#` (Unix-style comments)
  - Skips lines starting with `;` (INI-style comments)
  - Skips lines starting with `rem` (DOS/Windows comments)
  - Provides feedback when skipping commented lines
- **Blank Lines:**
  - Automatically skipped by FOR /F loop processing

#### Update Error Handling
- **Per-File Error Checking:**
  - Monitors ERRORLEVEL after each update.cmd call
  - Displays warning message if update.cmd fails for a specific file
  - Continues processing remaining files (default behavior)
  - Includes commented option to abort on first update.cmd failure

#### User Experience Improvements
- Color-coded status messages
- Clear "Starting file updates..." and "Update process complete" messages
- Shows which files are being processed
- Shows which lines are being skipped as comments
- Better visual separation between phases

### 3. .gitignore (New File)

**Purpose:** Prevents unnecessary files from being tracked in version control.

**Includes:**
- System files (.DS_Store, Thumbs.db)
- Log files (*.log, zip.log)
- Temporary files (*.tmp, *.temp)
- Downloaded files (clone/ directory)
- Zip files (*.zip)

## Error Code Reference

### download_clone.cmd Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - file downloaded and extracted |
| 3 | Invoke-WebRequest failed to download file |
| 4 | Downloaded file not found after download |
| 5 | Expand-Archive extraction failed |
| 6 | Clone file not found in extracted archive |
| 7 | Failed to move file to clone folder |

### athenaeum-update.cmd Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - all updates completed |
| 1-7 | Propagated from download_clone.cmd failure |

## Usage Examples

### Basic Usage
```batch
athenaeum-update.cmd
```

### With Comments in file_list.txt
```
# This is a comment line - will be skipped
; This is also a comment - will be skipped
rem Another comment format - will be skipped
trial_athenaeum
```

Each non-comment line lists a single database file name (no folder token). Files are read from and written back to the live folder configured in live.txt.

### Error Scenarios

**Scenario 1: Download Failure**
```
Downloading clone file...
ERROR: Failed to download file from https://...
ERROR: download_clone.cmd failed with error code 3
Aborting update process.
```

**Scenario 2: Extraction Failure**
```
Unzipping file...
ERROR: Failed to unzip file
ERROR: download_clone.cmd failed with error code 5
Aborting update process.
```

## Future Considerations

### Potential Enhancements
1. **Retry Logic:** Add automatic retry on download failures
2. **Logging:** Write detailed log files for troubleshooting
3. **Email Notifications:** Send alerts on failures
4. **Backup:** Create backups before updates
5. **Validation:** Add checksum validation for downloads
6. **Configuration File:** Move hardcoded paths to config file

### Strictness Options
The current implementation continues processing files even if individual update.cmd calls fail. To change this behavior to abort on first failure, uncomment this line in athenaeum-update.cmd:

```batch
rem exit /b %ERRORLEVEL%
```

## Testing Recommendations

1. Test the dry run (`athenaeum-update.cmd /dryrun`)
2. Test with an invalid download URL
3. Test with a corrupted/incomplete archive
4. Test with various comment formats in file_list.txt
5. Test with blank lines in file_list.txt
6. Test network disconnection during download
7. Test with missing or wrong credentials

## Compatibility

- **Windows Version:** Windows 7 and later
- **Required Tools:**
  - Windows PowerShell 5.1 (downloads and extraction use `Invoke-WebRequest` and `Expand-Archive` natively - no curl or 7-Zip)
- **Dependencies:** update.cmd must exist and function properly

## Version History

- **2026-07-20:** Single `config.json` and connectivity fixes
  - Consolidated `host.txt`, `live.txt`, and `file_list.txt` into a single
    `config.json` with `host`, `live`, and `files` (a JSON array) keys. Any
    other key (e.g. `_comment`) is ignored, so the file can be self-documenting.
  - `config.json` is now **compulsory** — a new `ps1/get-config.ps1` reader
    validates it and fails loudly on a missing file, invalid JSON, or a
    missing/empty value; there are no built-in defaults. The `live` path
    accepts forward slashes (normalized to `\`, trailing slash guaranteed).
  - `store-fmcreds.ps1` now prompts inline via `Read-Host` instead of the
    `Get-Credential` GUI dialog (which could open hidden or be cancelled).
  - Added a `list` operation to `fmadmin-api.ps1`; `list-databases.cmd` and
    dry-run step 4 now call it instead of inline PowerShell. The compiled
    certificate callback reliably handles the server's TLS renegotiation
    (an inline scriptblock callback failed on send).
  - `test-api.ps1` enables TLS 1.3 where available and reports inner exceptions.
- **2026-06-30:** Single-file simplification
  - Renamed `batch-one.cmd` to `athenaeum-update.cmd` and `one_file_list.txt` to `file_list.txt`
  - `file_list.txt` now uses a single token per line (file name only); the folder token was removed
  - `update.cmd` takes only `%1` (file name); the `%2` folder parameter and its empty-argument guard were removed
  - Moved the hard-coded live database path out of `update.cmd` into its own `live.txt` config file (read like `host.txt`, with the previous path as the fallback default)
  - Databases are now read from and written directly to the live folder (no per-file subfolder)
  - Added a dry-run mode to `athenaeum-update.cmd` (`/dryrun`) that validates config files and credentials, logs in to the Admin API and lists the databases on the server, and tests download capability against a small file - all without downloading the clone or changing any database
  - Corrected the docs to reflect the PowerShell-native download/extract (`Invoke-WebRequest` + `Expand-Archive`); curl and 7-Zip are no longer used
  - Added `doc/instructions.md` documenting the setup, testing, and execution processes
- **2026-01-23:** Initial improvements - Added error handling and comment filtering
- **Previous:** Original implementation with basic functionality

## Author

Improvements implemented by Claude Code based on user requirements.

Original scripts: © 2018-2026 Rob Russell, SumWare Consulting
License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
