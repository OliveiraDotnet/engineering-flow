[CmdletBinding()]
param([string]$BaselinePackRoot)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PackRoot = Split-Path -Parent $PSScriptRoot
$Inspector = Join-Path $PackRoot 'repo-template/.agents/skills/bootstrap-repo/scripts/inspect-repo.ps1'
$Installer = Join-Path $PSScriptRoot 'install-engineering-flow.ps1'
$Updater = Join-Path $PSScriptRoot 'update-engineering-flow.ps1'
$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ('engineering-flow-tests-' + [Guid]::NewGuid().ToString('N'))
$Utf8 = [Text.UTF8Encoding]::new($false)
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Put([string]$Root,[string]$Path,[string]$Text) {
 $full = Join-Path $Root $Path
 [IO.Directory]::CreateDirectory((Split-Path -Parent $full)) | Out-Null
 [IO.File]::WriteAllText($full,$Text,$Utf8)
}
function New-Repo([string]$Name) {
 $root=Join-Path $TempRoot $Name
 [IO.Directory]::CreateDirectory($root) | Out-Null
 & git -C $root init -q
 Assert ($LASTEXITCODE -eq 0) 'Unable to initialize fixture Git root.'
 return $root
}
function Inspect([string]$Root) { return (& $Inspector -RepoPath $Root -Format json | ConvertFrom-Json) }
try {
 [IO.Directory]::CreateDirectory($TempRoot) | Out-Null
 $empty = New-Repo 'empty'
 $result = Inspect $empty
 Assert ($result.discoveryMode -eq 'empty') 'Empty repo not identified.'
 Assert ($result.optionalProfilesSuggested.Count -eq 0) 'Empty repo selected optional profiles.'
 & $Installer -RepoPath $empty -Integration grok -Profile core -Confirm:$false
 Assert (Test-Path (Join-Path $empty '.grok/skills/new-project/SKILL.md')) 'Empty repo lacks Grok new-project skill.'
 Assert (-not (Test-Path (Join-Path $empty '.codex'))) 'Independent Grok installed Codex.'
 Assert (-not (Test-Path (Join-Path $empty '.agents/skills/mobile-app'))) 'Core installed unrelated mobile.'

 $mixed = New-Repo 'mixed'
 Put $mixed 'web/default.asp' '<% Response.Write "fixture-only" %>'
 Put $mixed 'web/site.css' 'body { color: black; }'
 Put $mixed 'api/Legacy.csproj' '<Project><PropertyGroup><TargetFrameworkVersion>v4.8</TargetFrameworkVersion></PropertyGroup><ItemGroup><PackageReference Include="System.Data.SqlClient" /></ItemGroup></Project>'
 Put $mixed 'ui/package.json' '{"dependencies":{"react":"18.0.0"},"scripts":{"test":"echo synthetic-secret-script-body"}}'
 Put $mixed 'infra/Dockerfile' 'FROM fixture-only'
 Put $mixed 'schema.sql' 'SELECT 1;'
 $out = & $Inspector -RepoPath $mixed -Format json
 $result = $out | ConvertFrom-Json
 Assert ($result.optionalProfilesSuggested -contains 'web' -and $result.optionalProfilesSuggested -contains 'sqlserver') 'Classic ASP/mixed .NET SQL discovery failed.'
 Assert ($result.targetFrameworks -contains 'v4.8') 'Legacy .NET specialization lost.'
 Assert ($result.manifestFiles -contains 'ui/package.json' -and $result.runtimeAndPlatformEvidence -contains 'web/default.asp') 'Mixed metadata missing.'
 Assert (($out -join '') -notmatch 'synthetic-secret-script-body') 'Discovery leaked script body.'
 Assert ($result.optionalProfilesSuggested -notcontains 'mobile' -and $result.optionalProfilesSuggested -notcontains 'quality') 'Mixed web selected unrelated profiles.'
 & $Installer -RepoPath $mixed -Integration codex -Confirm:$false
 Assert (Test-Path (Join-Path $mixed '.agents/skills/web-app/SKILL.md')) 'Classic ASP auto web module missing.'

 $unknown = New-Repo 'unknown'
 Put $unknown 'engine.customlang' 'opaque fixture'
 Put $unknown 'backend/Main.kt' 'class BackendOnly'
 Put $unknown 'cli/main.swift' 'print("fixture-only")'
 Put $unknown 'schema.sql' 'SELECT 1;'
 $result = Inspect $unknown
 Assert ($result.discoveryMode -eq 'existing' -and $result.extensionInventory.PSObject.Properties.Name -contains '.customlang') 'Unknown technology evidence lost.'
 Assert ($result.optionalProfilesSuggested.Count -eq 0) 'Unknown/generic SQL invented provider/profile.'

 $mobile = New-Repo 'mobile'
 Put $mobile 'android/app/AndroidManifest.xml' '<manifest />'
 Put $mobile 'android/app/Main.kt' 'class Main'
 $result = Inspect $mobile
 Assert ($result.optionalProfilesSuggested -contains 'mobile') 'Native mobile not suggested.'
 & $Installer -RepoPath $mobile -Integration grok -Confirm:$false
 Assert (Test-Path (Join-Path $mobile '.grok/skills/mobile-app/SKILL.md')) 'Mobile not installed independently in Grok.'
 Assert (-not (Test-Path (Join-Path $mobile '.agents/skills/web-app'))) 'Native mobile installed unrelated web.'
 $hybrid = New-Repo 'hybrid'
 Put $hybrid 'app/pubspec.yaml' 'name: fixture_only'
 Put $hybrid 'web/index.html' '<html></html>'
 $result = Inspect $hybrid
 Assert ($result.optionalProfilesSuggested -contains 'mobile' -and $result.optionalProfilesSuggested -contains 'web') 'Cross-platform/mixed targets not detected.'

 # Actual 1.7 bytes, recorded against the 1.7 catalog. A subset is durable; full baseline can also be exercised.
 $old = New-Repo 'installed-1.7'
 if ($BaselinePackRoot) {
  Assert ((Get-Content (Join-Path $BaselinePackRoot 'pack-version.txt') -Raw).Trim() -eq '1.7.0') 'Full migration baseline must be actual 1.7.0.'
  & (Join-Path $BaselinePackRoot 'scripts/install-agent-pack.ps1') -RepoPath $old -Profile web,sqlserver -Integration grok -Confirm:$false
 } else {
  $fixture = Join-Path $PackRoot 'tests/fixtures/installed-1.7.0'
  Copy-Item -LiteralPath (Join-Path $fixture 'repo') -Destination (Join-Path $old 'fixture-copy') -Recurse
  Get-ChildItem -LiteralPath (Join-Path $old 'fixture-copy') -Force | Move-Item -Destination $old
  [IO.Directory]::CreateDirectory((Join-Path $old '.agent-pack')) | Out-Null
  Copy-Item -LiteralPath (Join-Path $fixture 'state.txt') -Destination (Join-Path $old '.agent-pack/state.txt')
 }
 $managed = Join-Path $old '.agents/skills/bugfix-dotnet/SKILL.md'
 $guidance = Join-Path $old 'AGENTS.md'
 $memory = Join-Path $old 'docs/ai/runbook.md'
 Add-Content -LiteralPath $managed 'Local recurring rule: preserve me.'
 Add-Content -LiteralPath $guidance 'Local project guidance: preserve me.'
 Put $old 'docs/ai/runbook.md' 'Verified local commands: fixture only.'
 $before = @{}
 foreach ($p in @($managed,$guidance,$memory)) { $before[$p] = (Get-FileHash -LiteralPath $p).Hash }
 & $Updater -RepoPath $old -Check -Confirm:$false
 foreach ($p in $before.Keys) { Assert ((Get-FileHash -LiteralPath $p).Hash -eq $before[$p]) 'Check modified local content.' }
 $blocked = $false
 try { & $Updater -RepoPath $old -Apply -Confirm:$false } catch { $blocked = $_.Exception.Message -match 'conflict' }
 Assert $blocked 'Custom migration did not stop on conflict.'
 foreach ($p in $before.Keys) { Assert ((Get-FileHash -LiteralPath $p).Hash -eq $before[$p]) 'Conflict changed local content.' }
 # Preserve customizations explicitly. The unmodified Grok config can accept the new pack.
 & $Updater -RepoPath $old -Apply -KeepLocal 'guidance.agents','skill.shared.bugfix-dotnet' -AcceptPack 'config.grok.project' -Confirm:$false
 foreach ($p in $before.Keys) { Assert ((Get-FileHash -LiteralPath $p).Hash -eq $before[$p]) 'Migration lost managed/merge/seed customization.' }
 $state = Get-Content (Join-Path $old '.agent-pack/state.txt') -Raw
 Assert ($state -match '(?m)^version\|2\.0\.0$') 'Migration version not advanced.'
 Assert ($state -match '(?m)^integration\|grok$' -and $state -notmatch '(?m)^integration\|codex$') 'Migration changed independent integration.'
 Assert ($state -match '(?m)^profile\|web$' -and $state -notmatch '(?m)^profile\|(mobile|quality)$') 'Migration changed profile selection.'
 Assert (Test-Path (Join-Path $old '.grok/skills/complete-task/SKILL.md')) 'Migration did not add selected core workflow.'
 Assert (-not (Test-Path (Join-Path $old '.grok/skills/mobile-app'))) 'Update auto-installed mobile.'
 Assert ((Get-Content (Join-Path $old '.grok/skills/web-dotnet/SKILL.md') -Raw) -match 'Engineering Flow 2.0 execution gate') 'Unchanged trusted 1.7 managed file did not update.'

 # Static cross-entrypoint approval/evidence checks, not execution of agent behavior.
 $flow = Get-Content (Join-Path $PackRoot 'repo-template/docs/engineering-flow/workflow.md') -Raw
 foreach ($term in @('Ausência de pedido de testes não é autorização automática','não validado','verificado / falhou / pendente / não verificado','observado','Artefato','Mudança material')) { Assert ($flow.Contains($term)) "Missing static contract constraint: $term" }
 foreach ($file in Get-ChildItem (Join-Path $PackRoot 'repo-template/.agents/skills') -Recurse -Filter SKILL.md -File) {
  Assert ((Get-Content -LiteralPath $file.FullName -Raw).Contains('docs/engineering-flow/workflow.md')) "Skill bypasses common contract: $($file.FullName)"
 }
 Write-Host 'Engineering Flow script regressions passed: empty/unknown/classic ASP/mixed/native/hybrid, tool/metadata limits, independent profiles, actual 1.7 bytes, customization/conflict atomicity, migration and static approval/evidence contract. No agent/browser/device behavior claimed.'
} finally {
 $resolved = [IO.Path]::GetFullPath($TempRoot)
 $prefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
 if (-not $resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notlike 'engineering-flow-tests-*') { throw 'Unsafe test cleanup target.' }
 if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
