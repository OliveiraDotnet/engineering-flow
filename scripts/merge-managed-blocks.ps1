#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TemplatePath,

    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [switch]$CheckOnly,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) {
    Write-Error "Template file not found: $TemplatePath"
    exit 2
}
if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
    Write-Error "Target file not found: $TargetPath"
    exit 2
}

$Utf8Strict = [Text.UTF8Encoding]::new($false, $true)
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

function Read-Utf8WithBomFlag {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $offset = if ($hasBom) { 3 } else { 0 }
    $text = $Utf8Strict.GetString($bytes, $offset, $bytes.Length - $offset)
    return [pscustomobject]@{
        HasBom = $hasBom
        Text   = $text
    }
}

function Get-ManagedBlocks {
    param([Parameter(Mandatory = $true)][string]$Text)

    $blocks = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    $openId = $null
    $openInnerStart = 0
    $markerCount = 0

    $regex = [regex]::new('<!--\s*ef:managed:([^\r\n]*?)-->')
    foreach ($m in $regex.Matches($Text)) {
        $markerCount++
        $mStart = $m.Index
        $mEnd = $m.Index + $m.Length
        $payload = $m.Groups[1].Value.Trim()

        $tagMatch = [regex]::Match($payload, '^(begin|end):([A-Za-z0-9_-]+)$')
        if (-not $tagMatch.Success) {
            return [pscustomobject]@{ Status = 'MALFORMED'; Blocks = @() }
        }
        $kind = $tagMatch.Groups[1].Value
        $id = $tagMatch.Groups[2].Value

        if ($kind -eq 'begin') {
            if ($null -ne $openId) { return [pscustomobject]@{ Status = 'MALFORMED'; Blocks = @() } }
            if ($seen.ContainsKey($id)) { return [pscustomobject]@{ Status = 'MALFORMED'; Blocks = @() } }
            $openId = $id
            $openInnerStart = $mEnd
            $after = $Text.Substring($mEnd)
            $nlMatch = [regex]::Match($after, '^([ \t]*\r?\n)')
            if ($nlMatch.Success) {
                $openInnerStart += $nlMatch.Length
            }
        }
        else {
            if ($null -eq $openId) { return [pscustomobject]@{ Status = 'MALFORMED'; Blocks = @() } }
            if ($openId -ne $id) { return [pscustomobject]@{ Status = 'MALFORMED'; Blocks = @() } }
            $blocks.Add([pscustomobject]@{
                Id         = $id
                InnerStart = $openInnerStart
                InnerEnd   = $mStart
            }) | Out-Null
            $seen[$id] = $true
            $openId = $null
            $openInnerStart = 0
        }
    }

    if ($null -ne $openId) {
        return [pscustomobject]@{ Status = 'MALFORMED'; Blocks = @() }
    }
    if ($markerCount -eq 0) {
        return [pscustomobject]@{ Status = 'NO_MARKERS'; Blocks = @() }
    }
    return [pscustomobject]@{ Status = 'VALID'; Blocks = $blocks.ToArray() }
}

function Convert-Eol {
    param([string]$Text, [string]$TargetEol)
    return [regex]::Replace($Text, '\r?\n', $TargetEol)
}

$tmplData = Read-Utf8WithBomFlag -Path $TemplatePath
$tmplParsed = Get-ManagedBlocks -Text $tmplData.Text
if ($tmplParsed.Status -ne 'VALID') {
    [Console]::Error.WriteLine("ERROR: Template $TemplatePath has invalid ef:managed markers ($($tmplParsed.Status)).")
    exit 2
}

$tmplInner = @{}
$tmplOrder = New-Object System.Collections.Generic.List[string]
foreach ($b in $tmplParsed.Blocks) {
    $tmplInner[$b.Id] = $tmplData.Text.Substring($b.InnerStart, $b.InnerEnd - $b.InnerStart)
    $tmplOrder.Add($b.Id) | Out-Null
}

$targetData = Read-Utf8WithBomFlag -Path $TargetPath
$targetText = $targetData.Text
$targetName = [IO.Path]::GetFileName($TargetPath)
$targetParsed = Get-ManagedBlocks -Text $targetText

if ($targetParsed.Status -eq 'NO_MARKERS') {
    if (-not $Quiet) {
        [Console]::Error.WriteLine("WARNING: $targetName has no ef:managed markers; kept as is. Review $targetName.agent-pack.new and add markers to enable merge.")
    }
    exit 7
}
if ($targetParsed.Status -eq 'MALFORMED') {
    if (-not $Quiet) {
        [Console]::Error.WriteLine("WARNING: $targetName has malformed ef:managed markers; kept as is. Review $targetName.agent-pack.new and add markers to enable merge.")
    }
    exit 7
}

$targetEol = if ($targetText.Contains("`r`n")) { "`r`n" } else { "`n" }
$sb = [System.Text.StringBuilder]::new()
$pos = 0
$targetSeen = @{}

foreach ($b in $targetParsed.Blocks) {
    $id = $b.Id
    $targetSeen[$id] = $true
    [void]$sb.Append($targetText.Substring($pos, $b.InnerStart - $pos))
    if ($tmplInner.ContainsKey($id)) {
        [void]$sb.Append((Convert-Eol -Text $tmplInner[$id] -TargetEol $targetEol))
    }
    else {
        if (-not $Quiet) {
            [Console]::Error.WriteLine("WARNING: $targetName contains unknown ef:managed block '$id'; kept intact.")
        }
        [void]$sb.Append($targetText.Substring($b.InnerStart, $b.InnerEnd - $b.InnerStart))
    }
    $pos = $b.InnerEnd
}
[void]$sb.Append($targetText.Substring($pos))

foreach ($id in $tmplOrder) {
    if ($targetSeen.ContainsKey($id)) { continue }
    $currentOut = $sb.ToString()
    if ($currentOut.Length -gt 0) {
        if (-not $currentOut.EndsWith("`n")) {
            [void]$sb.Append($targetEol)
            $currentOut = $sb.ToString()
        }
        if ($currentOut -notmatch '(?:\r?\n){2}$') {
            [void]$sb.Append($targetEol)
        }
    }
    $adapted = Convert-Eol -Text $tmplInner[$id] -TargetEol $targetEol
    if ($adapted.Length -gt 0 -and -not $adapted.EndsWith("`n")) {
        $adapted += $targetEol
    }
    [void]$sb.Append("<!-- ef:managed:begin:$id -->$targetEol")
    [void]$sb.Append($adapted)
    [void]$sb.Append("<!-- ef:managed:end:$id -->$targetEol")
}

$blocksCsv = ($tmplOrder -join ',')
if ($CheckOnly) {
    Write-Output $blocksCsv
    exit 0
}

$bodyBytes = $Utf8NoBom.GetBytes($sb.ToString())
if ($targetData.HasBom) {
    $finalBytes = [byte[]]::new(3 + $bodyBytes.Length)
    $finalBytes[0] = 0xEF
    $finalBytes[1] = 0xBB
    $finalBytes[2] = 0xBF
    [Array]::Copy($bodyBytes, 0, $finalBytes, 3, $bodyBytes.Length)
}
else {
    $finalBytes = $bodyBytes
}

$tmpPath = "$TargetPath.agent-pack.tmp." + [Guid]::NewGuid().ToString('N')
[IO.File]::WriteAllBytes($tmpPath, $finalBytes)
[IO.File]::Move($tmpPath, $TargetPath, $true)

Write-Output $blocksCsv
exit 0
