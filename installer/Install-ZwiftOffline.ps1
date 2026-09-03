param(
    [Parameter(Mandatory = $true)]
    [string]$InstallDir
)

$ErrorActionPreference = 'Stop'
$supportedVersion = '1.0.164452'
$logPath = Join-Path $InstallDir 'install.log'

function Show-Error([string]$Message) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($Message, 'Zwift Offline Setup', 'OK', 'Error') | Out-Null
}

try {
    "$(Get-Date -Format o) Configuration started" | Set-Content -LiteralPath $logPath -Encoding utf8

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator privileges are required.'
    }

    $zwiftDir = $null
    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $installedZwift = Get-ItemProperty $uninstallRoots -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'Zwift version*' -and $_.InstallLocation } |
        Select-Object -First 1
    if ($installedZwift -and (Test-Path -LiteralPath (Join-Path $installedZwift.InstallLocation 'ZwiftLauncher.exe'))) {
        $zwiftDir = $installedZwift.InstallLocation.TrimEnd('\')
    }

    if (-not $zwiftDir) {
        $candidates = @(
            (Join-Path ${env:ProgramFiles(x86)} 'Zwift'),
            (Join-Path $env:ProgramFiles 'Zwift'),
            'C:\Zwift',
            'D:\Zwift'
        ) | Where-Object { $_ }
        $zwiftDir = $candidates |
            Where-Object { Test-Path -LiteralPath (Join-Path $_ 'ZwiftLauncher.exe') } |
            Select-Object -First 1
    }

    if (-not $zwiftDir) {
        throw 'Zwift was not found. Install the official Zwift client first, then run this setup again.'
    }

    $versionFile = Join-Path $zwiftDir 'Zwift_ver_cur.xml'
    if (-not (Test-Path -LiteralPath $versionFile)) {
        throw "Zwift version file was not found in $zwiftDir."
    }
    [xml]$versionXml = Get-Content -Raw -LiteralPath $versionFile
    $installedVersion = [string]$versionXml.Zwift.version
    if ($installedVersion -ne $supportedVersion) {
        throw "Unsupported Zwift game version: $installedVersion.`n`nThis package requires version $supportedVersion."
    }

    $backupDir = Join-Path $InstallDir 'backup'
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    $hostsPath = Join-Path $env:WINDIR 'System32\drivers\etc\hosts'
    Copy-Item -LiteralPath $hostsPath -Destination (Join-Path $backupDir 'hosts.before-install.txt') -Force
    $hostsText = Get-Content -Raw -LiteralPath $hostsPath
    $hostsText = [regex]::Replace($hostsText, '(?ms)^# BEGIN Zwift Offline Local\r?\n.*?^# END Zwift Offline Local\r?\n?', '')
    $hostsText = ($hostsText -split '\r?\n' | Where-Object {
        $_ -notmatch '(?i)\b(us-or-rly101|secure|cdn|launcher)\.zwift\.com\b'
    }) -join "`r`n"
    $hostsBlock = @"
# BEGIN Zwift Offline Local
127.0.0.1 us-or-rly101.zwift.com secure.zwift.com cdn.zwift.com launcher.zwift.com
# END Zwift Offline Local
"@
    ($hostsText.TrimEnd() + "`r`n`r`n" + $hostsBlock.Trim() + "`r`n") |
        Set-Content -LiteralPath $hostsPath -Encoding ascii

    $certificatePath = Join-Path $InstallDir 'ssl\cert-zwift-com.p12'
    $emptyPassword = New-Object Security.SecureString
    $pfxData = Get-PfxData -FilePath $certificatePath -Password $emptyPassword
    $pfxThumbprints = @($pfxData.EndEntityCertificates | Select-Object -ExpandProperty Thumbprint -Unique)
    $certBefore = @(Get-ChildItem Cert:\LocalMachine\Root | Select-Object -ExpandProperty Thumbprint)
    $missingThumbprints = @($pfxThumbprints | Where-Object { $_ -notin $certBefore })
    if ($missingThumbprints.Count -gt 0) {
        Import-PfxCertificate -FilePath $certificatePath -CertStoreLocation Cert:\LocalMachine\Root `
            -Password $emptyPassword -Exportable | Out-Null
    }
    $certAfter = @(Get-ChildItem Cert:\LocalMachine\Root | Select-Object -ExpandProperty Thumbprint)
    $newCertificateThumbprints = @($certAfter | Where-Object { $_ -notin $certBefore })

    $cacertPath = Join-Path $zwiftDir 'data\cacert.pem'
    if (Test-Path -LiteralPath $cacertPath) {
        Copy-Item -LiteralPath $cacertPath -Destination (Join-Path $backupDir 'cacert.before-install.pem') -Force
        $cacertText = Get-Content -Raw -LiteralPath $cacertPath
        $cacertText = [regex]::Replace($cacertText, '(?ms)^# BEGIN Zwift Offline Local\r?\n.*?^# END Zwift Offline Local\r?\n?', '')
        $certificateText = Get-Content -Raw -LiteralPath (Join-Path $InstallDir 'ssl\cert-zwift-com.pem')
        $certificateBlock = "# BEGIN Zwift Offline Local`r`n" + $certificateText.Trim() + "`r`n# END Zwift Offline Local`r`n"
        ($cacertText.TrimEnd() + "`r`n`r`n" + $certificateBlock) |
            Set-Content -LiteralPath $cacertPath -Encoding ascii
    }

    Get-NetFirewallRule -DisplayName 'Zwift Offline Local Server*' -ErrorAction SilentlyContinue |
        Remove-NetFirewallRule -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName 'Zwift Offline Local Server (TCP)' -Direction Inbound `
        -Program (Join-Path $InstallDir 'zoffline.exe') -Action Allow -Protocol TCP `
        -LocalPort 80,443,3025 -Profile Private | Out-Null
    New-NetFirewallRule -DisplayName 'Zwift Offline Local Server (UDP)' -Direction Inbound `
        -Program (Join-Path $InstallDir 'zoffline.exe') -Action Allow -Protocol UDP `
        -LocalPort 3024 -Profile Private | Out-Null

    $configuration = [ordered]@{
        zwiftDir = $zwiftDir
        zwiftVersion = $installedVersion
        supportedVersion = $supportedVersion
        certificateThumbprintsInstalledBySetup = $newCertificateThumbprints
        installedAt = (Get-Date -Format o)
    }
    $configuration | ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath (Join-Path $InstallDir 'config.json') -Encoding utf8

    Clear-DnsClientCache
    "$(Get-Date -Format o) Configuration completed successfully" | Add-Content -LiteralPath $logPath -Encoding utf8
    exit 0
}
catch {
    $message = $_.Exception.Message
    "$(Get-Date -Format o) ERROR: $message" | Add-Content -LiteralPath $logPath -Encoding utf8
    Show-Error $message
    exit 1
}
