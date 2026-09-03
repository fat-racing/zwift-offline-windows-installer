$ErrorActionPreference = 'Stop'
$installDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logPath = Join-Path $installDir 'launcher.log'

try {
    "$(Get-Date -Format o) Starting Zwift Offline" | Set-Content -LiteralPath $logPath -Encoding utf8
    $configPath = Join-Path $installDir 'config.json'
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw 'Installation configuration is missing. Run the installer again.'
    }
    $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
    $zwiftLauncher = Join-Path $config.zwiftDir 'ZwiftLauncher.exe'
    $versionFile = Join-Path $config.zwiftDir 'Zwift_ver_cur.xml'
    if (-not (Test-Path -LiteralPath $zwiftLauncher)) {
        throw "ZwiftLauncher.exe was not found in $($config.zwiftDir)."
    }
    [xml]$versionXml = Get-Content -Raw -LiteralPath $versionFile
    if ([string]$versionXml.Zwift.version -ne [string]$config.supportedVersion) {
        throw "This package supports Zwift $($config.supportedVersion), but $($versionXml.Zwift.version) is installed."
    }

    $requiredPorts = @(80, 443, 3025)
    $listening = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPort -in $requiredPorts } |
        Select-Object -ExpandProperty LocalPort -Unique)
    if ($listening.Count -ne $requiredPorts.Count) {
        Start-Process -FilePath (Join-Path $installDir 'zoffline.exe') -WorkingDirectory $installDir -WindowStyle Hidden
    }

    $ready = $false
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        Start-Sleep -Seconds 1
        $listening = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Where-Object { $_.LocalPort -in $requiredPorts } |
            Select-Object -ExpandProperty LocalPort -Unique)
        if ($listening.Count -eq $requiredPorts.Count) {
            $ready = $true
            break
        }
    }
    if (-not $ready) {
        throw 'The local zoffline server did not start within 90 seconds.'
    }

    $launcher = Get-Process -Name ZwiftLauncher -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $launcher) {
        Start-Process -FilePath $zwiftLauncher -WorkingDirectory $config.zwiftDir
    }
    elseif ($launcher.MainWindowHandle -ne 0) {
        $shell = New-Object -ComObject WScript.Shell
        [void]$shell.AppActivate($launcher.Id)
    }
    else {
        $launcher | Stop-Process -Force
        Start-Process -FilePath $zwiftLauncher -WorkingDirectory $config.zwiftDir
    }
    "$(Get-Date -Format o) Ready" | Add-Content -LiteralPath $logPath -Encoding utf8
}
catch {
    "$(Get-Date -Format o) ERROR: $($_.Exception.Message)" | Add-Content -LiteralPath $logPath -Encoding utf8
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($_.Exception.Message, 'Zwift Offline', 'OK', 'Error') | Out-Null
    exit 1
}
