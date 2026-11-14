[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)] [string] $SourceRepo,
    [Parameter(Mandatory)] [switch] $StbDhcpRestored,
    [string] $TechnitiumServer = 'http://127.0.0.1:5380'
)

$ErrorActionPreference = 'Stop'
if (-not $StbDhcpRestored) {
    throw 'Restore DHCP/automatic DNS on the STB and confirm its internet first, then pass -StbDhcpRestored.'
}

$source = (Resolve-Path -LiteralPath $SourceRepo).Path
$compose = Join-Path $source 'tls\docker-compose.yml'
$root = Split-Path $PSScriptRoot -Parent
$stateDir = Join-Path $root '.state'
$pidPath = Join-Path $stateDir 'proxy.pid'
$backupPath = Join-Path $stateDir 'technitium-backup.json'

if (Test-Path -LiteralPath $pidPath) {
    $proxyPid = [int](Get-Content -LiteralPath $pidPath -Raw)
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$proxyPid" -ErrorAction SilentlyContinue
    $removePidFile = -not [bool]$process
    if ($process -and $process.CommandLine -match 'pass_front\.py') {
        if ($PSCmdlet.ShouldProcess("PID $proxyPid", 'Stop tracked TLS proxy')) {
            Stop-Process -Id $proxyPid -Force
            $removePidFile = $true
        }
    } elseif ($process) {
        Write-Warning "PID $proxyPid is no longer pass_front.py; it was not stopped."
        $removePidFile = $true
    }
    if ($removePidFile) {
        Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
    }
}

if (Test-Path -LiteralPath $compose) {
    if ($PSCmdlet.ShouldProcess($compose, 'Stop GenieACS Compose services without deleting volumes')) {
        docker compose -f $compose down
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Docker Compose teardown failed.' }
    }
}

foreach ($name in 'JioSTB temporary DNS UDP', 'JioSTB temporary DNS TCP', 'JioSTB temporary TLS') {
    $rules = @(Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue)
    foreach ($rule in $rules) {
        if ($PSCmdlet.ShouldProcess($rule.Name, "Remove firewall rule $name")) {
            try { Remove-NetFirewallRule -Name $rule.Name } catch { Write-Warning $_.Exception.Message }
        }
    }
}

function Invoke-TechnitiumApi {
    param([string] $Path, [hashtable] $Parameters)
    $pairs = foreach ($key in $Parameters.Keys) {
        '{0}={1}' -f [uri]::EscapeDataString($key), [uri]::EscapeDataString([string]$Parameters[$key])
    }
    $uri = "$($TechnitiumServer.TrimEnd('/'))$Path?$($pairs -join '&')"
    $result = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 15
    if ($result.status -ne 'ok') { throw "Technitium API failed for $Path`: $($result.errorMessage)" }
    return $result
}

$token = $null
if (Test-Path -LiteralPath $backupPath) {
    $credential = Get-Credential -UserName 'admin' -Message 'Technitium administrator credentials for cleanup'
    $login = Invoke-TechnitiumApi '/api/user/login' @{
        user = $credential.UserName
        pass = $credential.GetNetworkCredential().Password
        includeInfo = 'true'
    }
    $token = $login.response.token
    try {
        $backup = Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json
        if ($backup.zoneCreated) {
            if ($PSCmdlet.ShouldProcess('acs.oss.jio.com', 'Delete exact temporary Technitium zone')) {
                try {
                    $null = Invoke-TechnitiumApi '/api/zones/delete' @{ token = $token; zone = 'acs.oss.jio.com' }
                } catch {
                    Write-Warning "Could not delete zone: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Host 'The acs.oss.jio.com zone predated this run and was left unchanged.'
        }
        $listeners = $backup.dnsServerLocalEndPoints
        if ($listeners -is [array]) { $listeners = $listeners -join ',' }
        if ($PSCmdlet.ShouldProcess($listeners, 'Restore Technitium listener endpoints')) {
            $null = Invoke-TechnitiumApi '/api/settings/set' @{
                token = $token
                dnsServerLocalEndPoints = [string]$listeners
            }
            Remove-Item -LiteralPath $backupPath -Force
        }
    } finally {
        if ($token) {
            try { $null = Invoke-TechnitiumApi '/api/user/logout' @{ token = $token } } catch { }
        }
    }
} else {
    Write-Warning 'No saved Technitium state was found; its zone and listener endpoints were not changed.'
}

Write-Host 'PC-side cleanup complete. The Docker Mongo volume was preserved.'
