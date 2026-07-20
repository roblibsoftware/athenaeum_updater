# Athenaeum Update Tools - Setup & Execution

This guide describes how to set up, test, and run the FileMaker database
update tools in this folder. The process downloads a fresh clone of the
Athenaeum database, migrates the live data into it using FileMaker Data
Migration, and redeploys the updated file to the FileMaker Server.

## Contents

- [Prerequisites](#prerequisites)
- [Setup](#setup)
  - [1. Configure host.txt](#1-configure-hosttxt)
  - [2. Configure live.txt](#2-configure-livetxt)
  - [3. Configure file_list.txt](#3-configure-file_listtxt)
  - [4. Store credentials](#4-store-credentials)
- [Testing the setup](#testing-the-setup)
  - [Test 1: Stored credentials](#test-1-stored-credentials)
  - [Test 2: List databases on the server](#test-2-list-databases-on-the-server)
  - [Test 3: Dry run](#test-3-dry-run)
  - [Additional connection tests](#additional-connection-tests)
- [Execution](#execution)
- [What the update does (per file)](#what-the-update-does-per-file)
- [Logs and troubleshooting](#logs-and-troubleshooting)
- [Resetting credentials](#resetting-credentials)

---

## Prerequisites

Run these tools on the machine that hosts (or can reach) FileMaker Server.
The following must be installed and available:

- **Windows 10 or later** with **Windows PowerShell 5.1** (the bundled scripts assume this).
- **PowerShell native networking** - `download_clone.cmd` downloads the clone with `Invoke-WebRequest` and unzips it with `Expand-Archive`. No curl or 7-Zip is required.
- **FMDataMigration** - the FileMaker Data Migration command-line tool, on the `PATH`.
- **FileMaker Server Admin API (v2)** reachable over HTTPS on the configured host.
- A FileMaker Server **admin account** (used to close/open databases via the Admin API).

The migration account/password used to open the source and clone files is
currently fixed to `migrate` / `migrate` inside `update.cmd`.

---

## Setup

All configuration lives in three small text files plus an encrypted
credential file. Configure them in this order.

### 1. Configure host.txt

`host.txt` holds the single host name of the FileMaker Server, on one line.
If the file is missing, the tools default to `localhost`.

```
database.kings.school.nz
```

> **Important — use the exact host name on the server's SSL certificate, not
> `localhost` or an IP address.** On Windows, FileMaker Server serves the
> Admin API through IIS/HTTP.sys, and the SSL certificate is bound to a
> specific host name (an SNI binding). HTTP.sys only completes a TLS
> handshake when the client sends that exact name. Connecting as `localhost`
> or by IP sends no matching name, so the server silently resets the
> connection and every tool fails with errors like *"The underlying
> connection was closed: An unexpected error occurred on a send"* or a TLS
> reset — even when run directly on the server machine.
>
> Set `host.txt` to the certificate's host name (e.g.
> `database.kings.school.nz`) and make sure that name resolves to, and can
> reach, the server. To confirm before running the tools:
>
> ```
> curl.exe -v -k https://<host-from-host.txt>/fmi/admin/api/v2/user/auth
> ```
>
> A completed TLS handshake and an HTTP `405` (with a FileMaker JSON body)
> means the host name is correct. A `Connection was reset` means the name
> doesn't match the certificate binding.

### 2. Configure live.txt

`live.txt` holds the path to the FileMaker Server **live databases folder**,
on one line, including the trailing backslash. This is where databases are
read from and written back to. If the file is missing, `update.cmd` falls
back to the standard install path.

```
C:\Program Files\FileMaker\FileMaker Server\Data\Databases\
```

Databases are read from and written directly to this folder (there are no
per-file subfolders).

### 3. Configure file_list.txt

`file_list.txt` lists the databases to update - **one file name per line**,
without the `.fmp12` extension and without any folder. Comment lines are
ignored.

```
# raw athenaeum file names
trial_athenaeum
```

Comment / blank line rules:

- Lines starting with `#`, `;`, or `rem` are skipped.
- Blank lines are skipped automatically.
- Each remaining line is a single database file name (one token, no spaces).

### 4. Store credentials

The FileMaker Server admin credentials are stored encrypted with the Windows
Data Protection API (DPAPI), so they can only be decrypted by the **same
Windows user account** that stored them.

Run:

```bat
store-credentials.cmd
```

You will be prompted for the admin **username** and **password**. They are
written to `fmcreds.encrypted` in this folder.

> Run `store-credentials.cmd` under the same Windows account that will run
> `athenaeum-update.cmd`, or the credentials cannot be decrypted later.

---

## Testing the setup

Before running a real update, confirm each piece works. Start with the
quickest checks and finish with a full dry run.

### Test 1: Stored credentials

Confirm the encrypted credentials exist and can be decrypted by the current
Windows account:

```bat
test\test-credentials.cmd
```

A success message means the credentials were retrieved. An error means you
need to (re)run `store-credentials.cmd` under the correct account.

### Test 2: List databases on the server

Confirm host, credentials, and connectivity all work together, and that the
server returns the expected database names:

```bat
list-databases.cmd
```

This logs in to the Admin API and prints every database the server knows
about, with its status. Use it to confirm that the names in
`file_list.txt` match the live file names exactly.

### Test 3: Dry run

Run the orchestrator in **dry-run mode**. This validates the configuration,
checks the stored credentials, lists the databases on the server, and tests
the download capability - **without downloading the clone or changing any
database**:

```bat
athenaeum-update.cmd /dryrun
```

The dry run checks, in order:

1. `host.txt`, `live.txt`, and `file_list.txt` are present (and shows the host and live path).
2. The stored credentials can be retrieved.
3. A login to the FileMaker Server Admin API succeeds.
4. Using the token from step 3, it lists the databases on the FileMaker Server, then logs out. Compare this list against the names in `file_list.txt`.
5. The download capability works - it fetches a small test file (`https://librarysoftware.co.nz/downloads/build.txt`) from the same host. This confirms the host domain is reachable and not blocked by a firewall, without downloading the full clone.

If every step reports `[OK]`, the setup is ready for a live run.
(`/dryrun`, `-dryrun`, `--dry-run`, and `/d` are all accepted.)

### Additional connection tests

The `test\` folder contains a focused script for diagnosing Admin API
connectivity against the live server:

- `test\test-api.cmd` - exercise the FileMaker Server Admin API helper directly.

---

## Execution

Once the dry run passes, run a live update:

```bat
athenaeum-update.cmd
```

The orchestrator will:

1. Run `download_clone.cmd` to download and extract the fresh clone into
   `clone\athenaeum_clone.fmp12`. If this fails, the whole run aborts.
2. Read `file_list.txt` and, for each non-comment file name, call
   `update.cmd <file name>`.

A warning is shown if `update.cmd` fails for an individual file, but
processing continues to the next file by default. To abort on the first
failure instead, uncomment the `rem exit /b %ERRORLEVEL%` line in
`athenaeum-update.cmd`.

---

## What the update does (per file)

For each file, `update.cmd` performs these steps (all detail is written to a
per-file log):

1. Ensures the working folders exist (`source`, `backup`, `clone`, `new`, `log`).
2. Reads the live path from `live.txt` and the host from `host.txt`.
3. Authenticates with the FileMaker Server Admin API.
4. Closes the live database (force-disconnects clients).
5. Copies the live file from the live folder into `source\`.
6. Runs FileMaker Data Migration: live data (`source`) into the new clone,
   producing the migrated file in `new\`.
7. Deletes the old file from the live folder and copies the migrated file
   back in its place.
8. Re-opens the database and logs out of the Admin API.

On failure at most steps, the script attempts to reopen the original
database and logs out cleanly so the server is left in a usable state.

---

## Logs and troubleshooting

- Each file writes a detailed log to `log\<file name>.txt`. Check it first
  when a run fails.
- Migration errors are surfaced at the console and the log is scanned for
  `error`, `not`, and `invalid`.
- `download_clone.cmd` returns specific exit codes (3-7) identifying which
  download/extract stage failed - see `doc/CHANGES.md` for the table.
- If the database name cannot be found or closed, confirm the name in
  `file_list.txt` against the output of `list-databases.cmd`.

---

## Resetting credentials

To remove the stored credentials (for example, to change the admin account):

```bat
clear-credentials.cmd
```

This deletes `fmcreds.encrypted` after confirmation. Run
`store-credentials.cmd` again to create new credentials.
