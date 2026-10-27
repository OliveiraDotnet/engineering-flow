#Requires -Version 7
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$ScriptDir = Split-Path -Parent $PSCommandPath
$Root = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$script:Passes = 0
$script:Failures = 0
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
$Work = Join-Path ([IO.Path]::GetTempPath()) ("ef311-blobs-" + [Guid]::NewGuid().ToString("N"))
$TempRoot = $null

function Pass {
    param([string]$Message)
    $script:Passes++
    Write-Output "PASSOU: $Message"
}

function Fail-Scenario {
    param([string]$Message)
    $script:Failures++
    Write-Output "FALHOU: $Message"
}

function Write-Summary {
    Write-Output "test-compat-catalogs: passou=$($script:Passes) falhou=$($script:Failures)"
    if ($script:Failures -ne 0) { exit 1 }
    exit 0
}

function Get-NormalizedHash {
    param([string]$Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    $offset = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $offset = 3
    }
    $text = $Utf8Strict.GetString($bytes, $offset, $bytes.Length - $offset)
    $normalized = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($Utf8NoBom.GetBytes($normalized)))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Test-VersionGe211 {
    param([string]$Version)
    $parts = $Version.Split(".")
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patchText = ($parts[2] -replace "[^0-9].*$", "")
    $patch = [int]$patchText
    if ($major -ne 2) { return ($major -gt 2) }
    if ($minor -ne 1) { return ($minor -gt 1) }
    return ($patch -ge 1)
}

function Test-TagExists {
    param([string]$Version)
    & git -C $Root rev-parse --verify --quiet "refs/tags/v$Version" 1>$null 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Save-GitShow {
    param([string]$Spec, [string]$OutFile)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "git"
    $psi.WorkingDirectory = $Root
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    foreach ($arg in @("-C", $Root, "--no-pager", "show", $Spec)) {
        $psi.ArgumentList.Add($arg)
    }
    $process = [Diagnostics.Process]::Start($psi)
    $stream = [IO.File]::Create($OutFile)
    try {
        $process.StandardOutput.BaseStream.CopyTo($stream)
    }
    finally {
        $stream.Dispose()
    }
    $errorText = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "git show falhou: $Spec $errorText"
    }
}

function Get-UsefulLines {
    param([string]$Path)
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($raw in [IO.File]::ReadAllLines($Path)) {
        $line = $raw.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $lines.Add($line)
        }
    }
    return $lines
}

function Read-ManifestMap {
    param([string]$Path)
    $map = @{}
    foreach ($line in (Get-UsefulLines $Path)) {
        $parts = $line.Split("|")
        if ($parts.Count -notin 2, 3) { throw "Manifesto invalido: $line" }
        $source = $parts[1].Trim()
        $dest = if ($parts.Count -eq 3 -and $parts[2].Trim()) { $parts[2].Trim() } else { $source }
        $map[$dest] = $source
    }
    return $map
}

function Read-ArtifactMap {
    param([string]$Path)
    $map = @{}
    foreach ($line in (Get-UsefulLines $Path)) {
        $parts = $line.Split("|")
        if ($parts.Count -ne 3) { throw "pack-artifacts invalido: $line" }
        $map[$parts[0].Trim()] = $parts[1].Trim()
    }
    return $map
}

function Test-SameBytes {
    param([string]$Left, [string]$Right)
    $a = [IO.File]::ReadAllBytes($Left)
    $b = [IO.File]::ReadAllBytes($Right)
    if ($a.Length -ne $b.Length) { return $false }
    for ($i = 0; $i -lt $a.Length; $i++) {
        if ($a[$i] -ne $b[$i]) { return $false }
    }
    return $true
}

function Invoke-Logged {
    param([string[]]$ArgumentList)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "pwsh"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    foreach ($arg in $ArgumentList) { $psi.ArgumentList.Add($arg) }
    $process = [Diagnostics.Process]::Start($psi)
    $outTask = $process.StandardOutput.ReadToEndAsync()
    $errTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $outTask.GetAwaiter().GetResult()
    $stderr = $errTask.GetAwaiter().GetResult()
    $text = $stdout
    if ($stderr) { $text += $stderr }
    return [pscustomobject]@{ Output = $text; Code = $process.ExitCode }
}

function Test-Catalog {
    param(
        [string]$Version,
        [string]$ManifestPath,
        [string]$ArtifactsPath,
        [string]$Mode
    )
    $catalog = Join-Path $Root "compat/releases/$Version.txt"
    $destSource = Read-ManifestMap $ManifestPath
    $artifactDest = Read-ArtifactMap $ArtifactsPath
    $catalogIds = @{}
    $localFailures = 0
    $dataLines = 0
    foreach ($line in (Get-UsefulLines $catalog)) {
        $dataLines++
        $parts = $line.Split("|")
        if ($parts.Count -ne 3) {
            Write-Output "DIVERGENCIA catalogo=$Version id=? destino=? hash_catalogo=$line hash_real=linha-invalida"
            $localFailures++
            continue
        }
        $id = $parts[0].Trim()
        $dest = $parts[1].Trim()
        $hash = $parts[2].Trim().ToLowerInvariant()
        if ($catalogIds.ContainsKey($id)) {
            Write-Output "DIVERGENCIA catalogo=$Version id=$id destino=$dest hash_catalogo=$hash hash_real=id-repetido"
            $localFailures++
            continue
        }
        $catalogIds[$id] = $dest
        if (-not $artifactDest.ContainsKey($id)) {
            Write-Output "DIVERGENCIA catalogo=$Version id=$id destino=$dest hash_catalogo=$hash hash_real=id-ausente-em-pack-artifacts"
            $localFailures++
            continue
        }
        if ($artifactDest[$id] -ne $dest) {
            Write-Output "DIVERGENCIA catalogo=$Version id=$id destino=$dest hash_catalogo=$hash hash_real=destino-diverge-de-pack-artifacts:$($artifactDest[$id])"
            $localFailures++
        }
        if (-not $destSource.ContainsKey($dest)) {
            Write-Output "DIVERGENCIA catalogo=$Version id=$id destino=$dest hash_catalogo=$hash hash_real=destino-sem-origem-no-manifest"
            $localFailures++
            continue
        }
        $source = $destSource[$dest]
        $blob = Join-Path $Work ("blob-" + [Guid]::NewGuid().ToString("N"))
        try {
            if ($Mode -eq "git") {
                Save-GitShow "v${Version}:repo-template/$source" $blob
            }
            else {
                $origin = Join-Path $Root "repo-template/$source"
                if (-not (Test-Path -LiteralPath $origin -PathType Leaf)) {
                    throw "origem ausente"
                }
                Copy-Item -LiteralPath $origin -Destination $blob
            }
            $real = Get-NormalizedHash $blob
        }
        catch {
            Write-Output "DIVERGENCIA catalogo=$Version id=$id destino=$dest hash_catalogo=$hash hash_real=origem-ausente:${source}"
            $localFailures++
            continue
        }
        finally {
            if (Test-Path -LiteralPath $blob) { Remove-Item -LiteralPath $blob -Force }
        }
        if ($real -ne $hash) {
            Write-Output "DIVERGENCIA catalogo=$Version id=$id destino=$dest hash_catalogo=$hash hash_real=$real"
            Write-Output "ESPERADO ${id}|${dest}|${real}"
            $localFailures++
        }
    }
    $onlyCatalog = @($catalogIds.Keys | Where-Object { -not $artifactDest.ContainsKey($_) })
    $onlyArtifacts = @($artifactDest.Keys | Where-Object { -not $catalogIds.ContainsKey($_) })
    if ($onlyCatalog.Count -gt 0 -or $onlyArtifacts.Count -gt 0) {
        $left = if ($onlyCatalog.Count) { $onlyCatalog -join "," } else { "-" }
        $right = if ($onlyArtifacts.Count) { $onlyArtifacts -join "," } else { "-" }
        Write-Output "DIVERGENCIA catalogo=$Version ids somente_catalogo=$left somente_pack_artifacts=$right hash_catalogo=- hash_real=-"
        $localFailures++
    }
    Write-Output "catalogo=$Version linhas_dados=$dataLines modo=$Mode"
    if ($localFailures -eq 0) {
        Pass "catalogo $Version bate com $Mode ($dataLines linhas)"
    }
    else {
        Fail-Scenario "catalogo $Version tem $localFailures divergencia(s)"
    }
}

try {
    New-Item -ItemType Directory -Path $Work | Out-Null
    & git -C $Root rev-parse --is-inside-work-tree 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "AVISO: teste test-compat-catalogs pulado: repositório sem .git (distribuição zip). Catálogos e fixture não foram verificados."
        Write-Output "test-compat-catalogs: passou=0 falhou=0 pulado=1"
        exit 0
    }

    $current = ""
    foreach ($line in (Get-UsefulLines (Join-Path $Root "pack-version.txt"))) {
        $current = $line
    }
    Write-Output "test-compat-catalogs raiz=$Root versao_atual=$current"
    $currentCatalog = Join-Path $Root "compat/releases/$current.txt"
    if (-not (Test-Path -LiteralPath $currentCatalog -PathType Leaf)) {
        Fail-Scenario "catalogo da versao atual ausente: compat/releases/$current.txt"
    }

    $catalogs = @(Get-ChildItem -LiteralPath (Join-Path $Root "compat/releases") -Filter "*.txt" -File | Sort-Object Name)
    if ($catalogs.Count -eq 0) {
        Fail-Scenario "nenhum catalogo em compat/releases"
    }
    foreach ($catalog in $catalogs) {
        $version = [IO.Path]::GetFileNameWithoutExtension($catalog.Name)
        if ($version -eq $current) {
            Test-Catalog $version (Join-Path $Root "pack-manifest.txt") (Join-Path $Root "pack-artifacts.txt") "work"
            continue
        }
        if (Test-TagExists $version) {
            $manifestFile = Join-Path $Work "manifest-$version.txt"
            $artifactsFile = Join-Path $Work "artifacts-$version.txt"
            try {
                Save-GitShow "v${version}:pack-manifest.txt" $manifestFile
                Save-GitShow "v${version}:pack-artifacts.txt" $artifactsFile
                Test-Catalog $version $manifestFile $artifactsFile "git"
            }
            catch {
                Fail-Scenario "nao foi possivel ler manifest/artifacts da tag v${version}: $($_.Exception.Message)"
            }
            continue
        }
        if (Test-VersionGe211 $version) {
            Fail-Scenario "tag ausente: v$version para compat/releases/$version.txt (versao >= 2.1.1). Clone sem tags: git fetch --tags."
        }
        else {
            Write-Output "não verificável: compat/releases/$version.txt sem tag v$version"
            Pass "catalogo $version não verificável"
        }
    }

    & git -C $Root diff --exit-code -- scripts/update-agent-pack.ps1 scripts/update-agent-pack.sh 1>$null 2>$null
    if ($LASTEXITCODE -eq 0) {
        Pass "git diff vazio em update-agent-pack.ps1 e update-agent-pack.sh (Test-TrustedBaseline, Read-CompatibilityCatalog e normalizacao)"
    }
    else {
        Fail-Scenario "update-agent-pack.ps1 ou update-agent-pack.sh tem diff; a logica de confianca nao pode mudar"
    }

    if ($script:Failures -ne 0) {
        Write-Output "Fixture 3.0.0 nao executada porque a conferencia de catalogo falhou."
        Write-Summary
    }

    $TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("ef311-compat-" + [Guid]::NewGuid().ToString("N"))
    $archive = Join-Path $TempRoot "v3.0.0"
    $repo = Join-Path $TempRoot "repo"
    New-Item -ItemType Directory -Path $archive, $repo | Out-Null
    $tar = Join-Path $TempRoot "v3.0.0.tar"
    & git -C $Root archive -o $tar v3.0.0
    if ($LASTEXITCODE -ne 0) {
        Fail-Scenario "git archive v3.0.0 falhou"
        Write-Summary
    }
    & tar -xf $tar -C $archive
    if ($LASTEXITCODE -ne 0) {
        Fail-Scenario "extracao do archive v3.0.0 falhou"
        Write-Summary
    }
    & git init -q $repo
    if ($LASTEXITCODE -ne 0) {
        Fail-Scenario "git init da fixture falhou"
        Write-Summary
    }
    $installer = Join-Path $archive "scripts/install-agent-pack.ps1"
    $installed = Invoke-Logged @("-NoProfile", "-File", $installer, "-RepoPath", $repo, "-Profile", "core", "-Integration", "grok", '-Confirm:$false')
    Write-Output $installed.Output
    if ($installed.Code -ne 0) {
        Fail-Scenario "instalador v3.0.0 (core, grok) falhou (exit $($installed.Code))"
        Write-Summary
    }
    $state = Join-Path $repo ".agent-pack/state.txt"
    if (-not (Test-Path -LiteralPath $state -PathType Leaf)) {
        Fail-Scenario "instalador v3.0.0 nao gravou state.txt"
        Write-Summary
    }
    $stateText = [IO.File]::ReadAllText($state)
    if ($stateText -notmatch "(?m)^version\|3\.0\.0$") { Fail-Scenario "state da fixture nao tem version|3.0.0" }
    if ($stateText -notmatch "(?m)^integration\|grok$") { Fail-Scenario "state da fixture nao tem integration|grok" }
    if ($script:Failures -ne 0) { Write-Summary }
    Pass "fixture instalada pela v3.0.0 (core, grok)"

    $before = Join-Path $TempRoot "state-before-check.txt"
    Copy-Item -LiteralPath $state -Destination $before
    $updater = Join-Path $Root "scripts/update-agent-pack.ps1"
    $check = Invoke-Logged @("-NoProfile", "-File", $updater, "-RepoPath", $repo, "-Check")
    Write-Output $check.Output
    Write-Output "CA2 check_status=$($check.Code)"
    $conflict = @($check.Output -split "`r?`n" | Where-Object { $_ -match "^CONFLICT\b" })
    if ($check.Code -eq 0 -and $conflict.Count -eq 0) {
        Pass "updater -Check da arvore atual na fixture 3.0.0 (exit 0, sem CONFLICT)"
    }
    else {
        Fail-Scenario "updater -Check da fixture 3.0.0 saiu $($check.Code) ou teve CONFLICT"
    }
    if (Test-SameBytes $state $before) {
        Pass "state da fixture byte a byte igual depois do -Check"
    }
    else {
        Fail-Scenario "state da fixture mudou no -Check"
    }
    Write-Output "--- state antes do -Check ---"
    Write-Output ([IO.File]::ReadAllText($before))
    Write-Output "--- state depois do -Check ---"
    Write-Output ([IO.File]::ReadAllText($state))
    Write-Output "--- fim do state ---"

    $managed = Join-Path $repo ".agents/skills/bugfix/SKILL.md"
    if (-not (Test-Path -LiteralPath $managed -PathType Leaf)) {
        Fail-Scenario "arquivo managed da fixture ausente: .agents/skills/bugfix/SKILL.md"
    }
    else {
        $managedBackup = Join-Path $TempRoot "managed-before.bin"
        Copy-Item -LiteralPath $managed -Destination $managedBackup
        $append = [IO.File]::Open($managed, [IO.FileMode]::Append, [IO.FileAccess]::Write)
        try { $append.WriteByte([byte][char]"X") } finally { $append.Dispose() }
        $stateBeforeNegative = Join-Path $TempRoot "state-before-negative.txt"
        Copy-Item -LiteralPath $state -Destination $stateBeforeNegative
        $negative = Invoke-Logged @("-NoProfile", "-File", $updater, "-RepoPath", $repo, "-Check")
        Write-Output $negative.Output
        Write-Output "CA4 byte check_status=$($negative.Code)"
        $negativeConflict = @($negative.Output -split "`r?`n" | Where-Object { $_ -match "^CONFLICT\b" })
        if ($negativeConflict.Count -gt 0) {
            Pass "1 byte alterado em managed continua CONFLICT (exit $($negative.Code))"
        }
        else {
            Fail-Scenario "1 byte alterado nao foi detectado como CONFLICT (exit $($negative.Code))"
        }
        if (Test-SameBytes $state $stateBeforeNegative) {
            Pass "state inalterado no teste negativo de 1 byte"
        }
        else {
            Fail-Scenario "teste negativo de 1 byte alterou o state"
        }
        Copy-Item -LiteralPath $managedBackup -Destination $managed -Force
    }

    $mut = Join-Path $TempRoot "pack-mut"
    New-Item -ItemType Directory -Path (Join-Path $mut "scripts") | Out-Null
    Copy-Item -LiteralPath $updater -Destination (Join-Path $mut "scripts/update-agent-pack.ps1")
    Copy-Item -LiteralPath (Join-Path $Root "scripts/protect-engineering-flow-files.ps1") -Destination (Join-Path $mut "scripts/protect-engineering-flow-files.ps1")
    foreach ($name in @("pack-version.txt", "pack-manifest.txt", "pack-artifacts.txt")) {
        Copy-Item -LiteralPath (Join-Path $Root $name) -Destination (Join-Path $mut $name)
    }
    Copy-Item -LiteralPath (Join-Path $Root "compat") -Destination $mut -Recurse
    Copy-Item -LiteralPath (Join-Path $Root "repo-template") -Destination $mut -Recurse
    $catalogCopy = Join-Path $mut "compat/releases/3.0.0.txt"
    $lines = [IO.File]::ReadAllLines($catalogCopy)
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -and -not $lines[$i].StartsWith("#")) {
            $parts = $lines[$i].Split("|")
            $hash = $parts[2]
            $replacement = if ($hash.EndsWith("0")) { "1" } else { "0" }
            $parts[2] = $hash.Substring(0, 63) + $replacement
            $lines[$i] = ($parts -join "|")
            Write-Output "CA4 hash do catalogo temporario alterado: id=$($parts[0])"
            break
        }
    }
    [IO.File]::WriteAllLines($catalogCopy, $lines, $Utf8NoBom)
    $stateBeforeHash = Join-Path $TempRoot "state-before-hash.txt"
    Copy-Item -LiteralPath $state -Destination $stateBeforeHash
    $mutUpdater = Join-Path $mut "scripts/update-agent-pack.ps1"
    $hashCheck = Invoke-Logged @("-NoProfile", "-File", $mutUpdater, "-RepoPath", $repo, "-Check")
    Write-Output $hashCheck.Output
    Write-Output "CA4 hash check_status=$($hashCheck.Code)"
    if ($hashCheck.Code -ne 0 -and $hashCheck.Output -match "does not match a trusted") {
        Pass "1 hash alterado no catalogo temporario continua nao confiavel (exit $($hashCheck.Code))"
    }
    else {
        Fail-Scenario "1 hash alterado no catalogo temporario nao foi recusado (exit $($hashCheck.Code))"
    }
    if (Test-SameBytes $state $stateBeforeHash) {
        Pass "state inalterado no teste negativo de hash"
    }
    else {
        Fail-Scenario "teste negativo de hash alterou o state"
    }

    $apply = Invoke-Logged @("-NoProfile", "-File", $updater, "-RepoPath", $repo, "-Apply", '-Confirm:$false')
    Write-Output $apply.Output
    Write-Output "CA3 apply_status=$($apply.Code)"
    $appliedText = [IO.File]::ReadAllText($state)
    if ($apply.Code -eq 0 -and $apply.Output -match "applied successfully" -and $appliedText -match "(?m)^version\|$([regex]::Escape($current))$" -and $appliedText -match "(?m)^integration\|grok$") {
        Pass "Apply da arvore atual gravou version|$current e integration|grok"
    }
    else {
        Fail-Scenario "Apply da fixture nao concluiu com version|$current e integration|grok (exit $($apply.Code))"
    }

    $second = Invoke-Logged @("-NoProfile", "-File", $updater, "-RepoPath", $repo, "-Check")
    Write-Output $second.Output
    Write-Output "CA3 second_check_status=$($second.Code)"
    $pending = @($second.Output -split "`r?`n" | Where-Object { $_ -match "^(UPDATE|ADD\w*|CONFLICT\w*|WRITE\w*|REPLACE\w*|RESTORE\w*|RETIRE\w*|BLOCK\w*|ACCEPT\w*)\s" })
    if ($second.Code -eq 0 -and $pending.Count -eq 0) {
        Pass "segundo -Check sem acao pendente"
    }
    else {
        Fail-Scenario "segundo -Check ainda tem acao pendente (exit $($second.Code), pendentes=$($pending.Count))"
        foreach ($line in $pending) { Write-Output "acao pendente: $line" }
    }

    Write-Summary
}
finally {
    if (Test-Path -LiteralPath $Work) {
        Remove-Item -LiteralPath $Work -Recurse -Force
    }
    if ($TempRoot -and (Test-Path -LiteralPath $TempRoot)) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}
