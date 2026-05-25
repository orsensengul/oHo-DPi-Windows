param(
    [Parameter(Position = 0)]
    [ValidateSet("install", "start", "stop", "restart", "status", "open-discord", "reset-proxy")]
    [string]$Action = "status"
)

$ErrorActionPreference = "Stop"

$AppName = "oHo-DPi"
$ListenHost = "127.0.0.1"
$ListenPort = 18080
$ListenAddr = "${ListenHost}:${ListenPort}"
$ProxyServer = "http=${ListenAddr};https=${ListenAddr}"

$RuntimeDir = Join-Path $env:APPDATA $AppName
$LocalRoot = Join-Path $env:LOCALAPPDATA $AppName
$BinDir = Join-Path $LocalRoot "bin"
$LocalBinary = Join-Path $BinDir "spoofdpi.exe"
$ConfigPath = Join-Path $RuntimeDir "spoofdpi.discord.toml"
$PidPath = Join-Path $RuntimeDir "spoofdpi.pid"
$LogPath = Join-Path $RuntimeDir "spoofdpi.log"
$ErrorLogPath = Join-Path $RuntimeDir "spoofdpi.err.log"
$WinInetBackupPath = Join-Path $RuntimeDir "wininet-proxy-backup.json"
$WinHttpMarkerPath = Join-Path $RuntimeDir "winhttp-proxy-managed"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplatePath = Join-Path $ScriptRoot "config\spoofdpi.discord.toml"
$BundledBinary = Join-Path $ScriptRoot "bin\spoofdpi.exe"
$VendorBinary = Join-Path $ScriptRoot "vendor\spoofdpi.exe"

function Ensure-Dirs {
    New-Item -ItemType Directory -Force -Path $RuntimeDir, $BinDir | Out-Null
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PathCommand {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-SpoofDpiBinary {
    if (Test-Path $BundledBinary) { return $BundledBinary }
    if (Test-Path $LocalBinary) { return $LocalBinary }
    if (Test-Path $VendorBinary) { return $VendorBinary }
    return Get-PathCommand "spoofdpi.exe"
}

function Write-Config {
    Ensure-Dirs
    if (-not (Test-Path $TemplatePath)) {
        throw "Config template not found: $TemplatePath"
    }
    Copy-Item -Force $TemplatePath $ConfigPath
}

function Get-ManagedProcess {
    $candidates = @()
    if (Test-Path $PidPath) {
        $rawPid = (Get-Content -Raw $PidPath).Trim()
        if ($rawPid -match '^\d+$') {
            $proc = Get-Process -Id ([int]$rawPid) -ErrorAction SilentlyContinue
            if ($proc -and $proc.ProcessName -like "spoofdpi*") {
                $candidates += $proc
            }
        }
    }

    $escapedConfig = [Regex]::Escape($ConfigPath)
    $wmiMatches = Get-CimInstance Win32_Process -Filter "Name = 'spoofdpi.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match $escapedConfig }
    foreach ($match in $wmiMatches) {
        $proc = Get-Process -Id $match.ProcessId -ErrorAction SilentlyContinue
        if ($proc) { $candidates += $proc }
    }

    return $candidates | Sort-Object Id -Unique | Select-Object -First 1
}

function Test-PortReachable {
    try {
        $client = [Net.Sockets.TcpClient]::new()
        $async = $client.BeginConnect($ListenHost, $ListenPort, $null, $null)
        $ok = $async.AsyncWaitHandle.WaitOne(1000, $false)
        if ($ok) { $client.EndConnect($async) }
        $client.Close()
        return $ok
    } catch {
        return $false
    }
}

function Get-WinInetProxy {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $props = Get-ItemProperty -Path $key
    return [pscustomobject]@{
        ProxyEnable = [int]($props.ProxyEnable -as [int])
        ProxyServer = [string]$props.ProxyServer
        ProxyOverride = [string]$props.ProxyOverride
    }
}

function Test-WinInetProxyMatch {
    $proxy = Get-WinInetProxy
    if ($proxy.ProxyEnable -ne 1) { return $false }
    $server = $proxy.ProxyServer
    return $server -eq $ListenAddr -or
        $server -eq $ProxyServer -or
        ($server -match "http=$([Regex]::Escape($ListenAddr))" -and $server -match "https=$([Regex]::Escape($ListenAddr))")
}

function Test-WinInetProxyEnabled {
    return (Get-WinInetProxy).ProxyEnable -eq 1
}

function Send-ProxyChangeNotification {
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class WinInetNotify {
    [DllImport("wininet.dll", SetLastError = true)]
    public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
}
"@ -ErrorAction SilentlyContinue
        [WinInetNotify]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
        [WinInetNotify]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
    } catch {
        Write-Verbose "Proxy change notification failed: $($_.Exception.Message)"
    }
}

function Backup-WinInetProxy {
    Ensure-Dirs
    if (Test-Path $WinInetBackupPath) { return }
    Get-WinInetProxy | ConvertTo-Json | Set-Content -Encoding UTF8 $WinInetBackupPath
}

function Set-WinInetProxy {
    Backup-WinInetProxy
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    New-ItemProperty -Path $key -Name ProxyEnable -PropertyType DWord -Value 1 -Force | Out-Null
    New-ItemProperty -Path $key -Name ProxyServer -PropertyType String -Value $ProxyServer -Force | Out-Null
    Send-ProxyChangeNotification
}

function Restore-WinInetProxy {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    if (Test-Path $WinInetBackupPath) {
        $backup = Get-Content -Raw $WinInetBackupPath | ConvertFrom-Json
        New-ItemProperty -Path $key -Name ProxyEnable -PropertyType DWord -Value ([int]$backup.ProxyEnable) -Force | Out-Null
        if ([string]::IsNullOrEmpty($backup.ProxyServer)) {
            Remove-ItemProperty -Path $key -Name ProxyServer -ErrorAction SilentlyContinue
        } else {
            New-ItemProperty -Path $key -Name ProxyServer -PropertyType String -Value ([string]$backup.ProxyServer) -Force | Out-Null
        }
        if ([string]::IsNullOrEmpty($backup.ProxyOverride)) {
            Remove-ItemProperty -Path $key -Name ProxyOverride -ErrorAction SilentlyContinue
        } else {
            New-ItemProperty -Path $key -Name ProxyOverride -PropertyType String -Value ([string]$backup.ProxyOverride) -Force | Out-Null
        }
        Remove-Item -Force $WinInetBackupPath -ErrorAction SilentlyContinue
    } else {
        New-ItemProperty -Path $key -Name ProxyEnable -PropertyType DWord -Value 0 -Force | Out-Null
    }
    Send-ProxyChangeNotification
}

function Set-WinHttpProxyIfAdmin {
    if (-not (Test-Admin)) { return "skipped-not-admin" }
    netsh winhttp set proxy proxy-server="$ProxyServer" bypass-list="localhost;127.0.0.1;<local>" | Out-Null
    Set-Content -Encoding ASCII $WinHttpMarkerPath "managed"
    return "set"
}

function Reset-WinHttpProxyIfManaged {
    if (-not (Test-Path $WinHttpMarkerPath)) { return "not-managed" }
    if (-not (Test-Admin)) { return "skipped-not-admin" }
    netsh winhttp reset proxy | Out-Null
    Remove-Item -Force $WinHttpMarkerPath -ErrorAction SilentlyContinue
    return "reset"
}

function Test-WinHttpProxyMatch {
    try {
        $out = netsh winhttp show proxy 2>$null | Out-String
        return $out -match [Regex]::Escape($ListenAddr)
    } catch {
        return $false
    }
}

function Install-SpoofDpi {
    Ensure-Dirs
    if (Test-Path $LocalBinary) {
        Write-Output "installed: yes"
        & $LocalBinary --version 2>$null
        return
    }
    if (Test-Path $BundledBinary) {
        Write-Output "installed: yes"
        Write-Output "binary: $BundledBinary"
        & $BundledBinary --version 2>$null
        return
    }
    if (Test-Path $VendorBinary) {
        Copy-Item -Force $VendorBinary $LocalBinary
        Write-Output "installed: yes"
        & $LocalBinary --version 2>$null
        return
    }
    $pathBinary = Get-PathCommand "spoofdpi.exe"
    if ($pathBinary) {
        Write-Output "installed: yes"
        Write-Output "binary: $pathBinary"
        & $pathBinary --version 2>$null
        return
    }
    Write-Output "installed: no"
    Write-Output "spoofdpi.exe bulunamadi."
    Write-Output "Beklenen konumlar:"
    Write-Output "- $BundledBinary"
    Write-Output "- $LocalBinary"
    Write-Output "- $VendorBinary"
    Write-Output "- PATH icinde spoofdpi.exe"
    Write-Output "Not: Resmi v1.5.3 release asset listesinde Windows binary gorunmuyor; Windows build artifact veya vendor binary gerekli."
    exit 1
}

function Start-SpoofDpi {
    $binary = Get-SpoofDpiBinary
    if (-not $binary) {
        Write-Output "state: not-installed"
        Write-Output "installed: no"
        Write-Output "spoofdpi.exe bulunamadi. Once install veya vendor binary ekleyin."
        exit 1
    }

    Ensure-Dirs
    Write-Config

    $existing = Get-ManagedProcess
    if ($existing) {
        Set-WinInetProxy
        $winHttp = Set-WinHttpProxyIfAdmin
        Write-Output "state: running"
        Write-Output "running: yes"
        Write-Output "pid: $($existing.Id)"
        Write-Output "winhttp: $winHttp"
        return
    }

    if (Test-PortReachable) {
        Write-Output "state: degraded"
        Write-Output "running: no"
        Write-Output "port: reachable"
        Write-Output "Port $ListenPort baska bir process tarafindan kullaniliyor. Process oldurmedim."
        exit 1
    }

    Remove-Item -Force $LogPath, $ErrorLogPath -ErrorAction SilentlyContinue
    $argString = "--config `"$ConfigPath`""
    $proc = Start-Process -FilePath $binary -ArgumentList $argString -WindowStyle Hidden -PassThru -RedirectStandardOutput $LogPath -RedirectStandardError $ErrorLogPath
    Set-Content -Encoding ASCII $PidPath $proc.Id
    Start-Sleep -Seconds 1

    $running = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if (-not $running) {
        Write-Output "state: stopped"
        Write-Output "running: no"
        Write-Output "SpoofDPI hemen kapandi. Log:"
        if (Test-Path $LogPath) { Get-Content -Tail 40 $LogPath }
        if (Test-Path $ErrorLogPath) { Get-Content -Tail 40 $ErrorLogPath }
        exit 1
    }

    Set-WinInetProxy
    $winHttp = Set-WinHttpProxyIfAdmin
    Write-Output "state: running"
    Write-Output "running: yes"
    Write-Output "pid: $($proc.Id)"
    Write-Output "listen: $ListenAddr"
    Write-Output "config: $ConfigPath"
    Write-Output "winhttp: $winHttp"
}

function Stop-SpoofDpi {
    $proc = Get-ManagedProcess
    if ($proc) {
        Write-Output "Stopping SpoofDPI pid $($proc.Id)"
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    } else {
        Write-Output "SpoofDPI process not found."
    }
    Remove-Item -Force $PidPath -ErrorAction SilentlyContinue
    Restore-WinInetProxy
    $winHttp = Reset-WinHttpProxyIfManaged
    Write-Output "state: stopped"
    Write-Output "running: no"
    Write-Output "proxy: disabled"
    Write-Output "winhttp: $winHttp"
}

function Reset-Proxy {
    Restore-WinInetProxy
    $winHttp = Reset-WinHttpProxyIfManaged
    Write-Output "proxy: disabled"
    Write-Output "winhttp: $winHttp"
}

function Get-State {
    $binary = Get-SpoofDpiBinary
    $installed = if ($binary) { "yes" } else { "no" }
    $proc = Get-ManagedProcess
    $process = if ($proc) { "yes" } else { "no" }
    $port = if (Test-PortReachable) { "reachable" } else { "closed" }
    $winInetEnabled = if (Test-WinInetProxyEnabled) { "yes" } else { "no" }
    $winInetMatch = if (Test-WinInetProxyMatch) { "yes" } else { "no" }
    $winHttpMatch = if (Test-WinHttpProxyMatch) { "yes" } else { "no" }

    if ($installed -eq "no") {
        $state = "not-installed"
    } elseif ($process -eq "yes" -and $port -eq "reachable" -and $winInetMatch -eq "yes") {
        $state = "running"
    } elseif ($process -eq "yes" -or $port -eq "reachable" -or $winInetEnabled -eq "yes" -or $winHttpMatch -eq "yes") {
        $state = "degraded"
    } else {
        $state = "stopped"
    }

    Write-Output "state: $state"
    Write-Output "installed: $installed"
    if ($binary) {
        Write-Output "binary: $binary"
        & $binary --version 2>$null
    }
    Write-Output "process: $process"
    if ($proc) { Write-Output "pid: $($proc.Id)" }
    Write-Output "listen: $ListenAddr"
    Write-Output "port: $port"
    Write-Output "wininet-proxy-enabled: $winInetEnabled"
    Write-Output "wininet-proxy-match: $winInetMatch"
    Write-Output "winhttp-proxy-match: $winHttpMatch"
    Write-Output "config: $ConfigPath"
    Write-Output "log: $LogPath"
    Write-Output "error-log: $ErrorLogPath"
    if ($state -eq "degraded" -and (Test-Path $LogPath)) {
        Write-Output "log tail:"
        Get-Content -Tail 20 $LogPath
    }
    if ($state -eq "degraded" -and (Test-Path $ErrorLogPath)) {
        Write-Output "error log tail:"
        Get-Content -Tail 20 $ErrorLogPath
    }
}

function Open-Discord {
    $update = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"
    if (-not (Test-Path $update)) {
        Write-Output "Discord Update.exe bulunamadi: $update"
        exit 1
    }
    Get-Process Discord, Update -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "*\Discord\*" -or $_.ProcessName -eq "Discord" } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Process -FilePath $update -ArgumentList "--processStart", "Discord.exe"
    Write-Output "Discord opened"
}

switch ($Action) {
    "install" { Install-SpoofDpi }
    "start" { Start-SpoofDpi }
    "stop" { Stop-SpoofDpi }
    "restart" { Stop-SpoofDpi; Start-SpoofDpi }
    "status" { Get-State }
    "open-discord" { Open-Discord }
    "reset-proxy" { Reset-Proxy }
}
