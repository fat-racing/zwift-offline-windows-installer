param(
    [Parameter(Mandatory = $true)]
    [string]$InstallDir
)

$ErrorActionPreference = 'SilentlyContinue'
$configPath = Join-Path $InstallDir 'config.json'
$config = if (Test-Path -LiteralPath $configPath) {
    Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
} else {
    $null
}

Get-Process -Name zoffline -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq (Join-Path $InstallDir 'zoffline.exe') } |
    Stop-Process -Force

Get-NetFirewallRule -DisplayName 'Zwift Offline Local Server*' -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule -ErrorAction SilentlyContinue

$hostsPath = Join-Path $env:WINDIR 'System32\drivers\etc\hosts'
if (Test-Path -LiteralPath $hostsPath) {
    $hostsText = Get-Content -Raw -LiteralPath $hostsPath
    $hostsText = [regex]::Replace($hostsText, '(?ms)^# BEGIN Zwift Offline Local\r?\n.*?^# END Zwift Offline Local\r?\n?', '')
    $hostsText.TrimEnd() + "`r`n" | Set-Content -LiteralPath $hostsPath -Encoding ascii
}

if ($config -and $config.zwiftDir) {
    $cacertPath = Join-Path $config.zwiftDir 'data\cacert.pem'
    if (Test-Path -LiteralPath $cacertPath) {
        $cacertText = Get-Content -Raw -LiteralPath $cacertPath
        $cacertText = [regex]::Replace($cacertText, '(?ms)^# BEGIN Zwift Offline Local\r?\n.*?^# END Zwift Offline Local\r?\n?', '')
        $cacertText.TrimEnd() + "`r`n" | Set-Content -LiteralPath $cacertPath -Encoding ascii
    }
    foreach ($thumbprint in @($config.certificateThumbprintsInstalledBySetup)) {
        if ($thumbprint -and (Test-Path -LiteralPath "Cert:\LocalMachine\Root\$thumbprint")) {
            Remove-Item -LiteralPath "Cert:\LocalMachine\Root\$thumbprint" -Force
        }
    }
}

Clear-DnsClientCache
