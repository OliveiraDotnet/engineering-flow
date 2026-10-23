#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Server,

    [ValidateRange(1, 65535)]
    [int]$Port = 1433,

    [ValidateRange(1, 60000)]
    [int]$TimeoutMs = 3000
)

$ErrorActionPreference = "Stop"
$serverHost = $Server.Trim()
$result = [ordered]@{
    Server = $Server
    HostName = $null
    Port = $Port
    DnsResolved = $false
    Addresses = @()
    TcpReachable = $false
    ElapsedMs = $null
    LikelyIssue = $null
    Recommendation = $null
    Notes = @()
}

if ($serverHost.Contains('\')) {
    $parts = $serverHost.Split('\')
    if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
        throw "Use a host/IP, or HOST\INSTANCE with an explicit actual TCP Port."
    }
    $serverHost = $parts[0]
    if (-not $PSBoundParameters.ContainsKey('Port')) {
        $result.HostName = $serverHost
        $result.Port = $null
        $result.LikelyIssue = "Named instance requires its actual TCP port"
        $result.Recommendation = "Supply -Port from known configuration; no DNS, SQL Browser, or TCP probe was attempted."
        [pscustomobject]$result
        return
    }
    $result.Notes += "Named instance: checking only the supplied host/port, without SQL Browser discovery."
}
if ([string]::IsNullOrWhiteSpace($serverHost) -or $serverHost -match '[,;/=\s]' -or $serverHost.StartsWith('tcp:', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Server must be a host/IP, not a connection string, URI, or host,port. Use -Port separately."
}
$result.HostName = $serverHost
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$client = $null
try {
    $dnsTask = [System.Net.Dns]::GetHostAddressesAsync($serverHost)
    if (-not $dnsTask.Wait($TimeoutMs)) {
        $result.LikelyIssue = "DNS resolution timed out"
        $result.Recommendation = "Check the known hostname and DNS/VPN path; no TCP probe was attempted."
    } else {
        $addresses = $dnsTask.GetAwaiter().GetResult()
        $result.DnsResolved = $addresses.Count -gt 0
        $result.Addresses = @($addresses | ForEach-Object { $_.IPAddressToString })
        if (-not $result.DnsResolved) {
            $result.LikelyIssue = "DNS returned no addresses"
            $result.Recommendation = "Confirm the hostname or use the known IP."
        } else {
            $client = [System.Net.Sockets.TcpClient]::new()
            $connectTask = $client.ConnectAsync($addresses, $Port)
            if (-not $connectTask.Wait($TimeoutMs)) {
                $result.LikelyIssue = "TCP connection timed out"
                $result.Recommendation = "Confirm listener, port, VPN/firewall, or use user-run metadata collection."
            } elseif ($client.Connected) {
                $result.TcpReachable = $true
                $result.LikelyIssue = "Network path is reachable"
                $result.Recommendation = "Only TCP was checked; authentication, SQL Server identity, and metadata permissions are unverified."
            }
        }
    }
} catch {
    $result.LikelyIssue = if ($result.DnsResolved) { "TCP connection failed" } else { "DNS resolution failed" }
    $result.Recommendation = "Check the target and known network conditions; use user-run metadata collection if direct access is unavailable."
} finally {
    $stopwatch.Stop()
    $result.ElapsedMs = $stopwatch.ElapsedMilliseconds
    if ($null -ne $client) { $client.Dispose() }
}
[pscustomobject]$result
