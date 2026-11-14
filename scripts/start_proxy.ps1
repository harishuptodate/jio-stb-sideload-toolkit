[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet('JHS', 'JMS')] [string] $Model,
    [string] $Python = 'python'
)

$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$compose = Join-Path $source 'tls\docker-compose.yml'
$proxy = Join-Path $source 'tls\pass_front.py'
$certName = if ($Model -eq 'JHS') { 'forged_chain.pem' } else { 'acs_chain.pem' }
$cert = Join-Path $source "tls\$certName"

foreach ($path in $compose, $proxy, $cert) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing required file: $path" }
}

$stateDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.state'
$pidPath = Join-Path $stateDir 'proxy.pid'
$logPath = Join-Path $stateDir 'pass_front.log'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

if (Test-Path -LiteralPath $pidPath) {
    $oldPid = [int](Get-Content -LiteralPath $pidPath -Raw)
    $old = Get-CimInstance Win32_Process -Filter "ProcessId=$oldPid" -ErrorAction SilentlyContinue
    if ($old -and $old.CommandLine -match 'pass_front\.py') {
        throw "A tracked proxy is already running as PID $oldPid. Run cleanup_pc.ps1 first."
    }
    Remove-Item -LiteralPath $pidPath -Force
}

$busy = foreach ($port in 8443, 9443) {
    Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
}
if ($busy) {
    $owners = $busy | ForEach-Object { "port $($_.LocalPort) PID $($_.OwningProcess)" }
    throw "Proxy ports are already occupied: $($owners -join ', ')"
}

docker compose -f $compose up -d
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose failed to start GenieACS.' }

$arguments = @($proxy, '--ports', '8443,9443', '--cert', $cert, '--log', $logPath)
$quotedArguments = $arguments | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }
$process = Start-Process -FilePath $Python -ArgumentList ($quotedArguments -join ' ') -WorkingDirectory (Split-Path $proxy) -WindowStyle Hidden -PassThru
$process.Id | Set-Content -LiteralPath $pidPath -Encoding ASCII

$ready = $false
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    Start-Sleep -Milliseconds 500
    $listening = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -in 8443, 9443 })
    if (($listening.LocalPort | Sort-Object -Unique) -join ',' -eq '8443,9443') {
        $ready = $true
        break
    }
    if ($process.HasExited) { break }
}

if (-not $ready) {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
    Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
    throw "Proxy did not open 8443 and 9443. Inspect $logPath"
}

Write-Host "$Model proxy ready as PID $($process.Id) using $certName"
Write-Host "Log: $logPath"
if ($Model -eq 'JMS') {
    Write-Warning 'JMS is provisional. Stop on unknown_ca and do not substitute the JHS chain as a guess.'
}
