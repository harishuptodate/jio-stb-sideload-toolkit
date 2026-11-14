[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)] [ipaddress] $PcIp,
    [Parameter(Mandatory)] [ipaddress] $StbIp,
    [Parameter(Mandatory)] [ValidateSet('JHS', 'JMS')] [string] $Model
)

$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this preparation command from an elevated PowerShell window.'
}

& (Join-Path $PSScriptRoot 'preflight.ps1') -PcIp $PcIp -StbIp $StbIp
& (Join-Path $PSScriptRoot 'configure_technitium.ps1') -PcIp $PcIp

$rules = @(
    @{ Name = 'JioSTB temporary DNS UDP'; Protocol = 'UDP'; Port = '53' },
    @{ Name = 'JioSTB temporary DNS TCP'; Protocol = 'TCP'; Port = '53' },
    @{ Name = 'JioSTB temporary TLS'; Protocol = 'TCP'; Port = '8443,9443' }
)
foreach ($definition in $rules) {
    if ($PSCmdlet.ShouldProcess($definition.Name, 'Replace exact temporary firewall rule')) {
        Get-NetFirewallRule -DisplayName $definition.Name -ErrorAction SilentlyContinue |
            Remove-NetFirewallRule
        New-NetFirewallRule -DisplayName $definition.Name -Direction Inbound -Action Allow `
            -Protocol $definition.Protocol -LocalPort $definition.Port `
            -LocalAddress $PcIp.IPAddressToString -RemoteAddress $StbIp.IPAddressToString `
            -Profile Any | Out-Null
    }
}

& (Join-Path $PSScriptRoot 'start_proxy.ps1') -Model $Model
Write-Host 'Preparation complete. Do not disconnect WAN until offline_watch.py prints READY.'
