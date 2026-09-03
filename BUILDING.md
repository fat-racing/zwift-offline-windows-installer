# Building the Windows Installer

The repository intentionally excludes large generated payloads and all user data. Never copy an existing zoffline `storage/<player-id>` directory into the build tree.

## Requirements

- Windows 10 or Windows 11, 64-bit
- Inno Setup 6
- A clean zoffline build compatible with Zwift game build `1.0.164452`

## Prepare the Payload

Place the clean server executable at:

```text
installer/payload/zoffline.exe
```

The TLS certificate files and feature marker files are already present in `installer/payload`.

Bots and RoboPacers are optional. To include them, populate these directories from a clean compatible zoffline distribution:

```text
installer/payload/storage/bots
installer/payload/storage/robopacers
```

Do not include profile directories, credentials, cookies, activity history, or third-party integration tokens.

## Compile

Open `installer/installer.iss` in Inno Setup and select **Build > Compile**, or run:

```powershell
& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" .\installer\installer.iss
```

The resulting installer is written to `dist`.

## Release Checklist

1. Confirm the payload contains no `storage/<player-id>` directory.
2. Scan the source tree for credentials and integration tokens.
3. Test installation, launch, and uninstall on a clean Windows account.
4. Calculate a SHA-256 checksum with `Get-FileHash`.
5. Upload the installer and corresponding source archive as GitHub Release assets.
