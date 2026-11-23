#Requires -Version 7
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $PSCommandPath
$Installer = Join-Path $ScriptDir "install-agent-pack.ps1"
$Template = Join-Path (Split-Path -Parent $ScriptDir) "repo-template"
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("dotnet-agents-pack-" + [Guid]::NewGuid().ToString("N"))
$Repo = Join-Path $TempRoot "target"

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

try {
    New-Item -ItemType Directory -Force -Path $Repo | Out-Null
    & git -C $Repo init -q
    Assert-True ($LASTEXITCODE -eq 0) "Unable to initialize temporary Git repository."

    & $Installer -RepoPath $Repo -DryRun -Confirm:$false
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo "AGENTS.md"))) "Dry-run wrote AGENTS.md."
    & $Installer -RepoPath $Repo -WhatIf -Confirm:$false
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo '.agent-pack'))) 'WhatIf created installation state or temporary files.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo '.agents'))) 'WhatIf created skills.'

    $agnosticRepo = Join-Path $TempRoot 'agnostic-only'
    New-Item -ItemType Directory -Path $agnosticRepo | Out-Null
    & git -C $agnosticRepo init -q
    & $Installer -RepoPath $agnosticRepo -Profile web,sqlserver,quality -Confirm:$false
    & $Installer -RepoPath $agnosticRepo -Confirm:$false
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $agnosticRepo '.grok'))) 'Tool-agnostic install created .grok directory.'
    Assert-True (Test-Path -LiteralPath (Join-Path $agnosticRepo '.agents/agents/repo-explorer.md')) 'Specialist agent missing in .agents/agents.'
    Assert-True (Test-Path -LiteralPath (Join-Path $agnosticRepo '.agents/agents/frontend-web.md')) 'Web specialist agent missing in .agents/agents.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $agnosticRepo '.codex'))) 'Tool-agnostic install created .codex.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $agnosticRepo '.claude'))) 'Tool-agnostic install created .claude.'
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $agnosticRepo '.agents') -Recurse -Filter openai.yaml).Count -eq 0) 'Orphan openai.yaml metadata installed.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $agnosticRepo '.agent-pack/state.txt'))) 'Clean install created state.txt.'
    Assert-True (Test-Path -LiteralPath (Join-Path $agnosticRepo '.agents/skills/harness-cycle/SKILL.md')) 'Harness-cycle skill missing.'
    Assert-True (Test-Path -LiteralPath (Join-Path $agnosticRepo '.agents/skills/delegate-to-harness/SKILL.md')) 'Agnostic delegate-to-harness skill missing.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $agnosticRepo '.agents/skills/delegate-to-grok-build'))) 'Removed delegate-to-grok-build was installed.'
    $rejected = $false
    try { & $Installer -RepoPath $agnosticRepo -Integration codex,grok -Confirm:$false } catch { $rejected = $true }
    Assert-True $rejected 'Installer accepted vendor integration.'

    foreach ($linkedRelative in @('.agents', '.agent-pack', 'AGENTS.md.agent-pack.new')) {
        $linkedRepo = Join-Path $TempRoot ('linked-' + [Guid]::NewGuid().ToString('N'))
        $outside = Join-Path $TempRoot ('outside-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $linkedRepo, $outside | Out-Null
        & git -C $linkedRepo init -q
        $linkPath = Join-Path $linkedRepo $linkedRelative
        $linkType = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $linkType -Path $linkPath -Target $outside | Out-Null
        try {
            $linkRejected = $false
            try { & $Installer -RepoPath $linkedRepo -Profile core -Confirm:$false } catch { $linkRejected = $_.Exception.Message -match 'Linked installation path' }
            Assert-True $linkRejected "Installer accepted linked path $linkedRelative."
            Assert-True (@(Get-ChildItem -LiteralPath $outside -Force).Count -eq 0) 'Installer wrote through a linked path.'
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $linkedRepo 'AGENTS.md'))) 'Link validation occurred after writes.'
        }
        finally { [IO.Directory]::Delete($linkPath) }
    }

    & $Installer -RepoPath $Repo -Confirm:$false
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo "AGENTS.md")) "Core AGENTS.md was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\bootstrap-dotnet-repo\SKILL.md")) "Bootstrap skill was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\agents-md-generator\references\agents-md-checklist.md")) "AGENTS.md generator skill was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\dotnet-xunit-tests\references\xunit-test-checklist.md")) "xUnit test skill was not installed."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\update-engineering-flow\SKILL.md"))) "Removed update-engineering-flow skill was installed."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".agent-pack\state.txt"))) "Clean install wrote state.txt."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\harness-cycle\SKILL.md")) "Harness-cycle skill was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo "prompts\12-implementor-harness.md")) "Implementor harness prompt was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo "prompts\13-tester-harness.md")) "Tester harness prompt was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\harness-cycle\scripts\supervise-harness.ps1")) "Harness supervisor was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\harness-cycle\scripts\run-implementor.ps1")) "Harness implementor runner was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\update-agent-pack\SKILL.md")) "Agent Pack update skill was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\agents\repo-explorer.md")) "Specialist agent repo-explorer was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\agents\implementer.md")) "Specialist agent implementer was not installed."
    foreach ($toolRel in @(
        '.agents\tools\verify-envelope.ps1',
        '.agents\tools\verify-envelope.sh',
        '.agents\tools\session-state.ps1',
        '.agents\tools\session-state.sh',
        '.agents\tools\task-lock.ps1',
        '.agents\tools\task-lock.sh'
    )) {
        Assert-True (Test-Path -LiteralPath (Join-Path $Repo $toolRel) -PathType Leaf) "Operational tool was not installed: $toolRel"
    }
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo "tools"))) "Installer should not pollute project root tools/ directory."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".grok"))) "Default install created .grok."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".codex"))) "Default install created .codex."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo "CLAUDE.md"))) "Default install wrote CLAUDE.md."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".claude"))) "Default install created .claude."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo "prompts\09-migrate-claude-to-codex-grok.md"))) "Removed migration prompt was installed."

    & $Installer -RepoPath $Repo -Confirm:$false
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo "AGENTS.md.agent-pack.new"))) "Idempotent install created a sidecar."

    & $Installer -RepoPath $Repo -Profile web,sqlserver,quality -Confirm:$false
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\agents\frontend-web.md")) "Web specialist agent was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\web-dotnet\SKILL.md")) "Web skill was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\db-change-sqlserver\SKILL.md")) "SQL Server skill was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\agents\database-sqlserver.md")) "SQL Server specialist agent was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\agents\security-reviewer.md")) "Quality specialist agent was not installed."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".codex"))) "Profiles installed Codex."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".grok"))) "Profiles created .grok."

    Add-Content -LiteralPath (Join-Path $Repo "AGENTS.md") -Value "# local change"
    & $Installer -RepoPath $Repo -Confirm:$false
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo "AGENTS.md.agent-pack.new")) "Conflict sidecar was not created."

    Add-Content -LiteralPath (Join-Path $Repo ".agents\skills\bugfix-dotnet\SKILL.md") -Value "# local customization"
    & $Installer -RepoPath $Repo -Confirm:$false
    & $Installer -RepoPath $Repo -Confirm:$false
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".agent-pack\state.txt"))) "Clean install wrote state.txt on local customization."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\bugfix-dotnet\SKILL.md.agent-pack.new")) "Local customization sidecar was not created."
    Assert-True ((Get-Content -LiteralPath (Join-Path $Repo ".agents\skills\bugfix-dotnet\SKILL.md") -Raw) -match 'local customization') "Local customization was overwritten."

    # I5: --force on AGENTS.md merges managed blocks, preserves outside content, removes sidecar, keeps backup
    & $Installer -RepoPath $Repo -Force -Confirm:$false
    Assert-True ($LASTEXITCODE -eq 0) "Force merge install failed."
    Assert-True ((Get-Content -LiteralPath (Join-Path $Repo "AGENTS.md") -Raw) -match '# local change') "Force install overwrote content outside managed blocks."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo "AGENTS.md.agent-pack.new"))) "Force merge left sidecar behind."
    Assert-True ((Get-ChildItem -LiteralPath $Repo -Filter "AGENTS.md.agent-pack.backup-*" -File).Count -gt 0) "Force install did not preserve a backup."

    $previousSpecGuardHome = $env:SPECGUARD_HOME
    try {
        $env:SPECGUARD_HOME = Join-Path $TempRoot "custom-specguard-home"
        & $Installer -RepoPath $Repo -InstallGlobal -Confirm:$false
        Assert-True (Test-Path -LiteralPath (Join-Path $env:SPECGUARD_HOME "AGENTS.md")) "InstallGlobal did not honor SPECGUARD_HOME."
    }
    finally {
        $env:SPECGUARD_HOME = $previousSpecGuardHome
    }

    $workspace = Join-Path $TempRoot "multi-root"
    $firstRepo = Join-Path $workspace "app"
    $secondRepo = Join-Path $workspace "api"
    New-Item -ItemType Directory -Force -Path $firstRepo, $secondRepo | Out-Null
    & git -C $firstRepo init -q
    & git -C $secondRepo init -q
    New-Item -ItemType Directory -Force -Path (Join-Path $firstRepo "Pages") | Out-Null
    Set-Content -LiteralPath (Join-Path $firstRepo "Pages\Index.cshtml") -Value "@page"
    & $Installer -RepoPath $workspace -DiscoverOnly -Confirm:$false
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $firstRepo "AGENTS.md"))) "Discover-only wrote files into a child repository."
    & $Installer -RepoPath $workspace -Confirm:$false
    Assert-True (Test-Path -LiteralPath (Join-Path $firstRepo "AGENTS.md")) "Workspace install did not reach the first Git root."
    Assert-True (Test-Path -LiteralPath (Join-Path $secondRepo "AGENTS.md")) "Workspace install did not reach the second Git root."
    Assert-True (Test-Path -LiteralPath (Join-Path $firstRepo ".agents\agents\frontend-web.md")) "Detected web profile was not installed into the web Git root."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $secondRepo ".agents\agents\frontend-web.md"))) "Web profile was installed into a repository without web evidence."

    $Pwsh = (Get-Process -Id $PID).Path
    $Utf8NoBom = [Text.UTF8Encoding]::new($false)
    $Utf8WithBom = [Text.UTF8Encoding]::new($true)

    function Invoke-InstallerProcess {
        param([string]$ScriptPath, [string[]]$Arguments)
        $psi = [System.Diagnostics.ProcessStartInfo]::new($Pwsh)
        $psi.ArgumentList.Add('-NoProfile')
        $psi.ArgumentList.Add('-File')
        $psi.ArgumentList.Add($ScriptPath)
        foreach ($arg in $Arguments) { $psi.ArgumentList.Add($arg) }
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
        $proc.WaitForExit()
        return [pscustomobject]@{
            Exit   = $proc.ExitCode
            Stdout = $stdoutTask.Result
            Stderr = $stderrTask.Result
        }
    }

    function Get-OutsideManagedHash {
        param([string]$Path)
        $bytes = [IO.File]::ReadAllBytes($Path)
        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $offset = if ($hasBom) { 3 } else { 0 }
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes, $offset, $bytes.Length - $offset)
        $stripped = [regex]::Replace($text, '(?s)<!--\s*ef:managed:begin:[A-Za-z0-9_-]+\s*-->.*?<!--\s*ef:managed:end:[A-Za-z0-9_-]+\s*-->', '')
        $outBytes = $Utf8NoBom.GetBytes($stripped)
        $prefix = if ($hasBom) { [byte[]]@(0xEF, 0xBB, 0xBF) } else { [byte[]]@() }
        $combined = $prefix + $outBytes
        return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($combined))
    }

    # I5-a: without -Force, AGENTS.md hash stays identical and sidecar is created
    $repoI5a = Join-Path $TempRoot 'repo-i5a'
    New-Item -ItemType Directory -Force -Path $repoI5a | Out-Null
    & git -C $repoI5a init -q
    & $Installer -RepoPath $repoI5a -Confirm:$false | Out-Null
    [IO.File]::AppendAllText((Join-Path $repoI5a 'AGENTS.md'), "`n- Sentinel I5-a: keep untouched`n", $Utf8NoBom)
    $hashI5aBefore = (Get-FileHash -LiteralPath (Join-Path $repoI5a 'AGENTS.md') -Algorithm SHA256).Hash
    & $Installer -RepoPath $repoI5a -Confirm:$false | Out-Null
    Assert-True ((Get-FileHash -LiteralPath (Join-Path $repoI5a 'AGENTS.md') -Algorithm SHA256).Hash -eq $hashI5aBefore) 'I5-a: AGENTS.md changed without -Force'
    Assert-True (Test-Path -LiteralPath (Join-Path $repoI5a 'AGENTS.md.agent-pack.new')) 'I5-a: sidecar missing'

    # I5-b: -Force with managed markers preserves outside bytes (BOM/CRLF/EOF) and updates blocks
    $packCopy = Join-Path $TempRoot 'pack-copy'
    New-Item -ItemType Directory -Force -Path $packCopy | Out-Null
    $packRoot = Split-Path -Parent $ScriptDir
    foreach ($item in Get-ChildItem -LiteralPath $packRoot -Force) {
        if ($item.Name -eq '.git') { continue }
        Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $packCopy $item.Name) -Recurse -Force
    }
    $copyInstaller = Join-Path $packCopy 'scripts/install-agent-pack.ps1'
    $repoI5b = Join-Path $TempRoot 'repo-i5b'
    New-Item -ItemType Directory -Force -Path $repoI5b | Out-Null
    & git -C $repoI5b init -q
    $resInit = Invoke-InstallerProcess -ScriptPath $copyInstaller -Arguments @('-RepoPath', $repoI5b, '-Confirm:$false')
    Assert-True ($resInit.Exit -eq 0) "I5-b: initial install failed: $($resInit.Stderr)"

    $agentsI5b = Join-Path $repoI5b 'AGENTS.md'
    $rawI5b = [IO.File]::ReadAllText($agentsI5b, $Utf8NoBom)
    $rawI5b = $rawI5b -replace '\r?\n', "`r`n"
    $rawI5b = $rawI5b.Replace("## Convenções do projeto`r`n", "## Convenções do projeto`r`n- Sentinel A: projeto preservado`r`n")
    $rawI5b = $rawI5b.Replace("<!-- ef:managed:begin:contract -->`r`n", "<!-- ef:managed:begin:contract -->`r`nSentinel B: old managed line`r`n")
    $rawI5b = $rawI5b.TrimEnd("`r", "`n")
    [IO.File]::WriteAllText($agentsI5b, $rawI5b, $Utf8WithBom)

    $copyTemplateAgents = Join-Path $packCopy 'repo-template/AGENTS.md'
    $tmplRaw = [IO.File]::ReadAllText($copyTemplateAgents, $Utf8NoBom)
    $tmplRaw = $tmplRaw.Replace("<!-- ef:managed:end:contract -->", "Sentinel C: new managed line`n<!-- ef:managed:end:contract -->")
    [IO.File]::WriteAllText($copyTemplateAgents, $tmplRaw, $Utf8NoBom)

    $outsideHashBefore = Get-OutsideManagedHash -Path $agentsI5b
    $fullHashBefore = (Get-FileHash -LiteralPath $agentsI5b -Algorithm SHA256).Hash

    $dryI5b = Invoke-InstallerProcess -ScriptPath $copyInstaller -Arguments @('-RepoPath', $repoI5b, '-Force', '-DryRun', '-Confirm:$false')
    Assert-True ($dryI5b.Exit -eq 0) "I5-b: dry-run failed: $($dryI5b.Stderr)"
    Assert-True ($dryI5b.Stdout -match 'WOULD-MERGE') 'I5-b: dry-run missing WOULD-MERGE'
    Assert-True ((Get-FileHash -LiteralPath $agentsI5b -Algorithm SHA256).Hash -eq $fullHashBefore) 'I5-b: dry-run modified AGENTS.md'

    $mergeRes = Invoke-InstallerProcess -ScriptPath $copyInstaller -Arguments @('-RepoPath', $repoI5b, '-Force', '-Confirm:$false')
    Assert-True ($mergeRes.Exit -eq 0) "I5-b: force merge failed: $($mergeRes.Stderr)"
    Assert-True ($mergeRes.Stdout -match 'MERGE AGENTS\.md \(blocks: header,contract,memory\)') 'I5-b: missing MERGE summary'
    $mergedText = [IO.File]::ReadAllText($agentsI5b)
    Assert-True ($mergedText.Contains('Sentinel A: projeto preservado')) 'I5-b: Sentinel A lost'
    Assert-True (-not $mergedText.Contains('Sentinel B: old managed line')) 'I5-b: Sentinel B still present'
    Assert-True ($mergedText.Contains('Sentinel C: new managed line')) 'I5-b: Sentinel C missing'
    Assert-True ((Get-OutsideManagedHash -Path $agentsI5b) -eq $outsideHashBefore) 'I5-b: bytes outside managed blocks changed'
    Assert-True ((Get-ChildItem -LiteralPath $repoI5b -Filter 'AGENTS.md.agent-pack.backup-*' -File).Count -gt 0) 'I5-b: backup missing'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repoI5b 'AGENTS.md.agent-pack.new'))) 'I5-b: sidecar was not removed'

    # I5-c: -Force on AGENTS.md without markers keeps file, keeps sidecar, warns, exits 7
    $repoI5c = Join-Path $TempRoot 'repo-i5c'
    New-Item -ItemType Directory -Force -Path $repoI5c | Out-Null
    & git -C $repoI5c init -q
    $agentsI5c = Join-Path $repoI5c 'AGENTS.md'
    [IO.File]::WriteAllText($agentsI5c, "# Freeform AGENTS`nProject notes here.`n", $Utf8NoBom)
    $hashI5cBefore = (Get-FileHash -LiteralPath $agentsI5c -Algorithm SHA256).Hash

    $dryI5c = Invoke-InstallerProcess -ScriptPath $Installer -Arguments @('-RepoPath', $repoI5c, '-Force', '-DryRun', '-Confirm:$false')
    Assert-True ($dryI5c.Stdout -match 'WOULD-SKIP-MERGE') 'I5-c: dry-run missing WOULD-SKIP-MERGE'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repoI5c 'AGENTS.md.agent-pack.new'))) 'I5-c: dry-run wrote sidecar'

    $resI5c = Invoke-InstallerProcess -ScriptPath $Installer -Arguments @('-RepoPath', $repoI5c, '-Force', '-Confirm:$false')
    Assert-True ($resI5c.Exit -eq 7) "I5-c: expected exit 7, got $($resI5c.Exit)"
    Assert-True ($resI5c.Stderr -match 'no ef:managed markers') "I5-c: missing warning message: $($resI5c.Stderr)"
    Assert-True ((Get-FileHash -LiteralPath $agentsI5c -Algorithm SHA256).Hash -eq $hashI5cBefore) 'I5-c: AGENTS.md modified'
    Assert-True (Test-Path -LiteralPath (Join-Path $repoI5c 'AGENTS.md.agent-pack.new')) 'I5-c: sidecar missing'
    Assert-True (Test-Path -LiteralPath (Join-Path $repoI5c '.agents/skills/harness-cycle/SKILL.md')) 'I5-c: rest of install did not complete'

    # I5-d: -Force on AGENTS.md with malformed markers exits 7
    foreach ($badKind in @('dup', 'unclosed')) {
        $repoI5d = Join-Path $TempRoot "repo-i5d-$badKind"
        New-Item -ItemType Directory -Force -Path $repoI5d | Out-Null
        & git -C $repoI5d init -q
        $agentsI5d = Join-Path $repoI5d 'AGENTS.md'
        $badContent = if ($badKind -eq 'dup') {
            "<!-- ef:managed:begin:header -->`na`n<!-- ef:managed:end:header -->`n<!-- ef:managed:begin:header -->`nb`n<!-- ef:managed:end:header -->`n"
        }
        else {
            "<!-- ef:managed:begin:header -->`na`n"
        }
        [IO.File]::WriteAllText($agentsI5d, $badContent, $Utf8NoBom)
        $hashI5dBefore = (Get-FileHash -LiteralPath $agentsI5d -Algorithm SHA256).Hash
        $resI5d = Invoke-InstallerProcess -ScriptPath $Installer -Arguments @('-RepoPath', $repoI5d, '-Force', '-Confirm:$false')
        Assert-True ($resI5d.Exit -eq 7) "I5-d ($badKind): expected exit 7, got $($resI5d.Exit)"
        Assert-True ($resI5d.Stderr -match 'malformed ef:managed markers') "I5-d ($badKind): missing malformed warning"
        Assert-True ((Get-FileHash -LiteralPath $agentsI5d -Algorithm SHA256).Hash -eq $hashI5dBefore) "I5-d ($badKind): AGENTS.md modified"
        Assert-True (Test-Path -LiteralPath (Join-Path $repoI5d 'AGENTS.md.agent-pack.new')) "I5-d ($badKind): sidecar missing"
    }

    # I6-a & I6-b: EF 3.0 .gitignore ignoring AGENTS.md, with BOM+CRLF
    $repoI6 = Join-Path $TempRoot 'repo-i6'
    New-Item -ItemType Directory -Force -Path $repoI6 | Out-Null
    & git -C $repoI6 init -q
    $giI6 = Join-Path $repoI6 '.gitignore'
    [IO.File]::WriteAllText($giI6, "AGENTS.md`r`nbin/`r`n*.user`r`n", $Utf8WithBom)
    $prefixBytes = [IO.File]::ReadAllBytes($giI6)

    $resI6 = Invoke-InstallerProcess -ScriptPath $Installer -Arguments @('-RepoPath', $repoI6, '-Confirm:$false')
    Assert-True ($resI6.Exit -eq 0) "I6-a: install failed: $($resI6.Stderr)"
    Assert-True ($resI6.Stdout -match 'UNIGNORE') 'I6-a: stdout missing UNIGNORE'
    & git -C $repoI6 check-ignore -q -- AGENTS.md
    Assert-True ($LASTEXITCODE -eq 1) 'I6-a: AGENTS.md still ignored'
    & git -C $repoI6 check-ignore -q -- bin/x
    Assert-True ($LASTEXITCODE -eq 0) 'I6-a: bin/x no longer ignored'
    & git -C $repoI6 check-ignore -q -- foo.user
    Assert-True ($LASTEXITCODE -eq 0) 'I6-a: foo.user no longer ignored'
    $afterBytesI6 = [IO.File]::ReadAllBytes($giI6)
    Assert-True ([Convert]::ToBase64String($prefixBytes) -eq [Convert]::ToBase64String($afterBytesI6[0..($prefixBytes.Length - 1)])) 'I6-a: original .gitignore bytes modified'
    $statusI6 = (& git -C $repoI6 status --porcelain) -join "`n"
    Assert-True ($statusI6 -match '(?m)^\?\? AGENTS\.md$') 'I6-a: AGENTS.md not visible in git status'

    # I6-b: idempotent reinstall
    $giHashI6 = (Get-FileHash -LiteralPath $giI6 -Algorithm SHA256).Hash
    $resI6b = Invoke-InstallerProcess -ScriptPath $Installer -Arguments @('-RepoPath', $repoI6, '-Confirm:$false')
    Assert-True ($resI6b.Exit -eq 0) "I6-b: reinstall failed: $($resI6b.Stderr)"
    Assert-True ((Get-FileHash -LiteralPath $giI6 -Algorithm SHA256).Hash -eq $giHashI6) 'I6-b: .gitignore changed on second install'

    # I6-c: -DryRun does not modify .gitignore and prints WOULD-UNIGNORE
    $repoI6c = Join-Path $TempRoot 'repo-i6c'
    New-Item -ItemType Directory -Force -Path $repoI6c | Out-Null
    & git -C $repoI6c init -q
    $giI6c = Join-Path $repoI6c '.gitignore'
    [IO.File]::WriteAllText($giI6c, "AGENTS.md`n", $Utf8NoBom)
    $giHashI6c = (Get-FileHash -LiteralPath $giI6c -Algorithm SHA256).Hash
    $resI6c = Invoke-InstallerProcess -ScriptPath $Installer -Arguments @('-RepoPath', $repoI6c, '-DryRun', '-Confirm:$false')
    Assert-True ($resI6c.Exit -eq 0) 'I6-c: dry-run failed'
    Assert-True ($resI6c.Stdout -match 'WOULD-UNIGNORE') 'I6-c: missing WOULD-UNIGNORE'
    Assert-True ((Get-FileHash -LiteralPath $giI6c -Algorithm SHA256).Hash -eq $giHashI6c) 'I6-c: dry-run modified .gitignore'

    # I6-d: repo without AGENTS.md ignore rule has no !AGENTS.md
    $repoGiLines = Get-Content -LiteralPath (Join-Path $Repo '.gitignore')
    Assert-True ('!AGENTS.md' -notin $repoGiLines) 'I6-d: !AGENTS.md added unexpectedly'

    # I6 exit 5: AGENTS.md still ignored after appending !AGENTS.md
    $repoI6Fail = Join-Path $TempRoot 'repo-i6-fail'
    New-Item -ItemType Directory -Force -Path $repoI6Fail | Out-Null
    & git -C $repoI6Fail init -q
    [IO.File]::WriteAllText((Join-Path $repoI6Fail '.gitignore'), "AGENTS.md`n", $Utf8NoBom)
    $shimDir = Join-Path $TempRoot 'shim-i6'
    New-Item -ItemType Directory -Force -Path $shimDir | Out-Null
    $realGit = (Get-Command git).Source
    if ($IsWindows) {
        $shimCmd = "@echo off`r`nsetlocal enabledelayedexpansion`r`nset `"HAS_CI=0`"`r`nset `"HAS_V=0`"`r`nfor %%A in (%*) do (`r`n  if `"%%~A`"==`"check-ignore`" set `"HAS_CI=1`"`r`n  if `"%%~A`"==`"-v`" set `"HAS_V=1`"`r`n)`r`nif `"!HAS_CI!`"==`"1`" (`r`n  if `"!HAS_V!`"==`"1`" echo .git/info/exclude:1:AGENTS.md	AGENTS.md`r`n  exit /b 0`r`n)`r`n`"$realGit`" %*`r`n"
        [IO.File]::WriteAllText((Join-Path $shimDir 'git.cmd'), $shimCmd, $Utf8NoBom)
    }
    else {
        $shimScript = "#!/usr/bin/env bash`nfor arg in `"`$@`"; do`n  if [ `"`$arg`" = `"check-ignore`" ]; then`n    for a in `"`$@`"; do`n      if [ `"`$a`" = `"-v`" ]; then`n        printf '.git/info/exclude:1:AGENTS.md\tAGENTS.md\n'`n        exit 0`n      fi`n    done`n    exit 0`n  fi`ndone`nexec `"$realGit`" `"`$@`"`n"
        $shimGitPath = Join-Path $shimDir 'git'
        [IO.File]::WriteAllText($shimGitPath, $shimScript, $Utf8NoBom)
        & chmod +x $shimGitPath
    }
    $prevPath = $env:PATH
    try {
        $env:PATH = "$shimDir$([IO.Path]::PathSeparator)$prevPath"
        $resI6Fail = Invoke-InstallerProcess -ScriptPath $Installer -Arguments @('-RepoPath', $repoI6Fail, '-Confirm:$false')
    }
    finally {
        $env:PATH = $prevPath
    }
    Assert-True ($resI6Fail.Exit -eq 5) "I6-fail: expected exit 5, got $($resI6Fail.Exit)"
    Assert-True ($resI6Fail.Stderr -match 'AGENTS\.md is still ignored after appending !AGENTS\.md') 'I6-fail: missing error message'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repoI6Fail '.agents'))) 'I6-fail: installer copied files despite preflight failure'

    # I7-a & I7-b: .ai-memory.toml is ignored and reinstall is idempotent
    & git -C $Repo check-ignore -q -- .ai-memory.toml
    Assert-True ($LASTEXITCODE -eq 0) 'I7-a: .ai-memory.toml is not ignored'
    $repoGiRaw = Get-Content -LiteralPath (Join-Path $Repo '.gitignore') -Raw
    Assert-True ($repoGiRaw.Contains('# Engineering Flow: clean install; only AGENTS.md stays versionable.')) 'I7: marker comment missing or has version'
    $giHashI7 = (Get-FileHash -LiteralPath (Join-Path $Repo '.gitignore') -Algorithm SHA256).Hash
    & $Installer -RepoPath $Repo -Confirm:$false | Out-Null
    Assert-True ((Get-FileHash -LiteralPath (Join-Path $Repo '.gitignore') -Algorithm SHA256).Hash -eq $giHashI7) 'I7-b: .gitignore changed on reinstall'

    Write-Host "Installer smoke test passed."
}
finally {
    if (Test-Path -LiteralPath $TempRoot) {
        $resolvedTestRoot = [IO.Path]::GetFullPath($TempRoot)
        $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $resolvedTestRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolvedTestRoot) -notlike 'dotnet-agents-pack-*') { throw 'Unsafe test cleanup path.' }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
