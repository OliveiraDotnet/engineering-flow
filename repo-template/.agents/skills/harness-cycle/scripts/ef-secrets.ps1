# Shared secret masking, scanning, and runner-block helpers for Engineering Flow harness scripts.

$script:EfSecretValues = @()
$script:EfSecretNames = @()
$script:EfCustomKeyRegex = $null
$script:EfLastMaskCount = 0
$script:EfScanStatus = 'clean'
$script:EfScanFindings = @()
$script:EfScanUnscanned = @()
$script:EfUtf8NoBom = [Text.UTF8Encoding]::new($false)

$script:EfBearerRegex = [regex]::new('\b(Bearer\s+)([A-Za-z0-9._~+/=-]+)', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Compiled)
$script:EfTokenPrefixRegex = [regex]::new('(?:gho_|ghp_|github_pat_)[A-Za-z0-9_]{10,}|AKIA[0-9A-Z]{16}', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Compiled)
$script:EfConnStrRegex = [regex]::new('(\b(?:Password|User\s+ID)\s*=\s*["'']?)([^;"''\r\n]+)(?=["'']?\s*;)', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Compiled)
$script:EfFixedKeyPrefix = '(?<![A-Za-z0-9_.-])(?!(?:cache_key|primary_key|foreign_key|sort_key|partition_key)(?![A-Za-z0-9_.-]))[A-Za-z0-9_.-]*(?:password|pwd|key|token|secret)'

function Resolve-EfCanonicalPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) {
        try {
            $item = Get-Item -LiteralPath $full -Force
            if ($item.LinkTarget) {
                $target = $item.ResolveLinkTarget($true)
                if ($target) { return $target.FullName.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) }
            }
            return (Resolve-Path -LiteralPath $full).Path.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        }
        catch {
            return $full.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        }
    }
    $parts = [System.Collections.Generic.List[string]]::new()
    $cur = $full.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    while ($cur) {
        if (Test-Path -LiteralPath $cur) {
            $resolved = (Resolve-Path -LiteralPath $cur).Path.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            for ($i = $parts.Count - 1; $i -ge 0; $i--) {
                $resolved = Join-Path $resolved $parts[$i]
            }
            return $resolved
        }
        $leaf = Split-Path -Leaf $cur
        $parent = Split-Path -Parent $cur
        if (-not $parent -or $parent -eq $cur) { break }
        $parts.Add($leaf)
        $cur = $parent.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    }
    return $full.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Test-EfPathInside([string]$FilePath, [string]$DirPath) {
    $cf = Resolve-EfCanonicalPath $FilePath
    $cd = Resolve-EfCanonicalPath $DirPath
    $cmp = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if ([string]::Equals($cf, $cd, $cmp)) { return $true }
    $prefix = $cd + [IO.Path]::DirectorySeparatorChar
    $altPrefix = $cd + [IO.Path]::AltDirectorySeparatorChar
    return $cf.StartsWith($prefix, $cmp) -or $cf.StartsWith($altPrefix, $cmp)
}

function ef_load_secrets {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$HarnessLogDir = ''
    )
    if (-not $HarnessLogDir) {
        $HarnessLogDir = Join-Path $RepoRoot '.agent-pack/logs'
    }

    $secretFile = $env:EF_SECRET_VALUES_FILE
    if ($secretFile) {
        if (-not (Test-Path -LiteralPath $secretFile -PathType Leaf)) {
            [Console]::Error.WriteLine('Error: EF_SECRET_VALUES_FILE does not exist or is not a regular file.')
            return 2
        }
        $forbidden = @(
            $RepoRoot,
            $HarnessLogDir,
            (Join-Path $RepoRoot '.agent-pack/evidencias'),
            (Join-Path $RepoRoot '.agent-pack/.runtime')
        )
        foreach ($dir in $forbidden) {
            if (Test-EfPathInside $secretFile $dir) {
                [Console]::Error.WriteLine('Error: EF_SECRET_VALUES_FILE cannot reside inside the repository, EF_HARNESS_LOG_DIR, evidencias/, or .runtime/.')
                return 2
            }
        }
    }

    $valsSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $addVal = {
        param([string]$v)
        if ([string]::IsNullOrEmpty($v) -or $v.Length -lt 6) { return }
        [void]$valsSet.Add($v)
        $j1 = $v.Replace('\', '\\').Replace('"', '\"')
        if ($j1.Length -ge 6) { [void]$valsSet.Add($j1) }
        $j2 = $j1.Replace('/', '\/')
        if ($j2.Length -ge 6) { [void]$valsSet.Add($j2) }
    }

    foreach ($entry in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
        $k = [string]$entry.Key
        if ($k -match '(?:TOKEN|PAT|KEY|SECRET|PASSWORD)$') {
            & $addVal ([string]$entry.Value)
        }
    }

    if ($secretFile) {
        $lines = [IO.File]::ReadAllLines($secretFile, $script:EfUtf8NoBom)
        foreach ($line in $lines) {
            $trimmed = $line.TrimEnd("`r", "`n")
            if ($trimmed.Length -gt 0) {
                & $addVal $trimmed
            }
        }
    }

    $namesSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $addNames = {
        param([string]$raw)
        if ([string]::IsNullOrWhiteSpace($raw)) { return }
        foreach ($item in ($raw -split ',')) {
            $clean = $item.Trim().Trim('[', ']').Trim('`').Trim()
            if (-not $clean) { continue }
            if ($clean -in @('...', 'não', 'nao')) { continue }
            [void]$namesSet.Add($clean)
        }
    }

    if ($env:EF_SECRET_NAMES) {
        & $addNames $env:EF_SECRET_NAMES
    }

    $agentsMd = Join-Path $RepoRoot 'AGENTS.md'
    if (Test-Path -LiteralPath $agentsMd -PathType Leaf) {
        foreach ($line in [IO.File]::ReadAllLines($agentsMd, [Text.Encoding]::UTF8)) {
            if ($line -match '^\s*-\s*Nomes\s+sens[ií]veis\s+\(mascaramento\)\s*:\s*(.+)$') {
                & $addNames $Matches[1]
            }
        }
    }

    $script:EfSecretValues = @($valsSet | Sort-Object @{ Expression = { -$_.Length } }, @{ Expression = { $_ } })
    $script:EfSecretNames = @($namesSet | Sort-Object @{ Expression = { -$_.Length } }, @{ Expression = { $_ } })

    $customAlt = ''
    if ($script:EfSecretNames.Count -gt 0) {
        $escaped = $script:EfSecretNames | ForEach-Object { [regex]::Escape($_) }
        $customAlt = '|' + ($escaped -join '|')
    }
    $pattern = "((?:$script:EfFixedKeyPrefix$customAlt)(?:\\?[""'])?\s*[=:]\s*(?:\\?[""'])?)((?:(?!\\[""'])[^\s;""'&,])+)"
    $script:EfCustomKeyRegex = [regex]::new($pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Compiled)
    return 0
}

function ConvertFrom-EfJsonEscapesWithMap {
    param([string]$Orig)
    $len = $Orig.Length
    $sb = [System.Text.StringBuilder]::new($len)
    $ostart = [System.Collections.Generic.List[int]]::new($len)
    $oend = [System.Collections.Generic.List[int]]::new($len)
    $i = 0
    while ($i -lt $len) {
        $ch = $Orig[$i]
        if ($ch -eq '\' -and ($i + 1) -lt $len) {
            $nxt = $Orig[$i + 1]
            if ($nxt -eq '"' -or $nxt -eq '\' -or $nxt -eq '/') {
                [void]$sb.Append($nxt)
                $ostart.Add($i)
                $oend.Add($i + 2)
                $i += 2
                continue
            }
            if ($nxt -eq 'u' -and ($i + 5) -lt $len) {
                $hex = $Orig.Substring($i + 2, 4)
                if ($hex -match '^[0-9a-fA-F]{4}$') {
                    $code = [Convert]::ToInt32($hex, 16)
                    if ($code -ne 0 -and -not ($code -ge 0xD800 -and $code -le 0xDFFF)) {
                        [void]$sb.Append([char]$code)
                        $ostart.Add($i)
                        $oend.Add($i + 6)
                        $i += 6
                        continue
                    }
                }
            }
        }
        [void]$sb.Append($ch)
        $ostart.Add($i)
        $oend.Add($i + 1)
        $i += 1
    }
    return [pscustomobject]@{
        Decoded   = $sb.ToString()
        OrigStart = $ostart
        OrigEnd   = $oend
    }
}

function Invoke-EfReplaceSpans {
    param(
        [string]$Orig,
        [System.Collections.Generic.List[int]]$OrigStart,
        [System.Collections.Generic.List[int]]$OrigEnd,
        [System.Collections.Generic.List[int[]]]$Spans
    )
    if ($Spans.Count -eq 0) { return $Orig }
    $sb = [System.Text.StringBuilder]::new($Orig)
    for ($k = $Spans.Count - 1; $k -ge 0; $k--) {
        $ds = $Spans[$k][0]
        $de = $Spans[$k][1]
        if ($de -le $ds) { continue }
        $os = $OrigStart[$ds]
        $oe = $OrigEnd[$de - 1]
        [void]$sb.Remove($os, $oe - $os)
        [void]$sb.Insert($os, '[EF-MASKED]')
    }
    return $sb.ToString()
}

function ef_mask_line {
    param(
        [string]$Line,
        [ref]$CountRef
    )
    if ($null -eq $Line -or $Line.Length -eq 0) { return $Line }
    $count = 0
    $out = $Line
    $map = ConvertFrom-EfJsonEscapesWithMap -Orig $out

    foreach ($v in $script:EfSecretValues) {
        $spans = [System.Collections.Generic.List[int[]]]::new()
        $idx = 0
        while (($pos = $map.Decoded.IndexOf($v, $idx, [StringComparison]::Ordinal)) -ge 0) {
            $spans.Add([int[]]@($pos, ($pos + $v.Length)))
            $idx = $pos + $v.Length
        }
        if ($spans.Count -gt 0) {
            $out = Invoke-EfReplaceSpans -Orig $out -OrigStart $map.OrigStart -OrigEnd $map.OrigEnd -Spans $spans
            $count += $spans.Count
            $map = ConvertFrom-EfJsonEscapesWithMap -Orig $out
        }
    }

    $spans = [System.Collections.Generic.List[int[]]]::new()
    foreach ($m in $script:EfBearerRegex.Matches($map.Decoded)) {
        $g = $m.Groups[2]
        $spans.Add([int[]]@($g.Index, ($g.Index + $g.Length)))
    }
    if ($spans.Count -gt 0) {
        $out = Invoke-EfReplaceSpans -Orig $out -OrigStart $map.OrigStart -OrigEnd $map.OrigEnd -Spans $spans
        $count += $spans.Count
        $map = ConvertFrom-EfJsonEscapesWithMap -Orig $out
    }

    $spans = [System.Collections.Generic.List[int[]]]::new()
    foreach ($m in $script:EfTokenPrefixRegex.Matches($map.Decoded)) {
        $spans.Add([int[]]@($m.Index, ($m.Index + $m.Length)))
    }
    if ($spans.Count -gt 0) {
        $out = Invoke-EfReplaceSpans -Orig $out -OrigStart $map.OrigStart -OrigEnd $map.OrigEnd -Spans $spans
        $count += $spans.Count
        $map = ConvertFrom-EfJsonEscapesWithMap -Orig $out
    }

    $spans = [System.Collections.Generic.List[int[]]]::new()
    foreach ($m in $script:EfConnStrRegex.Matches($map.Decoded)) {
        $g = $m.Groups[2]
        if ($g.Value -eq '[EF-MASKED]') { continue }
        $spans.Add([int[]]@($g.Index, ($g.Index + $g.Length)))
    }
    if ($spans.Count -gt 0) {
        $out = Invoke-EfReplaceSpans -Orig $out -OrigStart $map.OrigStart -OrigEnd $map.OrigEnd -Spans $spans
        $count += $spans.Count
        $map = ConvertFrom-EfJsonEscapesWithMap -Orig $out
    }

    if ($null -ne $script:EfCustomKeyRegex) {
        $spans = [System.Collections.Generic.List[int[]]]::new()
        foreach ($m in $script:EfCustomKeyRegex.Matches($map.Decoded)) {
            $g = $m.Groups[2]
            if ($g.Value -eq '[EF-MASKED]') { continue }
            $spans.Add([int[]]@($g.Index, ($g.Index + $g.Length)))
        }
        if ($spans.Count -gt 0) {
            $out = Invoke-EfReplaceSpans -Orig $out -OrigStart $map.OrigStart -OrigEnd $map.OrigEnd -Spans $spans
            $count += $spans.Count
        }
    }

    if ($null -ne $CountRef) {
        $CountRef.Value += $count
    }
    return $out
}

function ef_mask_string {
    param(
        [string]$Text,
        [ref]$CountRef
    )
    $total = 0
    if ([string]::IsNullOrEmpty($Text)) {
        if ($null -ne $CountRef) { $CountRef.Value = 0 }
        $script:EfLastMaskCount = 0
        return $Text
    }

    $sb = [System.Text.StringBuilder]::new($Text.Length)
    $parts = [regex]::Split($Text, '(?<=\n)')
    foreach ($part in $parts) {
        if ($part.Length -eq 0) { continue }
        $eol = ''
        $core = $part
        if ($core.EndsWith("`r`n")) {
            $eol = "`r`n"
            $core = $core.Substring(0, $core.Length - 2)
        }
        elseif ($core.EndsWith("`n")) {
            $eol = "`n"
            $core = $core.Substring(0, $core.Length - 1)
        }
        $masked = ef_mask_line -Line $core -CountRef ([ref]$total)
        [void]$sb.Append($masked)
        [void]$sb.Append($eol)
    }
    $script:EfLastMaskCount = $total
    if ($null -ne $CountRef) { $CountRef.Value = $total }
    return $sb.ToString()
}

function ef_mask {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)][AllowEmptyString()][string]$InputObject
    )
    begin {
        $total = 0
    }
    process {
        $masked = ef_mask_line -Line $InputObject -CountRef ([ref]$total)
        Write-Output $masked
    }
    end {
        $script:EfLastMaskCount = $total
    }
}

function ef_scan {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$CardId,
        [string]$HarnessLogDir = ''
    )
    if (-not $HarnessLogDir) {
        $HarnessLogDir = Join-Path $RepoRoot ".agent-pack/logs/$CardId"
    }

    $script:EfScanStatus = 'clean'
    $script:EfScanFindings = @()
    $script:EfScanUnscanned = @()

    $repoAbs = Resolve-EfCanonicalPath $RepoRoot
    $roots = @(
        $HarnessLogDir,
        (Join-Path $RepoRoot ".agent-pack/evidencias/$CardId"),
        (Join-Path $RepoRoot '.agent-pack/.runtime')
    )

    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($r in $roots) {
        if (-not (Test-Path -LiteralPath $r -PathType Container)) { continue }
        foreach ($f in (Get-ChildItem -LiteralPath $r -File -Recurse)) {
            $canon = Resolve-EfCanonicalPath $f.FullName
            if ($seen.Add($canon)) {
                $files.Add($canon)
            }
        }
    }
    $files.Sort([StringComparer]::Ordinal)

    foreach ($file in $files) {
        $rel = $file
        $prefix = $repoAbs + [IO.Path]::DirectorySeparatorChar
        if ($file.StartsWith($prefix, [StringComparison]::Ordinal)) {
            $rel = $file.Substring($prefix.Length).Replace('\', '/')
        }
        $bytes = [IO.File]::ReadAllBytes($file)
        if ([Array]::IndexOf($bytes, [byte]0) -ge 0) {
            $script:EfScanUnscanned += $rel
            continue
        }

        $raw = $script:EfUtf8NoBom.GetString($bytes)
        $cnt = 0
        $masked = ef_mask_string -Text $raw -CountRef ([ref]$cnt)
        if ($cnt -gt 0) {
            $dir = Split-Path -Parent $file
            $leaf = Split-Path -Leaf $file
            $tmp = Join-Path $dir (".ef-scan-tmp.$PID.$leaf")
            [IO.File]::WriteAllText($tmp, $masked, $script:EfUtf8NoBom)
            [IO.File]::Move($tmp, $file, $true)
            $script:EfScanStatus = 'SECRET_IN_LOG'
            $script:EfScanFindings += [ordered]@{
                file  = $rel
                count = $cnt
            }
        }
    }

    if ($script:EfScanStatus -eq 'SECRET_IN_LOG') {
        return 6
    }
    return 0
}

function ef_validate_evidence_markers([string]$EvidenceFile) {
    if (-not (Test-Path -LiteralPath $EvidenceFile -PathType Leaf)) { return 0 }
    $bytes = [IO.File]::ReadAllBytes($EvidenceFile)
    $data = [Text.Encoding]::Latin1.GetString($bytes)
    $b = '<!-- runner:begin -->'
    $e = '<!-- runner:end -->'

    $bpos = [System.Collections.Generic.List[int]]::new()
    $idx = 0
    while (($p = $data.IndexOf($b, $idx, [StringComparison]::Ordinal)) -ge 0) {
        $bpos.Add($p)
        $idx = $p + $b.Length
    }
    $epos = [System.Collections.Generic.List[int]]::new()
    $idx = 0
    while (($p = $data.IndexOf($e, $idx, [StringComparison]::Ordinal)) -ge 0) {
        $epos.Add($p)
        $idx = $p + $e.Length
    }

    if ($bpos.Count -ge 2 -or $epos.Count -ge 2) {
        [Console]::Error.WriteLine('Error: EVIDENCIA.md contains multiple runner markers.')
        return 2
    }
    if ($bpos.Count -ne $epos.Count) {
        [Console]::Error.WriteLine('Error: EVIDENCIA.md contains an unmatched runner marker.')
        return 2
    }
    if ($bpos.Count -eq 1 -and $epos[0] -lt $bpos[0]) {
        [Console]::Error.WriteLine('Error: EVIDENCIA.md has runner:end before runner:begin.')
        return 2
    }
    return 0
}

function ef_update_evidence_block {
    param(
        [Parameter(Mandatory = $true)][string]$EvidenceFile,
        [Parameter(Mandatory = $true)][string]$CardId,
        [Parameter(Mandatory = $true)][ValidateSet('replace', 'append_line')][string]$Mode,
        [string]$Body = ''
    )
    $checkRc = ef_validate_evidence_markers $EvidenceFile
    if ($checkRc -ne 0) { return $checkRc }

    $dir = Split-Path -Parent $EvidenceFile
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $leaf = Split-Path -Leaf $EvidenceFile
    $tmp = Join-Path $dir (".ef-ev-tmp.$PID.$leaf")

    $cleanBody = $Body.TrimEnd("`r", "`n")
    $b = '<!-- runner:begin -->'
    $e = '<!-- runner:end -->'

    if (-not (Test-Path -LiteralPath $EvidenceFile -PathType Leaf)) {
        $content = "# Evidencia de Testes — Card $CardId`n`n$b`n$cleanBody`n$e`n"
        [IO.File]::WriteAllText($tmp, $content, $script:EfUtf8NoBom)
        [IO.File]::Move($tmp, $EvidenceFile, $true)
        return 0
    }

    $rawBytes = [IO.File]::ReadAllBytes($EvidenceFile)
    $bBytes = [Text.Encoding]::ASCII.GetBytes($b)
    $eBytes = [Text.Encoding]::ASCII.GetBytes($e)

    $findSub = {
        param([byte[]]$hay, [byte[]]$needle)
        for ($i = 0; $i -le $hay.Length - $needle.Length; $i++) {
            $ok = $true
            for ($j = 0; $j -lt $needle.Length; $j++) {
                if ($hay[$i + $j] -ne $needle[$j]) { $ok = $false; break }
            }
            if ($ok) { return $i }
        }
        return -1
    }

    $hasCrlf = $false
    for ($i = 0; $i -lt $rawBytes.Length - 1; $i++) {
        if ($rawBytes[$i] -eq 13 -and $rawBytes[$i + 1] -eq 10) { $hasCrlf = $true; break }
    }
    $eolStr = if ($hasCrlf) { "`r`n" } else { "`n" }
    $eolBytes = [Text.Encoding]::ASCII.GetBytes($eolStr)
    $normBody = ($cleanBody -replace "\r?\n", "`n").Replace("`n", $eolStr)
    $bodyBytes = $script:EfUtf8NoBom.GetBytes($normBody)

    $bp = & $findSub $rawBytes $bBytes
    $ep = & $findSub $rawBytes $eBytes

    $ms = [IO.MemoryStream]::new()
    try {
        if ($bp -ge 0 -and $ep -ge 0) {
            $prefixLen = $bp + $bBytes.Length
            $ms.Write($rawBytes, 0, $prefixLen)
            $ms.Write($eolBytes, 0, $eolBytes.Length)
            if ($Mode -eq 'append_line') {
                $innerStart = $prefixLen
                $innerLen = $ep - $innerStart
                $innerStr = $script:EfUtf8NoBom.GetString($rawBytes, $innerStart, $innerLen).Trim("`r", "`n")
                $combined = if ($innerStr.Length -gt 0) { "$innerStr$eolStr$normBody" } else { $normBody }
                $combBytes = $script:EfUtf8NoBom.GetBytes($combined)
                $ms.Write($combBytes, 0, $combBytes.Length)
            }
            else {
                $ms.Write($bodyBytes, 0, $bodyBytes.Length)
            }
            $ms.Write($eolBytes, 0, $eolBytes.Length)
            $ms.Write($rawBytes, $ep, $rawBytes.Length - $ep)
        }
        else {
            $ms.Write($rawBytes, 0, $rawBytes.Length)
            if ($rawBytes.Length -gt 0) {
                $endsWithLf = ($rawBytes[$rawBytes.Length - 1] -eq 10)
                if (-not $endsWithLf) {
                    $ms.Write($eolBytes, 0, $eolBytes.Length)
                    $ms.Write($eolBytes, 0, $eolBytes.Length)
                }
                else {
                    $endsWithDouble = $false
                    if ($hasCrlf -and $rawBytes.Length -ge 4) {
                        $endsWithDouble = ($rawBytes[$rawBytes.Length - 4] -eq 13 -and $rawBytes[$rawBytes.Length - 3] -eq 10 -and $rawBytes[$rawBytes.Length - 2] -eq 13 -and $rawBytes[$rawBytes.Length - 1] -eq 10)
                    }
                    elseif (-not $hasCrlf -and $rawBytes.Length -ge 2) {
                        $endsWithDouble = ($rawBytes[$rawBytes.Length - 2] -eq 10 -and $rawBytes[$rawBytes.Length - 1] -eq 10)
                    }
                    if (-not $endsWithDouble) {
                        $ms.Write($eolBytes, 0, $eolBytes.Length)
                    }
                }
            }
            $ms.Write($bBytes, 0, $bBytes.Length)
            $ms.Write($eolBytes, 0, $eolBytes.Length)
            $ms.Write($bodyBytes, 0, $bodyBytes.Length)
            $ms.Write($eolBytes, 0, $eolBytes.Length)
            $ms.Write($eBytes, 0, $eBytes.Length)
            $ms.Write($eolBytes, 0, $eolBytes.Length)
        }
        [IO.File]::WriteAllBytes($tmp, $ms.ToArray())
        [IO.File]::Move($tmp, $EvidenceFile, $true)
    }
    finally {
        $ms.Dispose()
    }
    return 0
}

function ef_extract_evidence_runner_block([string]$EvidenceFile) {
    if (-not (Test-Path -LiteralPath $EvidenceFile -PathType Leaf)) { return '' }
    $data = [IO.File]::ReadAllText($EvidenceFile, [Text.Encoding]::UTF8)
    $b = '<!-- runner:begin -->'
    $e = '<!-- runner:end -->'
    $bp = $data.IndexOf($b, [StringComparison]::Ordinal)
    $ep = $data.IndexOf($e, [StringComparison]::Ordinal)
    if ($bp -ge 0 -and $ep -gt $bp) {
        return $data.Substring($bp, $ep - $bp + $e.Length)
    }
    return ''
}

function ef_write_test_status {
    param(
        [Parameter(Mandatory = $true)][string]$StatusFile,
        [Parameter(Mandatory = $true)][ValidateSet('tester', 'scan_fail', 'allow_unvalidated')][string]$Mode,
        [hashtable]$Values = @{}
    )
    $dir = Split-Path -Parent $StatusFile
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $leaf = Split-Path -Leaf $StatusFile
    $tmp = Join-Path $dir (".ef-status-tmp.$PID.$leaf")

    $obj = [ordered]@{}
    if ($Mode -ne 'tester' -and (Test-Path -LiteralPath $StatusFile -PathType Leaf)) {
        try {
            $parsed = [IO.File]::ReadAllText($StatusFile, [Text.Encoding]::UTF8) | ConvertFrom-Json -AsHashtable
            if ($parsed -is [System.Collections.IDictionary]) {
                foreach ($k in $parsed.Keys) { $obj[$k] = $parsed[$k] }
            }
        }
        catch {
            $obj = [ordered]@{}
        }
    }

    $findingsArr = @($script:EfScanFindings)
    $unscannedArr = @($script:EfScanUnscanned)

    if ($Mode -eq 'tester') {
        $obj['cardId'] = [string]$Values['cardId']
        $obj['demandType'] = [string]$Values['demandType']
        $obj['phase'] = [string]$Values['phase']
        $obj['passed'] = [bool]$Values['passed']
        $obj['exitCode'] = [int]$Values['exitCode']
        $obj['evidencePath'] = [string]$Values['evidencePath']
        $obj['timestamp'] = [string]$Values['timestamp']
        $obj['reason'] = if ($Values.ContainsKey('reason') -and $Values['reason']) { [string]$Values['reason'] } else { $null }
        $obj['secretScan'] = [ordered]@{
            status    = [string]$Values['scanStatus']
            findings  = $findingsArr
            unscanned = $unscannedArr
        }
    }
    elseif ($Mode -eq 'scan_fail') {
        if (-not $obj.Contains('cardId') -and $Values.ContainsKey('cardId')) { $obj['cardId'] = [string]$Values['cardId'] }
        $obj['passed'] = $false
        $obj['reason'] = 'SECRET_IN_LOG'
        if (-not $obj.Contains('evidencePath') -and $Values.ContainsKey('evidencePath')) { $obj['evidencePath'] = [string]$Values['evidencePath'] }
        $obj['timestamp'] = [string]$Values['timestamp']
        $obj['secretScan'] = [ordered]@{
            status    = 'SECRET_IN_LOG'
            findings  = $findingsArr
            unscanned = $unscannedArr
        }
    }
    elseif ($Mode -eq 'allow_unvalidated') {
        if (-not $obj.Contains('cardId') -and $Values.ContainsKey('cardId')) { $obj['cardId'] = [string]$Values['cardId'] }
        if (-not $obj.Contains('passed')) { $obj['passed'] = $null }
        $obj['allowUnvalidated'] = $true
        $obj['allowUnvalidatedReason'] = [string]$Values['allowUnvalidatedReason']
        $obj['allowUnvalidatedAt'] = [string]$Values['allowUnvalidatedAt']
        $obj['timestamp'] = [string]$Values['allowUnvalidatedAt']
    }

    $json = ($obj | ConvertTo-Json -Depth 10) + "`n"
    [IO.File]::WriteAllText($tmp, $json, $script:EfUtf8NoBom)
    [IO.File]::Move($tmp, $StatusFile, $true)
}

function ef_split_args([string]$RawArgs) {
    if ([string]::IsNullOrWhiteSpace($RawArgs)) { return @() }
    $tokens = [System.Collections.Generic.List[string]]::new()
    $sb = [System.Text.StringBuilder]::new()
    $inSingle = $false
    $inDouble = $false
    $hasToken = $false
    for ($i = 0; $i -lt $RawArgs.Length; $i++) {
        $ch = $RawArgs[$i]
        if ($inSingle) {
            if ($ch -eq "'") { $inSingle = $false }
            else { [void]$sb.Append($ch) }
        }
        elseif ($inDouble) {
            if ($ch -eq '\' -and ($i + 1) -lt $RawArgs.Length) {
                $i++
                [void]$sb.Append($RawArgs[$i])
            }
            elseif ($ch -eq '"') { $inDouble = $false }
            else { [void]$sb.Append($ch) }
        }
        else {
            if ([char]::IsWhiteSpace($ch)) {
                if ($hasToken) {
                    $tokens.Add($sb.ToString())
                    [void]$sb.Clear()
                    $hasToken = $false
                }
            }
            elseif ($ch -eq "'") {
                $inSingle = $true
                $hasToken = $true
            }
            elseif ($ch -eq '"') {
                $inDouble = $true
                $hasToken = $true
            }
            elseif ($ch -eq '\' -and ($i + 1) -lt $RawArgs.Length) {
                $i++
                [void]$sb.Append($RawArgs[$i])
                $hasToken = $true
            }
            else {
                [void]$sb.Append($ch)
                $hasToken = $true
            }
        }
    }
    if ($hasToken) { $tokens.Add($sb.ToString()) }
    return @($tokens)
}

function ef_extract_flag_names([string[]]$ArgsArray) {
    $flags = [System.Collections.Generic.List[string]]::new()
    foreach ($tok in $ArgsArray) {
        if ($tok -like '-*') {
            $eqIdx = $tok.IndexOf('=')
            if ($eqIdx -gt 0) { $flags.Add($tok.Substring(0, $eqIdx)) }
            else { $flags.Add($tok) }
        }
    }
    return ($flags -join ',')
}

function ef_check_agy_effort([string[]]$ArgsArray) {
    for ($i = 0; $i -lt $ArgsArray.Length; $i++) {
        $tok = $ArgsArray[$i]
        if ($tok -eq '--effort') {
            if (($i + 1) -ge $ArgsArray.Length -or $ArgsArray[$i + 1] -ne 'high') {
                [Console]::Error.WriteLine('Error: agy harness requires --effort high.')
                return 2
            }
            $i++
        }
        elseif ($tok -like '--effort=*') {
            if ($tok.Substring(9) -ne 'high') {
                [Console]::Error.WriteLine('Error: agy harness requires --effort high.')
                return 2
            }
        }
    }
    return 0
}
