[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Position=0)]
  [ValidateSet("connect","help")]
  [string]$Command = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-LocalIp {
  try {
    $addr = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
      Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" -and $_.PrefixOrigin -ne "WellKnown" } |
      Sort-Object -Property InterfaceMetric, SkipAsSource |
      Select-Object -First 1
    if ($addr) { return $addr.IPAddress }
  } catch {}
  return ""
}

function Get-TailscaleIp {
  $ts = Get-Command tailscale.exe -ErrorAction SilentlyContinue
  if (-not $ts) { return "" }
  $ip = & $ts.Source ip -4 2>$null | Select-Object -First 1
  if ($ip) { return "$ip".Trim() }
  return ""
}

function Show-Connect {
  $tailscaleIp = Get-TailscaleIp
  $localIp = Get-LocalIp
  $hostIp = if ($tailscaleIp) { $tailscaleIp } else { $localIp }

  Write-Output ("Host: " + ($(if($hostIp){$hostIp}else{"(not available)"})))
  Write-Output ("User: " + $env:USERNAME)
  Write-Output "Port: 22"
}

switch ($Command) {
  "connect" { Show-Connect }
  "help" { "Usage: .\status.ps1 connect" }
  default { Show-Connect }
}
