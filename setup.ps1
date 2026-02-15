[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)]
    [ValidateSet("check", "windows", "tailscale", "all", "help", "mac")]
    [string]$Command = "help"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TailscaleCommand {
    $cmd = Get-Command tailscale -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        "C:\Program Files\Tailscale\tailscale.exe",
        "C:\Program Files (x86)\Tailscale\tailscale.exe"
    )
    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) { return $path }
    }
    return ""
}

function Get-LocalIp {
    try {
        $addr = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {
                $_.IPAddress -notlike "127.*" -and
                $_.IPAddress -notlike "169.254.*" -and
                $_.PrefixOrigin -ne "WellKnown"
            } |
            Sort-Object -Property InterfaceMetric, SkipAsSource |
            Select-Object -First 1
        if ($addr) { return $addr.IPAddress }
    } catch {
    }

    try {
        $ipconfig = ipconfig
        $matches = [regex]::Matches(($ipconfig -join "`n"), 'IPv4[^:\r\n]*:\s*(\d{1,3}(?:\.\d{1,3}){3})')
        foreach ($m in $matches) {
            $ip = $m.Groups[1].Value
            if ($ip -and $ip -notlike "127.*" -and $ip -notlike "169.254.*") {
                return $ip
            }
        }
    } catch {
    }

    return ""
}

function Show-Help {
    Write-Output ""
    Write-Output "Remote Approval Setup Tool (Windows)"
    Write-Output ""
    Write-Output "使い方:"
    Write-Output "  .\setup.ps1 check"
    Write-Output "  .\setup.ps1 windows"
    Write-Output "  .\setup.ps1 tailscale"
    Write-Output "  .\setup.ps1 all"
    Write-Output ""
}

function Check-Status {
    Write-Output ""
    Write-Output "[1] OpenSSH Server"
    $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if ($sshd) {
        Write-Output "  ✓ インストール済み (Status: $($sshd.Status))"
    } else {
        Write-Output "  ✗ 未インストール"
    }
    Write-Output ""

    Write-Output "[2] Tailscale"
    $tailscale = Get-TailscaleCommand
    if ($tailscale) {
        Write-Output "  ✓ tailscale コマンドあり"
        & $tailscale status 2>$null | Select-Object -First 4 | ForEach-Object { "    $_" }
    } else {
        Write-Output "  ✗ tailscale コマンドなし"
    }
    Write-Output ""

    Write-Output "[3] 接続情報"
    Write-Output "  ユーザー名: $env:USERNAME"
    Write-Output "  ホスト名:   $env:COMPUTERNAME"
    $ip = Get-LocalIp
    if ($ip) {
        Write-Output "  ローカルIP: $ip"
    } else {
        Write-Output "  ローカルIP: (未取得)"
    }
    Write-Output ""
}

function Setup-WindowsSsh {
    Write-Output "OpenSSH Server を設定します..."
    $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if (-not $sshd) {
        Write-Output "OpenSSH Server が未インストールです。"
        Write-Output "管理者PowerShellで以下を実行してください:"
        Write-Output "  Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0"
        return
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Output "⚠ 管理者権限が必要です。"
        Write-Output ""
        Write-Output "管理者PowerShellで以下を実行してください:"
        Write-Output "  Set-Service -Name sshd -StartupType Automatic"
        Write-Output "  Start-Service sshd"
        Write-Output '  if (-not (Get-NetFirewallRule -DisplayName "OpenSSH Server (sshd)" -ErrorAction SilentlyContinue)) { New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 }'
        return
    }

    $needsAdmin = $false

    try {
        Set-Service -Name sshd -StartupType Automatic -ErrorAction Stop
    } catch {
        $needsAdmin = $true
        Write-Output "⚠ StartupType変更に失敗しました（管理者権限が必要）"
    }

    try {
        if ((Get-Service -Name sshd).Status -ne "Running") {
            Start-Service sshd -ErrorAction Stop
        }
    } catch {
        $needsAdmin = $true
        Write-Output "⚠ sshd起動に失敗しました（管理者権限が必要）"
    }

    try {
        if (-not (Get-NetFirewallRule -DisplayName "OpenSSH Server (sshd)" -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction Stop | Out-Null
        }
    } catch {
        $needsAdmin = $true
        Write-Output "⚠ ファイアウォール設定に失敗しました（管理者権限が必要）"
    }

    if ($needsAdmin) {
        Write-Output ""
        Write-Output "管理者PowerShellで以下を実行してください:"
        Write-Output "  Set-Service -Name sshd -StartupType Automatic"
        Write-Output "  Start-Service sshd"
        Write-Output '  if (-not (Get-NetFirewallRule -DisplayName "OpenSSH Server (sshd)" -ErrorAction SilentlyContinue)) { New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 }'
        return
    }

    Write-Output "✓ OpenSSH Server の設定完了"
}

function Setup-Tailscale {
    $tailscale = Get-TailscaleCommand
    if (-not $tailscale) {
        Write-Output "tailscale が未インストールです。"
        Write-Output "インストール例:"
        Write-Output "  winget install Tailscale.Tailscale"
        return
    }

    Write-Output "tailscale status:"
    & $tailscale status 2>$null | Select-Object -First 8
    if ($LASTEXITCODE -ne 0) {
        Write-Output ""
        Write-Output "未ログインの場合は以下を実行してください:"
        Write-Output "  tailscale up"
    }
}

switch ($Command) {
    "check" { Check-Status }
    "windows" { Setup-WindowsSsh }
    "mac" { Setup-WindowsSsh }
    "tailscale" { Setup-Tailscale }
    "all" {
        Setup-WindowsSsh
        Write-Output ""
        Setup-Tailscale
        Write-Output ""
        Check-Status
    }
    default { Show-Help }
}
