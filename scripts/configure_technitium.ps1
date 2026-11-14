[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ipaddress] $PcIp,
    [string] $Server = 'http://127.0.0.1:5380'
)

$ErrorActionPreference = 'Stop'
$stateDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.state'
$backupPath = Join-Path $stateDir 'technitium-backup.json'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

function Invoke-TechnitiumApi {
    param([string] $Path, [hashtable] $Parameters)
    $pairs = foreach ($key in $Parameters.Keys) {
        '{0}={1}' -f [uri]::EscapeDataString($key), [uri]::EscapeDataString([string]$Parameters[$key])
    }
    $uri = "$($Server.TrimEnd('/'))$Path?$($pairs -join '&')"
    $result = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 15
    if ($result.status -ne 'ok') {
        throw "Technitium API failed for $Path`: $($result.errorMessage)"
    }
    return $result
}

$credential = Get-Credential -UserName 'admin' -Message 'Technitium administrator credentials'
$login = Invoke-TechnitiumApi '/api/user/login' @{
    user = $credential.UserName
    pass = $credential.GetNetworkCredential().Password
    includeInfo = 'true'
}
$token = $login.response.token

try {
    $settings = Invoke-TechnitiumApi '/api/settings/get' @{ token = $token }
    $zones = Invoke-TechnitiumApi '/api/zones/list' @{ token = $token }
    $zoneExists = @($zones.response.zones) | Where-Object { $_.name -eq 'acs.oss.jio.com' }
    if (-not (Test-Path -LiteralPath $backupPath)) {
        @{
            dnsServerLocalEndPoints = $settings.response.dnsServerLocalEndPoints
            zoneCreated = -not [bool]$zoneExists
            savedAt = (Get-Date).ToString('o')
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $backupPath -Encoding UTF8
    } else {
        Write-Warning "Keeping existing listener backup: $backupPath"
    }

    $listeners = "$($PcIp.IPAddressToString):53,127.0.0.1:53,[::1]:53"
    $null = Invoke-TechnitiumApi '/api/settings/set' @{
        token = $token
        dnsServerLocalEndPoints = $listeners
    }

    if (-not $zoneExists) {
        $null = Invoke-TechnitiumApi '/api/zones/create' @{
            token = $token
            zone = 'acs.oss.jio.com'
            type = 'Primary'
        }
        $null = Invoke-TechnitiumApi '/api/zones/records/add' @{
            token = $token
            zone = 'acs.oss.jio.com'
            domain = 'acs.oss.jio.com'
            type = 'A'
            ipAddress = $PcIp.IPAddressToString
            ttl = '60'
        }
    } else {
        Write-Warning 'The exact zone already exists, so the script did not alter it and will not delete it during cleanup.'
    }

    $answer = Resolve-DnsName -Name 'acs.oss.jio.com' -Server $PcIp.IPAddressToString -Type A -DnsOnly -ErrorAction Stop
    if ($answer.IPAddress -notcontains $PcIp.IPAddressToString) {
        throw "Existing acs.oss.jio.com zone does not resolve to $PcIp. Correct it in Technitium before continuing."
    }

    Write-Host "Technitium now listens on $listeners"
    Write-Host "acs.oss.jio.com -> $PcIp"
    Write-Host "Backup saved at $backupPath"
    Write-Host 'Keep the PC adapter on normal DHCP/router DNS. Point only the STB at this PC address.'
} finally {
    if ($token) {
        try { $null = Invoke-TechnitiumApi '/api/user/logout' @{ token = $token } } catch { }
    }
}
