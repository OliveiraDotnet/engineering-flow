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

    $grokOnly = Join-Path $TempRoot 'grok-only'
    New-Item -ItemType Directory -Path $grokOnly | Out-Null
    & git -C $grokOnly init -q
    & $Installer -RepoPath $grokOnly -Integration grok -Profile web,sqlserver,quality -Confirm:$false
    & $Installer -RepoPath $grokOnly -Confirm:$false
    Assert-True (Test-Path -LiteralPath (Join-Path $grokOnly '.grok/config.toml')) 'Grok-only config missing.'
    Assert-True (Test-Path -LiteralPath (Join-Path $grokOnly '.grok/agents/repo-explorer.md')) 'Grok agent origin missing.'
    Assert-True (Test-Path -LiteralPath (Join-Path $grokOnly '.grok/agents/frontend-web.md')) 'Grok web agent missing.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $grokOnly '.codex'))) 'Grok-only installed Codex agents.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $grokOnly '.claude'))) 'Grok-only installed Claude agents.'
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $grokOnly '.agents') -Recurse -Filter openai.yaml).Count -eq 0) 'Grok-only installed Codex metadata.'
    $grokState = Get-Content -LiteralPath (Join-Path $grokOnly '.agent-pack/state.txt') -Raw
    Assert-True ($grokState -match '(?m)^integration\|grok$' -and $grokState -notmatch '(?m)^integration\|codex$') 'Grok-only state selected Codex.'
    $rejected = $false
    try { & $Installer -RepoPath $grokOnly -Integration codex,grok -Confirm:$false } catch { $rejected = $true }
    Assert-True $rejected 'Installer accepted Codex integration.'

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
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agent-pack\state.txt")) "Installer did not write Agent Pack state."
    $coreState = Get-Content -LiteralPath (Join-Path $Repo ".agent-pack\state.txt") -Raw
    $expectedVersion = (Get-Content -LiteralPath (Join-Path (Split-Path -Parent $ScriptDir) 'pack-version.txt') -Raw).Trim()
    Assert-True ($coreState -match ('(?m)^version\|' + [regex]::Escape($expectedVersion) + '$')) 'Installer state version does not match pack-version.txt.'
    Assert-True ($coreState -match '(?m)^profile\|core$') "Installer state is missing core."
    Assert-True ($coreState -match '(?m)^integration\|grok$') "Default install did not select Grok."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\update-agent-pack\SKILL.md")) "Agent Pack update skill was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".grok\config.toml")) "Grok config was not installed by default."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".grok\agents\repo-explorer.md")) "Grok agent origin was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".grok\agents\implementer.md")) "Grok implementer was not installed."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".codex"))) "Default install created .codex."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo "CLAUDE.md"))) "Default install wrote CLAUDE.md."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".claude"))) "Default install created .claude."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".grok\skills\execute-codex-work-order"))) "Removed execute-codex-work-order was installed."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo "prompts\09-migrate-claude-to-codex-grok.md"))) "Removed migration prompt was installed."

    & $Installer -RepoPath $Repo -Confirm:$false
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo "AGENTS.md.agent-pack.new"))) "Idempotent install created a sidecar."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".grok\config.toml.agent-pack.new"))) "Idempotent Grok install created a sidecar."

    & $Installer -RepoPath $Repo -Profile web,sqlserver,quality -Confirm:$false
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".grok\agents\frontend-web.md")) "Web Grok agent was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\web-dotnet\SKILL.md")) "Web skill was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".grok\skills\web-dotnet\SKILL.md")) "Grok web skill was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".agents\skills\db-change-sqlserver\SKILL.md")) "SQL Server skill was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".grok\agents\database-sqlserver.md")) "SQL Server Grok agent was not installed."
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".grok\agents\security-reviewer.md")) "Quality Grok agent was not installed."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $Repo ".codex"))) "Profiles installed Codex."
    $canonicalBootstrapSkill = Join-Path $Repo ".agents\skills\bootstrap-dotnet-repo\SKILL.md"
    $grokBootstrapSkill = Join-Path $Repo ".grok\skills\bootstrap-dotnet-repo\SKILL.md"
    Assert-True ((Get-FileHash -LiteralPath $canonicalBootstrapSkill -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $grokBootstrapSkill -Algorithm SHA256).Hash) "Grok bootstrap skill diverged from its canonical source."

    Add-Content -LiteralPath (Join-Path $Repo "AGENTS.md") -Value "# local change"
    & $Installer -RepoPath $Repo -Confirm:$false
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo "AGENTS.md.agent-pack.new")) "Conflict sidecar was not created."

    Add-Content -LiteralPath (Join-Path $Repo ".agents\skills\bugfix-dotnet\SKILL.md") -Value "# local customization"
    & $Installer -RepoPath $Repo -Confirm:$false
    & $Installer -RepoPath $Repo -Confirm:$false
    $state = Get-Content -LiteralPath (Join-Path $Repo ".agent-pack\state.txt") -Raw
    Assert-True ($state -match '(?m)^artifact\|[^|]+\|\.agents/skills/bugfix-dotnet/SKILL.md\|[^|]+\|-\|-\|keep-local\|') "Local customization was not recorded as keep-local."
    Assert-True ((Get-Content -LiteralPath (Join-Path $Repo ".agents\skills\bugfix-dotnet\SKILL.md") -Raw) -match 'local customization') "Local customization was overwritten."

    & $Installer -RepoPath $Repo -Force -Confirm:$false
    Assert-True ((Get-Content -LiteralPath (Join-Path $Repo "AGENTS.md") -Raw) -eq (Get-Content -LiteralPath (Join-Path $Template "AGENTS.md") -Raw)) "Force install did not replace modified AGENTS.md."
    Assert-True ((Get-ChildItem -LiteralPath $Repo -Filter "AGENTS.md.agent-pack.backup-*" -File).Count -gt 0) "Force install did not preserve a backup."

    Add-Content -LiteralPath (Join-Path $Repo ".grok\config.toml") -Value "# local Grok change"
    & $Installer -RepoPath $Repo -Confirm:$false
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo ".grok\config.toml.agent-pack.new")) "Grok conflict sidecar was not created."

    & $Installer -RepoPath $Repo -Force -Confirm:$false
    Assert-True ((Get-Content -LiteralPath (Join-Path $Repo ".grok\config.toml") -Raw) -eq (Get-Content -LiteralPath (Join-Path $Template ".grok\config.toml") -Raw)) "Force install did not replace modified Grok config."

    $previousGrokHome = $env:GROK_HOME
    try {
        $env:GROK_HOME = Join-Path $TempRoot "custom-grok-home"
        & $Installer -RepoPath $Repo -InstallGlobal -Confirm:$false
        Assert-True (Test-Path -LiteralPath (Join-Path $env:GROK_HOME "AGENTS.md")) "InstallGlobal did not honor GROK_HOME."
    }
    finally {
        $env:GROK_HOME = $previousGrokHome
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
    Assert-True (Test-Path -LiteralPath (Join-Path $firstRepo ".grok\agents\frontend-web.md")) "Detected web profile was not installed into the web Git root."
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $secondRepo ".grok\agents\frontend-web.md"))) "Web profile was installed into a repository without web evidence."

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
