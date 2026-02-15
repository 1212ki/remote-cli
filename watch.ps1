[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)]
    [ValidateSet("start", "stop", "status", "monitor")]
    [string]$Command = "status",
    [string]$SessionsDir = "",
    [string]$Webhook = "",
    [string]$PidFilePath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = $MyInvocation.MyCommand.Path
$logDir = Join-Path $env:TEMP "claude-watch"
$pidFile = if ($PidFilePath) { $PidFilePath } else { Join-Path $logDir "watch.pid" }

function Get-Webhook {
    if ($env:SLACK_WEBHOOK_URL) {
        return $env:SLACK_WEBHOOK_URL
    }

    $envFileLocal = Join-Path $scriptDir ".env"
    if (Test-Path -LiteralPath $envFileLocal) {
        $line = Get-Content -LiteralPath $envFileLocal | Where-Object { $_ -match '^SLACK_WEBHOOK_URL=' } | Select-Object -First 1
        if ($line) {
            return ($line -replace '^SLACK_WEBHOOK_URL=', '').Trim()
        }
    }

    $envFile = Join-Path $scriptDir "..\podcast-summarizer\.env"
    if (Test-Path -LiteralPath $envFile) {
        $line = Get-Content -LiteralPath $envFile | Where-Object { $_ -match '^SLACK_WEBHOOK_URL=' } | Select-Object -First 1
        if ($line) {
            return ($line -replace '^SLACK_WEBHOOK_URL=', '').Trim()
        }
    }
    return ""
}

function Send-Slack {
    param([string]$WebhookUrl, [string]$Text, [string]$Emoji = "👀")
    if (-not $WebhookUrl) { return }
    try {
        Invoke-RestMethod -Method Post -Uri $WebhookUrl -ContentType "application/json" -Body (@{ text = "$Emoji $Text" } | ConvertTo-Json -Compress) | Out-Null
    } catch {
    }
}

function Resolve-SessionsDir {
    $codexHome = if ($env:CODEX_HOME) {
        $env:CODEX_HOME
    } else {
        Join-Path (Resolve-Path (Join-Path $scriptDir "..\..")).Path ".codex"
    }
    $sessions = Join-Path $codexHome "sessions"
    $fallback = Join-Path $HOME ".codex\sessions"
    $wslDistro = $env:REMOTE_APPROVAL_WSL_DISTRO
    if (-not $wslDistro) { $wslDistro = "Ubuntu-24.04" }
    $wslUser = $env:REMOTE_APPROVAL_WSL_USER
    if (-not $wslUser) { $wslUser = $env:USERNAME }
    $wslCandidates = @(
        "\\wsl.localhost\$wslDistro\home\$wslUser\.codex\sessions",
        "\\wsl.localhost\$wslDistro\root\.codex\sessions",
        "\\wsl$\$wslDistro\home\$wslUser\.codex\sessions",
        "\\wsl$\$wslDistro\root\.codex\sessions"
    )

    try {
        if (Test-Path -LiteralPath $sessions) {
            return $sessions
        }
    } catch {
    }
    try {
        if (Test-Path -LiteralPath $fallback) {
            return $fallback
        }
    } catch {
    }
    foreach ($candidate in $wslCandidates) {
        try {
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        } catch {
        }
    }
    return $sessions
}

function Start-Monitor {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    if (Test-Path -LiteralPath $pidFile) {
        Stop-Monitor | Out-Null
    }

    $sessions = Resolve-SessionsDir
    if (-not (Test-Path -LiteralPath $sessions)) {
        throw "Codexセッションフォルダが見つかりません: $sessions"
    }

    $webhookUrl = Get-Webhook
    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) {
        throw "pwsh が見つかりません。"
    }

    # 先にPIDファイルを作成して、monitor側の起動レースを防ぐ
    Set-Content -LiteralPath $pidFile -Value "starting" -NoNewline

    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $scriptPath,
        "monitor",
        "-SessionsDir", $sessions,
        "-PidFilePath", $pidFile
    )
    if ($webhookUrl) {
        $argList += @("-Webhook", $webhookUrl)
    }
    try {
        $proc = Start-Process -FilePath $pwsh -ArgumentList $argList -PassThru -WindowStyle Hidden
        Set-Content -LiteralPath $pidFile -Value $proc.Id -NoNewline
        Write-Output "監視を開始しました (PID=$($proc.Id))"
    } catch {
        Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Stop-Monitor {
    if (-not (Test-Path -LiteralPath $pidFile)) {
        Write-Output "監視は実行されていません"
        return
    }

    $rawPid = (Get-Content -LiteralPath $pidFile -Raw).Trim()
    $watchPid = 0
    if (-not [int]::TryParse($rawPid, [ref]$watchPid)) {
        Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
        Write-Output "監視プロセス情報が不正なため、状態をリセットしました"
        return
    }
    $proc = Get-Process -Id $watchPid -ErrorAction SilentlyContinue
    if ($proc) {
        Stop-Process -Id $watchPid -Force -ErrorAction SilentlyContinue
        Write-Output "監視を停止しました (PID=$watchPid)"
    } else {
        Write-Output "監視プロセスは既に停止しています"
    }
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}

function Show-Status {
    if (-not (Test-Path -LiteralPath $pidFile)) {
        Write-Output "監視停止中"
        return
    }
    $rawPid = (Get-Content -LiteralPath $pidFile -Raw).Trim()
    $watchPid = 0
    if (-not [int]::TryParse($rawPid, [ref]$watchPid)) {
        Write-Output "監視停止中"
        Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
        return
    }
    $proc = Get-Process -Id $watchPid -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Output "監視中 (PID=$watchPid)"
    } else {
        Write-Output "監視停止中"
        Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    }
}

function Run-Monitor {
    if (-not $SessionsDir) {
        throw "monitor mode requires -SessionsDir"
    }
    if (-not $PidFilePath) {
        throw "monitor mode requires -PidFilePath"
    }

    $lastWrite = Get-Date
    $lastInputNotify = Get-Date "2000-01-01"
    $idleNotified = $false
    Send-Slack -WebhookUrl $Webhook -Text "監視モード開始 (Windows sessions monitor)" -Emoji "📱"

    while (Test-Path -LiteralPath $PidFilePath) {
        $latest = Get-ChildItem -LiteralPath $SessionsDir -Recurse -File -Filter "*.jsonl" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($latest -and $latest.LastWriteTime -gt $lastWrite) {
            $lastWrite = $latest.LastWriteTime
            $idleNotified = $false
        }

        $stableSeconds = [int]((Get-Date) - $lastWrite).TotalSeconds
        $sinceInputNotify = [int]((Get-Date) - $lastInputNotify).TotalSeconds

        if ($stableSeconds -ge 300 -and $sinceInputNotify -ge 300) {
            Send-Slack -WebhookUrl $Webhook -Text "【入力待ちの可能性】5分以上更新がありません" -Emoji "⏳"
            $lastInputNotify = Get-Date
        }

        if ($stableSeconds -ge 900 -and -not $idleNotified) {
            Send-Slack -WebhookUrl $Webhook -Text "【作業完了？】15分以上更新がありません" -Emoji "✅"
            $idleNotified = $true
        }

        Start-Sleep -Seconds 30
    }
}

switch ($Command) {
    "start" { Start-Monitor }
    "stop" { Stop-Monitor }
    "status" { Show-Status }
    "monitor" { Run-Monitor }
}
