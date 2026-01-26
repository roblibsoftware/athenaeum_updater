# FileMaker Server Admin API Integration

## Overview

This document describes the integration of FileMaker Server Admin API v2 into the update scripts, replacing the legacy `fmsadmin.exe` command-line tool with modern RESTful API calls.

**Migration Date:** 2026-01-23

## Why the Change?

### Benefits of Admin API vs fmsadmin.exe

1. **Modern RESTful Interface**
   - JSON-based requests/responses
   - Standard HTTP/HTTPS protocol
   - Better error handling and status codes

2. **More Granular Control**
   - Force disconnect specific database clients only
   - Better status reporting
   - Graceful shutdown with customizable grace periods

3. **Better Integration**
   - Easier to integrate with automation tools
   - Works remotely without special configuration
   - Token-based authentication (more secure)

4. **Future-Proof**
   - FileMaker Server Admin API is the current recommended approach
   - fmsadmin.exe may be deprecated in future versions
   - Active development and improvements from Claris

## Architecture

### Components

**1. fmadmin-api.ps1** - PowerShell API Helper
- Handles all FileMaker Server Admin API operations
- Manages authentication tokens
- Provides operations: login, close, open, logout, get-status
- Returns proper exit codes for batch script integration

**2. update.cmd** - Updated Batch Script
- Uses PowerShell helper for all FileMaker operations
- Implements complete workflow with error handling
- Automatic rollback on failure
- Detailed logging and status reporting

**3. update1.cmd / all.cmd**
- Orchestrate calls to update.cmd
- No changes needed (update.cmd handles API internally)

## API Operations

### 1. Login (Authentication)

**Purpose:** Obtain authentication token for API operations

**PowerShell Usage:**
```powershell
.\fmadmin-api.ps1 -Operation login -FileMakerHost "localhost" -Username "admin" -Password "password"
```

**Returns:** Authentication token (string)

**Batch Usage:**
```batch
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation login -FileMakerHost "%fmhost%" -Username "%fmaccount%" -Password "%fmpassword%"') do set fmtoken=%%i
```

**API Endpoint:** `POST https://{host}/fmi/admin/api/v2/user/auth`

**Error Codes:**
- Exit 0: Success, token returned
- Exit 1: Authentication failed

---

### 2. Close Database

**Purpose:** Close a specific database and optionally force disconnect clients

**PowerShell Usage:**
```powershell
.\fmadmin-api.ps1 -Operation close -FileMakerHost "localhost" -Token $token -DatabaseName "mydb.fmp12" -ForceDisconnect -GracePeriod 0
```

**Parameters:**
- `-ForceDisconnect` (switch): Force disconnect clients connected to this database
- `-GracePeriod` (int): Seconds to wait before forcing disconnect (default: 0)

**Batch Usage:**
```batch
powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation close -FileMakerHost "%fmhost%" -Token "%fmtoken%" -DatabaseName "%dbfilename%" -ForceDisconnect -GracePeriod 0
```

**API Endpoint:** `PUT https://{host}/fmi/admin/api/v2/databases/{database}/close`

**Request Body:**
```json
{
  "messageText": "Database closing for update",
  "force": true,
  "gracePeriod": 0
}
```

**Error Codes:**
- Exit 0: Database closed successfully
- Exit 1: Close operation failed (database not found, in use, etc.)

---

### 3. Open Database

**Purpose:** Open a closed database on FileMaker Server

**PowerShell Usage:**
```powershell
.\fmadmin-api.ps1 -Operation open -FileMakerHost "localhost" -Token $token -DatabaseName "mydb.fmp12"
```

**Batch Usage:**
```batch
powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation open -FileMakerHost "%fmhost%" -Token "%fmtoken%" -DatabaseName "%dbfilename%"
```

**API Endpoint:** `PUT https://{host}/fmi/admin/api/v2/databases/{database}/open`

**Error Codes:**
- Exit 0: Database opened successfully
- Exit 1: Open operation failed

---

### 4. Get Database Status

**Purpose:** Check if a database is open or closed

**PowerShell Usage:**
```powershell
.\fmadmin-api.ps1 -Operation get-status -FileMakerHost "localhost" -Token $token -DatabaseName "mydb.fmp12"
```

**Returns:** Status string ("NORMAL", "CLOSED", etc.)

**API Endpoint:** `GET https://{host}/fmi/admin/api/v2/databases/{database}`

**Error Codes:**
- Exit 0: Status retrieved successfully
- Exit 1: Failed to get status

---

### 5. Logout

**Purpose:** Invalidate the authentication token

**PowerShell Usage:**
```powershell
.\fmadmin-api.ps1 -Operation logout -FileMakerHost "localhost" -Token $token
```

**Batch Usage:**
```batch
powershell -ExecutionPolicy Bypass -File "%~dp0fmadmin-api.ps1" -Operation logout -FileMakerHost "%fmhost%" -Token "%fmtoken%"
```

**API Endpoint:** `DELETE https://{host}/fmi/admin/api/v2/user/auth/{token}`

**Error Codes:**
- Exit 0: Logout successful
- Exit 1: Logout failed (token already invalid)

---

## Update Workflow

The new update.cmd implements this workflow:

### Step-by-Step Process

**1. Authenticate**
- Retrieve credentials from encrypted storage (get-fmcreds.ps1)
- Login to FileMaker Server Admin API
- Obtain authentication token

**2. Close Database**
- Close the specific database being updated
- Force disconnect any connected clients
- Fail immediately if database cannot be closed

**3. Copy Live Database**
- Copy the closed database to working directory
- On failure: reopen database and abort

**4. Run Migration**
- Execute FMDataMigration tool
- Migrate data from old schema to new schema

**5. Handle Migration Result**

**If migration succeeds:**
- Delete old database from live folder
- Copy updated database to live folder
- Open the updated database
- Logout from API
- Exit with success

**If migration fails:**
- Discard failed migration output
- Reopen the original database
- Logout from API
- Exit with error code

### Error Handling Strategy

**At each step:**
1. Check exit code / ERRORLEVEL
2. Log the operation result
3. On failure:
   - Display clear error message
   - Attempt recovery (reopen database if needed)
   - Cleanup (logout from API)
   - Exit with non-zero code

**Critical Failure Points:**
- **Cannot close database** → Abort, don't proceed
- **Cannot copy file** → Abort, reopen database
- **Migration fails** → Abort, reopen database, discard changes
- **Cannot copy updated file** → Critical error (database closed, no version available)
- **Cannot open updated database** → Warning, may need manual intervention

## Configuration

### FileMaker Server Settings

Edit these variables in `update.cmd`:

```batch
rem FileMaker Server settings
set fmhost=localhost
set dbfilename=%1.fmp12
```

**fmhost:**
- Default: `localhost`
- Change to server hostname or IP if FileMaker Server is remote
- Examples: `fmserver.example.com`, `192.168.1.100`

**dbfilename:**
- Automatically constructed from the first parameter (%1)
- Must include the `.fmp12` extension

### SSL Certificate Handling

By default, `fmadmin-api.ps1` ignores SSL certificate validation errors. This is necessary for self-signed certificates.

**For self-signed certificates (default):**
- No changes needed
- Script will work with default FileMaker Server installation

**For valid SSL certificates:**
Remove this section from `fmadmin-api.ps1`:

```powershell
# Remove this entire block if using valid SSL certificates
if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
    Add-Type @"
        using System;
        using System.Net;
        using System.Net.Security;
        using System.Security.Cryptography.X509Certificates;
        public class ServerCertificateValidationCallback {
            public static void Ignore() {
                ServicePointManager.ServerCertificateValidationCallback =
                    delegate(...) { return true; };
            }
        }
"@
}
[ServerCertificateValidationCallback]::Ignore()
```

## Comparison: fmsadmin.exe vs Admin API

### Old Method (fmsadmin.exe)

```batch
rem List files
fmsadmin list files -u%fmaccount% -p%fmpassword% >> %log%

rem Close file
fmsadmin close %1.fmp12 -y -f -t 0 -u%fmaccount% -p%fmpassword% >> %log%

rem Open file
fmsadmin open %1.fmp12 -yf -u%fmaccount% -p%fmpassword% >> %log%
```

**Issues:**
- Closes ALL clients (not just clients of this database)
- Limited error reporting
- Command-line parsing can be fragile
- Requires local access or special configuration

### New Method (Admin API)

```batch
rem Get token
for /f "delims=" %%i in ('powershell ... -Operation login ...') do set fmtoken=%%i

rem Close specific database
powershell ... -Operation close ... -DatabaseName "%dbfilename%" -ForceDisconnect

rem Open database
powershell ... -Operation open ... -DatabaseName "%dbfilename%"

rem Logout
powershell ... -Operation logout ... -Token "%fmtoken%"
```

**Advantages:**
- Targets specific database only
- Better error messages (JSON responses)
- Works remotely without special setup
- Token-based security (credentials not passed repeatedly)
- More control (grace periods, force options, etc.)

## Troubleshooting

### Error: "Failed to authenticate with FileMaker Server"

**Possible Causes:**
1. FileMaker Server not running
2. Invalid credentials
3. Admin Console API not enabled
4. Firewall blocking HTTPS

**Solutions:**
1. Verify FileMaker Server is running: `fmsadmin status`
2. Check credentials in encrypted storage: `.\get-fmcreds.ps1`
3. Verify Admin Console API is enabled (FileMaker Server Admin Console → Configuration → Admin API)
4. Check firewall allows HTTPS (port 443) to FileMaker Server

---

### Error: "Failed to close database"

**Possible Causes:**
1. Database name incorrect
2. Database already closed
3. Database not found
4. Insufficient permissions

**Solutions:**
1. Verify database name includes `.fmp12` extension
2. Check database status in Admin Console
3. Verify database exists in FileMaker Server Databases folder
4. Ensure admin account has full access

---

### Error: "SSL connection failed" or Certificate Errors

**Possible Causes:**
1. Self-signed certificate (normal for FileMaker Server)
2. Certificate validation not disabled in script

**Solutions:**
1. Verify the SSL certificate ignore code is present in `fmadmin-api.ps1`
2. If using valid certificate, ensure it's trusted by Windows

---

### Error: "Failed to reopen database"

**Critical Issue:** This means the database is closed but couldn't be reopened.

**Immediate Actions:**
1. Manually open database in FileMaker Server Admin Console
2. Check FileMaker Server logs for errors
3. Verify database file integrity
4. Check file permissions

---

### Error: "Database closed but new version not deployed"

**Critical Issue:** Old database deleted, new version failed to copy.

**Immediate Actions:**
1. Check disk space on server
2. Verify file permissions on live database folder
3. Check if file is locked by another process
4. Manually copy `new\{database}.fmp12` to `live_databases\{folder}\`
5. Manually open database in Admin Console

## API Reference

### FileMaker Server Admin API v2 Documentation

**Official Documentation:**
https://help.claris.com/en/server-admin-api/

**Base URL:**
```
https://{hostname}/fmi/admin/api/v2
```

**Authentication:**
- Method: Bearer token
- Header: `Authorization: Bearer {token}`
- Token obtained via POST to `/user/auth`
- Tokens expire after 15 minutes of inactivity

**Common Response Format:**
```json
{
  "response": {
    // Response data
  },
  "messages": [
    {
      "code": "0",
      "message": "OK"
    }
  ]
}
```

**Success Codes:**
- `"0"` = Success

**Common Error Codes:**
- `"212"` = Invalid username/password
- `"802"` = Unable to open file
- `"10900"` = Authentication token is invalid

## Security Considerations

### Token Management

**Tokens are:**
- Valid for 15 minutes of inactivity
- Invalidated on logout
- Transmitted over HTTPS only
- Stored in memory only (not on disk)

**Best Practices:**
1. Always logout when done (cleanup)
2. Never log tokens to files
3. Use HTTPS only (never HTTP)
4. Keep credentials encrypted (using fmcreds.encrypted)

### Network Security

**Recommendations:**
1. Use firewall rules to restrict API access
2. Consider VPN for remote administration
3. Enable audit logging on FileMaker Server
4. Regularly review Admin Console logs
5. Use strong passwords for admin accounts

### Credentials

**Storage:**
- Admin credentials stored in `fmcreds.encrypted`
- Encrypted using Windows DPAPI
- Only decryptable by the Windows user who encrypted them

**See:** `CREDENTIAL_SETUP.md` for credential security details

## Performance Considerations

### API Call Overhead

Each PowerShell invocation has ~1-2 second overhead:
- Process startup
- Script loading
- SSL handshake
- API call

**Optimization:**
- Reuse authentication token across operations (we do this)
- Minimize number of API calls
- Use batch operations where possible

### Timeout Settings

**Default timeouts:**
- PowerShell: 100 seconds
- FileMaker API: 30 seconds

**Adjust if needed** for large databases or slow networks.

## Migration from fmsadmin.exe

### Changes Made

**Removed:**
- All `fmsadmin` commands
- Client disconnect logic (was disconnecting ALL clients)
- File list checking (was listing all open files)

**Added:**
- PowerShell API helper (`fmadmin-api.ps1`)
- Token-based authentication
- Specific database close/open
- Better error handling and recovery
- Detailed step-by-step logging

**Behavior Changes:**
- **Force disconnect now targets specific database only** (not all clients)
- Authentication happens once per update (not per command)
- More detailed error messages
- Automatic rollback on migration failure

### Testing Recommendations

Before using in production:

1. **Test authentication:**
   ```batch
   powershell -File fmadmin-api.ps1 -Operation login -FileMakerHost localhost -Username admin -Password test
   ```

2. **Test close/open cycle:**
   ```batch
   update.cmd testdatabase testfolder
   ```
   (Use a non-critical test database first)

3. **Test failure scenarios:**
   - What happens if migration fails?
   - What happens if network disconnects mid-update?
   - What happens if disk space runs out?

4. **Verify logs:**
   - Check `log\{database}.txt` for detailed operation logs
   - Verify error messages are clear and actionable

## Changelog

**2026-01-23 - Initial API Integration**
- Created fmadmin-api.ps1 PowerShell helper
- Updated update.cmd to use Admin API instead of fmsadmin.exe
- Implemented token-based authentication
- Added automatic rollback on migration failure
- Improved error handling and logging
- Updated documentation

## Future Enhancements

### Potential Improvements

1. **Progress Monitoring**
   - Real-time migration progress via API
   - Estimated time remaining

2. **Backup Before Update**
   - Automatic backup to backup folder before migration
   - Retention policy for old backups

3. **Email Notifications**
   - Success/failure notifications
   - Error alerts to administrators

4. **Scheduled Updates**
   - Integration with Windows Task Scheduler
   - Automatic updates during maintenance windows

5. **Multi-Database Updates**
   - Parallel updates (for independent databases)
   - Dependency-aware update ordering

6. **Health Checks**
   - Pre-update validation
   - Post-update verification
   - Automatic rollback if health checks fail

## Credits

© 2026 Rob Russell, SumWare Consulting
Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
https://creativecommons.org/licenses/by-sa/4.0/

FileMaker Server Admin API integration implemented by Claude Code.
