[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ipaddress] $PcIp,
    [Parameter(Mandatory)] [ipaddress] $StbIp
)

$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$required = @(
    'tls\docker-compose.yml',
    'tls\pass_front.py',
    'tls\acs_chain.pem',
    'tls\forged_chain.pem',
    'adb.exe'
)

$missing = $required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $source $_)) }
if ($missing) {
    throw "Standalone repository is incomplete: $($missing -join ', ')"
}

$adapterIp = Get-NetIPAddress -AddressFamily IPv4 -IPAddress $PcIp.IPAddressToString -ErrorAction SilentlyContinue
if (-not $adapterIp) {
    throw "PC address $PcIp is not assigned to a local adapter."
}

Write-Host "Repository: $source"
Write-Host "PC LAN address: $PcIp"
Write-Host "STB address: $StbIp"
Write-Host "Adapter: $($adapterIp.InterfaceAlias)"

$ports = 53, 3000, 5380, 7547, 7557, 7567, 8443, 9443
$allTcp = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)
$allUdp = @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue)
$processNames = @{}
foreach ($port in $ports) {
    $tcp = @($allTcp | Where-Object LocalPort -eq $port)
    $udp = @($allUdp | Where-Object LocalPort -eq $port)
    if (-not $tcp -and -not $udp) {
        Write-Host ("{0}: not listening" -f $port)
        continue
    }
    foreach ($endpoint in @($tcp) + @($udp)) {
        if (-not $processNames.ContainsKey($endpoint.OwningProcess)) {
            $processNames[$endpoint.OwningProcess] = (Get-Process -Id $endpoint.OwningProcess -ErrorAction SilentlyContinue).ProcessName
        }
        Write-Host ("{0}: {1} PID {2} ({3})" -f $port, $endpoint.LocalAddress, $endpoint.OwningProcess, $processNames[$endpoint.OwningProcess])
    }
}

try {
    $null = Invoke-RestMethod -Uri 'http://127.0.0.1:5380/api/status' -TimeoutSec 3
    Write-Host 'Technitium API: reachable'
} catch {
    Write-Warning 'Technitium API is not reachable at http://127.0.0.1:5380.'
}

try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    Write-Host "Docker server: $dockerVersion"
} catch {
    Write-Warning 'Docker Desktop is not running or docker.exe is unavailable.'
}

$excluded = netsh interface ipv4 show excludedportrange protocol=tcp
$relevantExcluded = $excluded | Select-String -Pattern '(^|\s)(53|3000|5380|7547|7557|7567|8443|9443)(\s|$)'
if ($relevantExcluded) {
    Write-Warning 'A relevant TCP port appears in an excluded range. Inspect netsh output before continuing.'
}

Write-Host ''
Write-Host 'Run these commands once in an elevated PowerShell prompt:'
Write-Host ('New-NetFirewallRule -DisplayName "JioSTB temporary DNS UDP" -Direction Inbound -Action Allow -Protocol UDP -LocalPort 53 -LocalAddress {0} -RemoteAddress {1} -Profile Any' -f $PcIp, $StbIp)
Write-Host ('New-NetFirewallRule -DisplayName "JioSTB temporary DNS TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 53 -LocalAddress {0} -RemoteAddress {1} -Profile Any' -f $PcIp, $StbIp)
Write-Host ('New-NetFirewallRule -DisplayName "JioSTB temporary TLS" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8443,9443 -LocalAddress {0} -RemoteAddress {1} -Profile Any' -f $PcIp, $StbIp)
Write-Host ''
Write-Host 'If rules with these names already exist, remove duplicates before adding them again.'
