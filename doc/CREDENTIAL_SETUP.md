# Secure Credential Management Setup Guide

## Overview

This guide explains how to securely store and retrieve FileMaker admin credentials for the updater scripts with encrypted credential storage using Windows Data Protection API (DPAPI).

## Security

- Credentials encrypted using Windows DPAPI
- Encrypted file can only be decrypted by the Windows user account that created it
- Credentials excluded from version control via .gitignore
- Optional NTFS permissions restrict file access
- No passwords stored in plain text anywhere

## How It Works

### Encryption Technology
The system uses **Windows Data Protection API (DPAPI)**, which:
- Is built into Windows (no additional software needed)
- Encrypts data using keys derived from the user's Windows login
- Ensures only the encrypting user can decrypt the data
- Is the same technology used by Windows to protect saved browser passwords

### Architecture
1. **store-fmcreds.ps1** - One-time setup to encrypt and store credentials
2. **get-fmcreds.ps1** - Retrieves and decrypts credentials for use in batch scripts
3. **fmcreds.encrypted** - Encrypted credential file (never commit to git!)
4. **Batch scripts** - Call PowerShell to retrieve credentials when needed

## Initial Setup

### Step 1: Store Credentials (One-Time)

Run the storage script as the Windows user that will run the update scripts:

**Method 1: Using the batch wrapper (Recommended - easiest)**
```batch
cd B:\up
store-credentials.cmd
```

**Method 2: Using PowerShell directly**
```powershell
cd B:\up
powershell -ExecutionPolicy Bypass -File .\ps1\store-fmcreds.ps1
```

Or from within PowerShell (if file is unblocked):
```powershell
.\ps1\store-fmcreds.ps1
```

You will be prompted to:
1. Enter the FileMaker admin username
2. Enter the FileMaker admin password
3. Optionally set NTFS permissions to restrict file access (recommended)

**Example output:**
```
FileMaker Credential Storage Utility
=====================================

Please enter the FileMaker admin credentials to store securely.

cmdlet Get-Credential at command pipeline position 1
Supply values for the following parameters:
Credential

SUCCESS: Credentials encrypted and stored successfully!

File location: B:\up\fmcreds.encrypted

IMPORTANT SECURITY NOTES:
  1. These credentials can only be decrypted by the Windows user: SERVERNAME\serviceaccount
  2. Set NTFS permissions on the file to restrict access (recommended)
  3. DO NOT commit fmcreds.encrypted to version control
  4. Consider backing up this file in a secure location
```

### Step 2: Verify Setup

Test that credentials can be retrieved:

**Method 1: Using the batch wrapper (Recommended)**
```batch
test-credentials.cmd
```

**Method 2: Using PowerShell directly**
```powershell
powershell -ExecutionPolicy Bypass -File .\ps1\get-fmcreds.ps1
```

**Sample expected output:**
```
set "fmaccount=fmadmin"
set "fmpassword=y3K6f#s!4etF7"
```

### Step 3: Run Update Scripts

athenaeum-update.cmd automatically retrieve credentials, 

## How Batch Scripts Use Credentials

athenaeum-update.cmd includes this code block to retrieve credentials:

```batch
rem Retrieve credentials from encrypted storage using PowerShell
for /f "delims=" %%i in ('powershell -ExecutionPolicy Bypass -File "%~dp0get-fmcreds.ps1"') do %%i
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to retrieve credentials
    exit /b 1
)
```

This:
1. Calls PowerShell to run `get-fmcreds.ps1`
2. PowerShell outputs `set` commands
3. Batch script executes those commands to set environment variables
4. Variables `%fmaccount%` and `%fmpassword%` are now available
5. If retrieval fails, the script exits with an error

## User-Friendly Batch File Wrappers

For easier use, batch file wrappers are provided that handle all the PowerShell execution policy complexities:

| Batch File | Purpose | Usage |
|------------|---------|-------|
| **store-credentials.cmd** | Set up credentials (one-time) | Double-click or run from CMD |
| **test-credentials.cmd** | Test if credentials work | Double-click or run from CMD |
| **clear-credentials.cmd** | Remove stored credentials | Double-click or run from CMD |

**Benefits:**
- Works from CMD, PowerShell, or double-click
- Input prompts work correctly (no nested session issues)

**Recommendation:** Use the `.cmd` files for interactive credential management, and let the update scripts handle the PowerShell calls automatically.

## Troubleshooting

### Error: "Credential file not found"

**Cause:** The `fmcreds.encrypted` file doesn't exist.

**Solution:** Run the storage script to create it:
```batch
store-credentials.cmd
```

Or using PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File .\ps1\store-fmcreds.ps1
```

### Error: "Failed to retrieve credentials" or Decryption Error

**Cause:** The credentials were encrypted by a different Windows user account.

**Solution:**
1. Delete `fmcreds.encrypted`
2. Log in as the correct Windows user (the one that runs the update scripts)
3. Run `store-fmcreds.ps1` again

### Error: PowerShell Execution Policy

**Cause:** PowerShell execution policy prevents running scripts directly.

**Error Message:**
```
File B:\api_updater\store-fmcreds.ps1 cannot be loaded. The file is not digitally signed.
You cannot run this script on the current system.
```

**Solutions:**

**Option 1: Use the batch file wrappers (Easiest)**
```batch
store-credentials.cmd
test-credentials.cmd
clear-credentials.cmd
```

**Option 2: Unblock the PowerShell files**
```powershell
Unblock-File .\ps1\store-fmcreds.ps1
Unblock-File .\ps1\get-fmcreds.ps1
Unblock-File .\ps1\clear-fmcreds.ps1
Unblock-File .\ps1\fmadmin-api.ps1
```

**Option 3: Change execution policy**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Option 4: Always use -ExecutionPolicy Bypass flag**
```powershell
powershell -ExecutionPolicy Bypass -File .\ps1\store-fmcreds.ps1
```

**Note:** The batch scripts (update.cmd, all.cmd, etc.) already use the `-ExecutionPolicy Bypass` flag, so they will work without any changes.

### Error: Script stops and won't accept input

**Symptoms:**
- Script displays prompt but cursor doesn't blink
- Cannot type any input
- Script appears frozen

**Cause:** Running PowerShell from within PowerShell creates a nested session that can't read input properly.

**Example of problem:**
```powershell
PS B:\api_updater> powershell -ExecutionPolicy Bypass -File .\ps1\clear-fmcreds.ps1
# Script displays prompt but won't accept input
```

**Solutions:**

**Option 1: Use the batch file wrapper (Best)**
```batch
clear-credentials.cmd
```

**Option 2: Run from Command Prompt (not PowerShell)**
- Close PowerShell
- Open Command Prompt (CMD)
- Run: `powershell -ExecutionPolicy Bypass -File .\ps1\clear-fmcreds.ps1`

**Option 3: Run directly if file is unblocked**
```powershell
.\ps1\clear-fmcreds.ps1
```

**Option 4: Use -Force to skip the prompt**
```powershell
powershell -ExecutionPolicy Bypass -File .\ps1\clear-fmcreds.ps1 -Force
```

### Scheduled Tasks Not Working

**Cause:** Scheduled task running under different user account than the one that encrypted credentials.

**Solution:**
1. Check which user account the scheduled task runs as
2. Log in as that user
3. Run `store-fmcreds.ps1` to encrypt credentials for that user

## Security Best Practices

### Do's
✅ Run `store-fmcreds.ps1` as the same Windows user that runs the update scripts
✅ Set NTFS permissions to restrict access to `fmcreds.encrypted`
✅ Back up `fmcreds.encrypted` in a secure location (e.g., encrypted backup)
✅ Use a dedicated service account with minimum required FileMaker permissions
✅ Regularly rotate the FileMaker admin password
✅ Review Windows Event Logs for unauthorized access attempts

### Don'ts
❌ Never commit `setlog.cmd` or `fmcreds.encrypted` to version control
❌ Never copy `fmcreds.encrypted` to another computer (won't decrypt)
❌ Never share `fmcreds.encrypted` (it's tied to your Windows user)
❌ Never store the encrypted file in a publicly accessible location
❌ Never use the same password across multiple systems

## File Permissions Recommendations

### fmcreds.encrypted
```
SYSTEM: Full Control
[Your Service Account]: Full Control
```

Remove all other users and groups. This is automatically done if you choose "yes" when `store-fmcreds.ps1` asks about permissions.

### PowerShell Scripts
```
SYSTEM: Read & Execute
[Your Service Account]: Read & Execute
Administrators: Full Control
```

## Backup and Recovery

### Backing Up Credentials
1. Copy `fmcreds.encrypted` to a secure backup location
2. Document which Windows user account encrypted it
3. Store backup on encrypted storage (BitLocker, EFS, etc.)

### Recovering Credentials
1. Log in as the same Windows user that encrypted the credentials
2. Copy `fmcreds.encrypted` back to the script directory
3. Test with `.\ps1\get-fmcreds.ps1`

### What If You Lose Access?
If you lose access to the Windows user account that encrypted credentials:
- The encrypted file cannot be decrypted (this is by design for security)
- You must create new credentials using `store-fmcreds.ps1`
- Log in as the new service account and run the storage script again


## Technical Details

### File Format: fmcreds.encrypted
```
Line 1: Username (plain text)
Line 2: Encrypted password (DPAPI encrypted string)
```

### DPAPI Encryption
- **Algorithm:** AES-256 (default on Windows 10/11/Server 2016+)
- **Key Derivation:** Based on user's Windows login credentials
- **Scope:** CurrentUser (tied to specific Windows user account)

### PowerShell Commands Used
- `ConvertFrom-SecureString`: Encrypts password using DPAPI
- `ConvertTo-SecureString`: Decrypts password using DPAPI
- `Get-Credential`: Securely prompts for credentials
- `SecureStringToBSTR`: Converts SecureString to readable format for batch use

## Support and Questions

### Common Questions

**Q: Can I use this on Windows Server 2022?**
A: Yes, DPAPI is fully supported on Windows Server 2022.

**Q: What happens if I change my Windows password?**
A: DPAPI credentials remain accessible after a password change, as long as you're the same user account.

**Q: Can I automate storing credentials in a script?**
A: Yes, but it defeats the security purpose. Use `Get-Credential` interactive prompt for best security.

**Q: Is this more secure than Windows Credential Manager?**
A: It uses the same underlying technology (DPAPI). Both are equally secure.

**Q: Should I use Group Managed Service Accounts (gMSA) instead?**
A: If you're in an Active Directory environment and the FileMaker server supports it, gMSA is more secure because passwords are automatically rotated.

## Credits

© 2026 Rob Russell, SumWare Consulting
Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
https://creativecommons.org/licenses/by-sa/4.0/

Implementation by Claude Code based on Windows Server 2022 security best practices.
