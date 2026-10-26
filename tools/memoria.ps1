#Requires -Version 7
# mem — memória local (engineering-flow 3.1). Sem Git e sem busca semântica.
# Versionamento em Git previsto para a 3.2. A raiz vem de maquinas.conf (EF_MAQUINA).
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

$ScriptDir = Split-Path -Parent $PSCommandPath
$PackRoot = (Resolve-Path -LiteralPath (Join-Path $ScriptDir '..')).Path
$Template = Join-Path $PackRoot 'memory-template'
$Utf8 = [System.Text.UTF8Encoding]::new($false)
$script:RaizRepos = ''
$script:MemDir = ''
$script:Prefixo = ''
$script:MemSistema = ''

function Write-Out([string]$Text) { [Console]::Out.WriteLine($Text) }
function Write-ErrLine([string]$Text) { [Console]::Error.WriteLine($Text) }
function Die([string]$Message) { Write-ErrLine "mem: $Message"; exit 1 }

function Show-Usage {
  Write-Out @'
uso: mem <comando> [args]
comandos: init, novo, index, find, grep, show, gatilho, pacote, pendentes, dupes, lint
EF_MAQUINA escolhe o bloco. EF_MAQUINAS_CONF aponta o arquivo (padrão: config/maquinas.conf).
'@
}

function Get-Trim([string]$Value) {
  if ($null -eq $Value) { return '' }
  return $Value.Trim()
}

function Get-TextLines([string]$Path) {
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -eq 0) { return @() }
  $text = $Utf8.GetString($bytes) -replace "`r`n", "`n" -replace "`r", "`n"
  if ($text.EndsWith("`n")) { $text = $text.Substring(0, $text.Length - 1) }
  if ($text.Length -eq 0) { return @() }
  return @($text.Split("`n"))
}

function Write-Utf8Lf([string]$Path, [string]$Text) {
  if (-not $Text.EndsWith("`n")) { $Text += "`n" }
  $parent = Split-Path -Parent $Path
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Text, $Utf8)
}

function ConvertTo-AsciiFold([string]$Value) {
  if ([string]::IsNullOrEmpty($Value)) { return '' }
  $iconv = Get-Command iconv -ErrorAction SilentlyContinue
  if (-not $iconv) { return $Value }
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $iconv.Source
  $psi.Arguments = '-f UTF-8 -t ASCII//TRANSLIT'
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $proc = $null
  try {
    $proc = [System.Diagnostics.Process]::Start($psi)
    $bytes = $Utf8.GetBytes($Value)
    $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $proc.StandardInput.Close()
    $out = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0 -or [string]::IsNullOrEmpty($out)) { return $Value }
    return $out.TrimEnd("`r", "`n")
  } catch {
    return $Value
  } finally {
    if ($proc) { $proc.Dispose() }
  }
}

function Import-Maquina {
  $conf = if ($env:EF_MAQUINAS_CONF) { $env:EF_MAQUINAS_CONF } else { Join-Path $PackRoot 'config/maquinas.conf' }
  if (-not (Test-Path -LiteralPath $conf -PathType Leaf)) {
    Die "maquinas.conf ausente (${conf}). Copie config/maquinas.conf.example para config/maquinas.conf. Nenhum caminho foi assumido."
  }
  if ([string]::IsNullOrEmpty($env:EF_MAQUINA)) {
    Die 'EF_MAQUINA ausente. Defina EF_MAQUINA com o bloco de maquinas.conf. Sem bloco, o mem não escolhe máquina.'
  }
  $section = ''
  $blocks = ''
  $raiz = ''
  foreach ($raw in (Get-TextLines $conf)) {
    $line = Get-Trim $raw
    if ($line.Length -eq 0 -or $line.StartsWith('#')) { continue }
    $sec = [regex]::Match($line, '^\[([A-Za-z0-9_-]+)\]$')
    if ($sec.Success) {
      $section = $sec.Groups[1].Value
      $blocks += "$section "
      continue
    }
    if ($section -ne $env:EF_MAQUINA) { continue }
    $kv = [regex]::Match($line, '^([A-Za-z0-9_]+)\s*[:=]\s*(.*)$')
    if (-not $kv.Success) { continue }
    $key = $kv.Groups[1].Value
    $val = Get-Trim $kv.Groups[2].Value
    if ($val.Length -ge 2) {
      $q = $val.Substring(0, 1)
      if (($q -eq '"' -or $q -eq "'") -and $val.EndsWith($q)) { $val = $val.Substring(1, $val.Length - 2) }
    }
    if ($key -eq 'raiz_repos') { $raiz = $val }
  }
  if ([string]::IsNullOrEmpty($raiz)) {
    if ((" $blocks").Contains(" $($env:EF_MAQUINA) ")) {
      Die "O bloco [$($env:EF_MAQUINA)] não define raiz_repos."
    }
    $shown = if ($blocks) { $blocks } else { 'nenhum' }
    Die "EF_MAQUINA='$($env:EF_MAQUINA)' não é um bloco de maquinas.conf. Blocos: ${shown}."
  }
  if ($raiz.Contains("`n") -or $raiz.Contains('..')) { Die "raiz_repos inválida no bloco [$($env:EF_MAQUINA)]." }
  $script:RaizRepos = $raiz
}

function Assert-Slug([string]$Value) {
  if ($Value -notmatch '^[a-z][a-z0-9-]{0,40}$') { Die 'sistema inválido: use um slug [a-z0-9-].' }
}
function Assert-Prefix([string]$Value) {
  if ($Value -notmatch '^[A-Z][A-Z0-9]{1,3}$') { Die 'prefixo inválido: 2 a 4 letras maiúsculas.' }
}

function Get-MemPath([string]$Sistema) {
  Assert-Slug $Sistema
  $root = $script:RaizRepos.TrimEnd('/', '\')
  return "$root/$Sistema/conhecimento"
}

function Get-ConfValue([string]$Key, [string]$File) {
  foreach ($line in (Get-TextLines $File)) {
    $idx = $line.IndexOf(':')
    if ($idx -lt 0) { continue }
    if ($line.Substring(0, $idx) -ne $Key) { continue }
    return (Get-Trim $line.Substring($idx + 1))
  }
  return ''
}

function Resolve-MemDir {
  $dir = ''
  if ($script:MemSistema) {
    $dir = Get-MemPath $script:MemSistema
  } else {
    $walk = (Get-Location).Path
    while ($walk -and $walk -ne [System.IO.Path]::GetPathRoot($walk)) {
      if (Test-Path -LiteralPath (Join-Path $walk '.memoria.conf') -PathType Leaf) { $dir = $walk; break }
      $parent = Split-Path -Parent $walk
      if ($parent -eq $walk) { break }
      $walk = $parent
    }
  }
  $conf = if ($dir) { Join-Path $dir '.memoria.conf' } else { '' }
  if (-not $dir -or -not (Test-Path -LiteralPath $conf -PathType Leaf)) {
    Die 'memória não encontrada. Rode mem init <sistema> <prefixo> ou passe --sistema.'
  }
  $prefix = $script:RaizRepos.TrimEnd('/', '\') + '/'
  $probe = $dir.TrimEnd('/', '\') + '/'
  if (-not $probe.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
    Die "a memória está fora da raiz configurada para EF_MAQUINA=$($env:EF_MAQUINA)."
  }
  $script:MemDir = $dir.TrimEnd('/', '\')
  $script:Prefixo = Get-Trim (Get-ConfValue 'prefixo' $conf)
  if (-not $script:Prefixo) { Die '.memoria.conf sem prefixo.' }
}

function Get-TipoCode([string]$Tipo) {
  switch ($Tipo) {
    'contexto' { return 'CTX' }
    'regra' { return 'RN' }
    'decisao' { return 'ADR' }
    'glossario' { return 'GLO' }
    'modulo' { return 'MOD' }
    'armadilha' { return 'ARM' }
    'contrato' { return 'CTR' }
    'runbook' { return 'RUN' }
    'preferencia' { return 'PREF' }
    default { Die "tipo desconhecido: $Tipo" }
  }
}

function Get-Slug([string]$Value) {
  $s = (ConvertTo-AsciiFold $Value).ToLowerInvariant()
  $s = [regex]::Replace($s, '[^a-z0-9]+', '-')
  $s = [regex]::Replace($s, '-{2,}', '-')
  $s = $s.Trim('-')
  if ($s.Length -gt 40) { $s = $s.Substring(0, 40) }
  if ([string]::IsNullOrEmpty($s)) { $s = 'cartao' }
  return $s
}

function Test-CpfValido([string]$Digits) {
  if ($Digits -notmatch '^[0-9]{11}$') { return $false }
  $same = $true
  for ($i = 1; $i -lt 11; $i++) { if ($Digits[$i] -ne $Digits[0]) { $same = $false; break } }
  if ($same) { return $false }
  $sum = 0
  for ($i = 0; $i -lt 9; $i++) { $sum += [int]::Parse($Digits.Substring($i, 1)) * (10 - $i) }
  $mod = $sum % 11
  $dig = if ($mod -lt 2) { 0 } else { 11 - $mod }
  if ([int]::Parse($Digits.Substring(9, 1)) -ne $dig) { return $false }
  $sum = 0
  for ($i = 0; $i -lt 10; $i++) { $sum += [int]::Parse($Digits.Substring($i, 1)) * (11 - $i) }
  $mod = $sum % 11
  $dig = if ($mod -lt 2) { 0 } else { 11 - $mod }
  return ([int]::Parse($Digits.Substring(10, 1)) -eq $dig)
}

function Test-Luhn([string]$Number) {
  if ($Number.Length -lt 13 -or $Number.Length -gt 19) { return $false }
  if ($Number -notmatch '^[0-9]+$') { return $false }
  $sum = 0
  $alt = $false
  for ($i = $Number.Length - 1; $i -ge 0; $i--) {
    $d = [int]::Parse($Number.Substring($i, 1))
    if ($alt) { $d *= 2; if ($d -gt 9) { $d -= 9 } }
    $sum += $d
    $alt = -not $alt
  }
  return (($sum % 10) -eq 0)
}

function Get-SecretPattern {
  $kw = 'pass' + 'word|p' + 'wd|se' + 'nha|sec' + 'ret|api' + 'key|api_' + 'key|account' + 'key|sharedaccess' + 'key'
  $cs = 'connection' + 'strings'
  $pem = '-----BEGIN ' + 'PRIVATE KEY-----'
  return "(?i)($kw)\s*[=:]|(?i)(server|data\s*source)\s*=|(?i)$cs|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.|" + [regex]::Escape($pem)
}

function Add-LineHits([System.Collections.Generic.List[string]]$Hits, [string]$Rel, [int]$Number, [string]$Line) {
  if ($Line -match '(?i)(^|\s)revalidar_em\s*:') { $Hits.Add("${Rel}:${Number}:revalidar_em") | Out-Null }
  if ([regex]::IsMatch($Line, (Get-SecretPattern))) { $Hits.Add("${Rel}:${Number}:segredo") | Out-Null }
  if ([regex]::IsMatch($Line, '(?<![0-9])[0-9]{3}\.[0-9]{3}\.[0-9]{3}-[0-9]{2}(?![0-9])')) {
    $Hits.Add("${Rel}:${Number}:cpf-formatado") | Out-Null
  }
  foreach ($m in [regex]::Matches($Line, '(?<![0-9])[0-9]{11}(?![0-9])')) {
    if (Test-CpfValido $m.Value) { $Hits.Add("${Rel}:${Number}:cpf-valido") | Out-Null }
  }
  if ([regex]::IsMatch($Line, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')) {
    $Hits.Add("${Rel}:${Number}:email") | Out-Null
  }
  if ([regex]::IsMatch($Line, '\([0-9]{2}\)\s*[0-9]{4,5}-?[0-9]{4}|\+[0-9]{1,3}\s*[0-9]{2}\s*[0-9]{4,5}-?[0-9]{4}|\b[0-9]{2}\s[0-9]{4,5}-[0-9]{4}\b')) {
    $Hits.Add("${Rel}:${Number}:telefone") | Out-Null
  }
  foreach ($m in [regex]::Matches($Line, '[0-9]([0-9]|[ -][0-9]){12,18}')) {
    $digits = -join ($m.Value.ToCharArray() | Where-Object { $_ -match '[0-9]' })
    if (Test-Luhn $digits) { $Hits.Add("${Rel}:${Number}:cartao") | Out-Null }
  }
  if ([regex]::IsMatch($Line, '(?i)ag(?:ê|e)ncia\s*[:=]?\s*[0-9]{3,6}')) { $Hits.Add("${Rel}:${Number}:agencia") | Out-Null }
  if ([regex]::IsMatch($Line, '(?i)\bconta\s*[:=]\s*[0-9][0-9.\-]{3,}|\bconta\s+[0-9]{5,}(-[0-9])?\b')) {
    $Hits.Add("${Rel}:${Number}:conta") | Out-Null
  }
  if ([regex]::IsMatch($Line, '(?i)\bIBAN\s*[:=]?\s*[A-Z]{2}[0-9]{2}[A-Z0-9]{8,}')) { $Hits.Add("${Rel}:${Number}:iban") | Out-Null }
  if ([regex]::IsMatch($Line, '(?i)(\bchave\s+pix\b|\bpix\b)\s*[:=]\s*\S+')) { $Hits.Add("${Rel}:${Number}:pix") | Out-Null }
}

function Test-CardPath([string]$Rel) {
  if ($Rel -like '_templates/*' -or $Rel -eq 'README.md' -or $Rel -eq 'INDEX.md' -or $Rel -eq '.gitignore') { return $false }
  return $Rel.EndsWith('.md')
}

function Get-MemFiles {
  if (-not (Test-Path -LiteralPath $script:MemDir)) { return @() }
  $list = New-Object System.Collections.Generic.List[string]
  Get-ChildItem -LiteralPath $script:MemDir -Recurse -Force -File | ForEach-Object {
    $full = $_.FullName
    if ($full -match '[\\/]\.cache[\\/]') { return }
    $list.Add($full) | Out-Null
  }
  $arr = $list.ToArray()
  [Array]::Sort($arr, [System.StringComparer]::Ordinal)
  return $arr
}

function Get-Rel([string]$Full) {
  $root = $script:MemDir.TrimEnd('/', '\') + '/'
  $rel = $Full
  if ($rel.StartsWith($root, [System.StringComparison]::Ordinal)) { $rel = $rel.Substring($root.Length) }
  return ($rel -replace '\\', '/')
}

function Get-CardFiles {
  $cards = New-Object System.Collections.Generic.List[string]
  foreach ($file in (Get-MemFiles)) {
    if (Test-CardPath (Get-Rel $file)) { $cards.Add($file) | Out-Null }
  }
  return $cards.ToArray()
}

function Add-StructuralHits([System.Collections.Generic.List[string]]$Hits, [string]$File, [System.Collections.Generic.List[string]]$Seen) {
  $rel = Get-Rel $File
  if (-not (Test-CardPath $rel)) { return }
  $id = Get-ConfValue 'id' $File
  $tipo = Get-ConfValue 'tipo' $File
  $titulo = Get-ConfValue 'titulo' $File
  $escopo = Get-ConfValue 'escopo' $File
  $tags = Get-ConfValue 'tags' $File
  $status = Get-ConfValue 'status' $File
  $fonte = Get-ConfValue 'fonte' $File
  $dono = Get-ConfValue 'dono' $File
  $criado = Get-ConfValue 'criado' $File
  $atualizado = Get-ConfValue 'atualizado' $File
  if (-not $id -or -not $tipo -or -not $titulo -or -not $escopo -or -not $tags -or -not $status -or -not $fonte -or -not $dono -or -not $criado -or -not $atualizado) {
    $Hits.Add("${rel}:1:front-matter") | Out-Null
  }
  switch ($status) {
    { $_ -in @('pendente', 'rascunho', 'confirmada', 'conflito', 'obsoleta', 'substituida') } { }
    default { $Hits.Add("${rel}:1:front-matter") | Out-Null }
  }
  if ($status -eq 'confirmada') {
    $conf = Get-ConfValue 'confirmado_por' $File
    if ($conf -notmatch '^matheus:') { $Hits.Add("${rel}:1:confirmada-sem-ok") | Out-Null }
  }
  if ($id) {
    if ($Seen.Contains($id)) { $Hits.Add("${rel}:1:id-duplicado") | Out-Null }
    $Seen.Add($id) | Out-Null
  }
}

function Get-LintScan {
  $hits = New-Object System.Collections.Generic.List[string]
  $seen = New-Object System.Collections.Generic.List[string]
  foreach ($file in (Get-MemFiles)) {
    $rel = Get-Rel $file
    $n = 0
    foreach ($line in (Get-TextLines $file)) {
      $n++
      Add-LineHits $hits $rel $n $line
    }
    Add-StructuralHits $hits $file $seen
  }
  return $hits
}

function Get-FileLineHits([string]$File) {
  $hits = New-Object System.Collections.Generic.List[string]
  $rel = Get-Rel $File
  $n = 0
  foreach ($line in (Get-TextLines $File)) {
    $n++
    Add-LineHits $hits $rel $n $line
  }
  return $hits
}

function Invoke-Init([string[]]$Argv) {
  if ($Argv.Count -lt 2 -or -not $Argv[0] -or -not $Argv[1]) { Die 'uso: mem init <sistema> <prefixo>' }
  $sistema = $Argv[0]
  $prefixo = $Argv[1]
  Assert-Slug $sistema
  Assert-Prefix $prefixo
  $dest = Get-MemPath $sistema
  if (Test-Path -LiteralPath (Join-Path $dest '.memoria.conf')) { Die "já inicializado: $dest" }
  foreach ($sub in @('contextos', 'projeto', 'repos', '_templates')) {
    New-Item -ItemType Directory -Path (Join-Path $dest $sub) -Force | Out-Null
  }
  Copy-Item -LiteralPath (Join-Path $Template 'README.md') -Destination (Join-Path $dest 'README.md')
  Copy-Item -LiteralPath (Join-Path $Template '.gitignore') -Destination (Join-Path $dest '.gitignore')
  Copy-Item -LiteralPath (Join-Path $Template '_templates/cartao.md') -Destination (Join-Path $dest '_templates/cartao.md')
  $confText = $Utf8.GetString([System.IO.File]::ReadAllBytes((Join-Path $Template '.memoria.conf')))
  $confText = [regex]::Replace($confText, '(?m)^prefixo:.*$', "prefixo: $prefixo")
  $confText = [regex]::Replace($confText, '(?m)^sistema:.*$', "sistema: $sistema")
  Write-Utf8Lf (Join-Path $dest '.memoria.conf') ($confText.TrimEnd("`r", "`n"))
  Write-Out "raiz_repos=$($script:RaizRepos)"
  Write-Out "conhecimento=$dest"
  Write-Out 'mem init: 1'
}

function Format-List([string]$Value) {
  if ([string]::IsNullOrEmpty($Value)) { return '' }
  return [regex]::Replace($Value, '\s*,\s*', ', ')
}

function Get-NextId([string]$Code) {
  $max = 0
  $re = '^{0}-{1}-([0-9]{{4}})$' -f [regex]::Escape($script:Prefixo), [regex]::Escape($Code)
  foreach ($file in (Get-CardFiles)) {
    $id = Get-ConfValue 'id' $file
    $m = [regex]::Match($id, $re)
    if (-not $m.Success) { continue }
    $n = [int]$m.Groups[1].Value
    if ($n -gt $max) { $max = $n }
  }
  return '{0}-{1}-{2:D4}' -f $script:Prefixo, $Code, ($max + 1)
}

function Take-Value([string[]]$Argv, [int]$Index, [string]$Flag) {
  if ($Index + 1 -ge $Argv.Count) { Die "faltou valor para $Flag" }
  return $Argv[$Index + 1]
}

function Invoke-Novo([string[]]$Argv) {
  if ($Argv.Count -lt 1 -or -not $Argv[0]) { Die 'uso: mem novo <tipo> --titulo ... --origem ditado|bot' }
  $tipo = $Argv[0]
  $titulo = ''
  $origem = ''
  $ctx = ''
  $tags = ''
  $gatilhos = ''
  $escopo = 'projeto'
  $corpo = ''
  $i = 1
  while ($i -lt $Argv.Count) {
    $flag = $Argv[$i]
    switch ($flag) {
      '--titulo' { $titulo = Take-Value $Argv $i $flag; $i += 2 }
      '--origem' { $origem = Take-Value $Argv $i $flag; $i += 2 }
      '--contexto' { $ctx = Take-Value $Argv $i $flag; $i += 2 }
      '--tags' { $tags = Take-Value $Argv $i $flag; $i += 2 }
      '--gatilhos' { $gatilhos = Take-Value $Argv $i $flag; $i += 2 }
      '--escopo' { $escopo = Take-Value $Argv $i $flag; $i += 2 }
      '--corpo' { $corpo = Take-Value $Argv $i $flag; $i += 2 }
      default { Die "argumento desconhecido em novo: $flag" }
    }
  }
  if (-not $titulo) { Die 'novo exige --titulo.' }
  switch ($origem) {
    'ditado' { $status = 'pendente' }
    'bot' { $status = 'rascunho' }
    default { Die 'novo exige --origem ditado ou --origem bot. Cartão não nasce confirmada.' }
  }
  switch ($escopo) {
    { $_ -in @('projeto', 'repo', 'global') } { }
    default { Die 'escopo inválido.' }
  }
  if ($ctx -and $ctx -notmatch '^[a-z0-9-]{1,40}$') { Die 'contexto inválido.' }
  $code = Get-TipoCode $tipo
  $id = Get-NextId $code
  $slug = Get-Slug $titulo
  $hoje = (Get-Date).ToString('yyyy-MM-dd')
  if (-not $tags) { $tags = 'geral' }
  $tags = Format-List $tags
  $gatilhos = Format-List $gatilhos
  if (-not $corpo) { $corpo = 'Cartão fictício.' }
  if ($tipo -eq 'contexto') {
    if (-not $ctx) { Die 'tipo contexto exige --contexto.' }
    $dir = Join-Path $script:MemDir "contextos/$ctx"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $dest = Join-Path $dir 'CONTEXTO.md'
    if (Test-Path -LiteralPath $dest) { Die "contexto já existe: $ctx" }
  } elseif ($ctx) {
    $dir = Join-Path $script:MemDir "contextos/$ctx"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $dest = Join-Path $dir "${id}--${slug}.md"
  } else {
    $dest = Join-Path $script:MemDir "projeto/${id}--${slug}.md"
  }
  $ctxLine = ''
  if ($ctx) { $ctxLine = "contexto: $ctx`n" }
  $text = @"
---
id: $id
tipo: $tipo
titulo: $titulo
escopo: $escopo
tags: [$tags]
status: $status
fonte: [$origem]
dono: revisor-entrega
criado: $hoje
atualizado: $hoje
${ctxLine}gatilhos: [$gatilhos]
---
$corpo
"@
  $text = $text -replace "`r`n", "`n"
  Write-Utf8Lf $dest $text
  $hits = @(Get-FileLineHits $dest)
  if ($hits.Count -gt 0) {
    Remove-Item -LiteralPath $dest -Force
    foreach ($hit in $hits) { Write-ErrLine $hit }
    Die 'escrita bloqueada pelo lint. O arquivo não foi mantido.'
  }
  Write-Out "id=$id"
  Write-Out "status=$status"
  Write-Out 'mem novo: 1'
}

function Invoke-Lint {
  $hits = @(Get-LintScan)
  foreach ($hit in $hits) { if ($hit) { Write-Out $hit } }
  Write-Out "mem lint: $($hits.Count)"
  if ($hits.Count -ne 0) { exit 1 }
}

function Get-Row([string]$File) {
  return @(
    (Get-ConfValue 'id' $File),
    (Get-ConfValue 'tipo' $File),
    (Get-ConfValue 'status' $File),
    (Get-ConfValue 'contexto' $File),
    (Get-ConfValue 'tags' $File),
    (Get-ConfValue 'titulo' $File),
    (Get-ConfValue 'gatilhos' $File)
  ) -join "`t"
}

function Invoke-Index {
  $hits = @(Get-LintScan)
  if ($hits.Count -ne 0) {
    foreach ($hit in $hits) { if ($hit) { Write-ErrLine $hit } }
    Write-ErrLine "mem lint: $($hits.Count)"
    Die 'index abortado: o lint bloqueou.'
  }
  $rows = New-Object System.Collections.Generic.List[string]
  foreach ($file in (Get-CardFiles)) { $rows.Add((Get-Row $file)) | Out-Null }
  $arr = $rows.ToArray()
  [Array]::Sort($arr, [System.StringComparer]::Ordinal)
  $sistema = Get-ConfValue 'sistema' (Join-Path $script:MemDir '.memoria.conf')
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('# INDEX')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('Gerado por mem index. Não editar à mão.')
  [void]$sb.AppendLine('Memória local; versionamento em Git previsto para a 3.2.')
  [void]$sb.AppendLine("sistema: $sistema")
  [void]$sb.AppendLine("prefixo: $($script:Prefixo)")
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('## Contextos e gatilhos')
  foreach ($row in $arr) {
    $p = $row.Split("`t")
    if ($p[1] -ne 'contexto') { continue }
    [void]$sb.AppendLine("- $($p[0]) | $($p[3]) | gatilhos: $($p[6]) | $($p[5])")
  }
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('## Cartões')
  $count = 0
  foreach ($row in $arr) {
    $p = $row.Split("`t")
    if ($p[2] -eq 'obsoleta' -or $p[2] -eq 'substituida') { continue }
    [void]$sb.AppendLine("$($p[0]) | $($p[1]) | $($p[2]) | $($p[3]) | $($p[4]) | $($p[5])")
    $count++
  }
  $indexPath = Join-Path $script:MemDir 'INDEX.md'
  Write-Utf8Lf $indexPath ($sb.ToString().TrimEnd("`r", "`n"))
  Write-Out "index=$indexPath"
  Write-Out "mem index: $count"
}

function Test-TagMatch([string]$Have, [string]$Want) {
  if ([string]::IsNullOrEmpty($Want)) { return $true }
  foreach ($one in ($Want -split ',')) {
    $one = Get-Trim $one
    if (-not $one) { continue }
    if ($Have.IndexOf($one, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
  }
  return $false
}

function Get-CardsById {
  $pairs = New-Object System.Collections.Generic.List[string]
  foreach ($file in (Get-CardFiles)) {
    $id = Get-ConfValue 'id' $file
    $pairs.Add("$id`t$file") | Out-Null
  }
  $arr = $pairs.ToArray()
  [Array]::Sort($arr, [System.StringComparer]::Ordinal)
  $files = New-Object System.Collections.Generic.List[string]
  foreach ($pair in $arr) {
    $tab = $pair.IndexOf("`t")
    $files.Add($pair.Substring($tab + 1)) | Out-Null
  }
  return $files.ToArray()
}

function Invoke-Find([string[]]$Argv) {
  $ctx = ''
  $tipo = ''
  $tags = ''
  $repo = ''
  $status = ''
  $i = 0
  while ($i -lt $Argv.Count) {
    $flag = $Argv[$i]
    switch ($flag) {
      '--contexto' { $ctx = Take-Value $Argv $i $flag; $i += 2 }
      '--tipo' { $tipo = Take-Value $Argv $i $flag; $i += 2 }
      '--tags' { $tags = Take-Value $Argv $i $flag; $i += 2 }
      '--repo' { $repo = Take-Value $Argv $i $flag; $i += 2 }
      '--status' { $status = Take-Value $Argv $i $flag; $i += 2 }
      default { Die "argumento desconhecido em find: $flag" }
    }
  }
  $count = 0
  foreach ($file in (Get-CardsById)) {
    $id = Get-ConfValue 'id' $file
    $t = Get-ConfValue 'tipo' $file
    $s = Get-ConfValue 'status' $file
    $c = Get-ConfValue 'contexto' $file
    $g = Get-ConfValue 'tags' $file
    $titulo = Get-ConfValue 'titulo' $file
    if ($ctx -and $c -ne $ctx) { continue }
    if ($tipo -and $t -ne $tipo) { continue }
    if ($status -and ",$status,".IndexOf(",$s,", [System.StringComparison]::Ordinal) -lt 0) { continue }
    if ($repo) {
      $repos = Get-ConfValue 'repos' $file
      if ($repos.IndexOf($repo, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
    }
    if (-not (Test-TagMatch $g $tags)) { continue }
    Write-Out "$id | $t | $s | $c | $g | $titulo"
    $count++
  }
  Write-Out "mem find: $count"
}

function Invoke-Grep([string[]]$Argv) {
  if ($Argv.Count -lt 1 -or -not $Argv[0]) { Die 'uso: mem grep <termo>' }
  $term = $Argv[0]
  $count = 0
  foreach ($file in (Get-CardFiles)) {
    $id = Get-ConfValue 'id' $file
    if (-not $id) { $id = [System.IO.Path]::GetFileName($file) }
    $n = 0
    foreach ($line in (Get-TextLines $file)) {
      $n++
      if ($line.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        Write-Out "${id}:${n}:${line}"
        $count++
      }
    }
  }
  Write-Out "mem grep: $count"
}

function Find-IdPath([string]$Want) {
  foreach ($file in (Get-CardFiles)) {
    if ((Get-ConfValue 'id' $file) -eq $Want) { return $file }
  }
  return ''
}

function Invoke-Show([string[]]$Argv) {
  if ($Argv.Count -lt 1) { Die 'uso: mem show <id>...' }
  $count = 0
  foreach ($id in $Argv) {
    $file = Find-IdPath $id
    if (-not $file) { Die "id não encontrado: $id" }
    Write-Out "===== $id ====="
    foreach ($line in (Get-TextLines $file)) { Write-Out $line }
    Write-Out ''
    $count++
  }
  Write-Out "mem show: $count"
}

function Invoke-Pacote([string[]]$Argv) {
  if ($Argv.Count -lt 1) { Die 'uso: mem pacote <id>...' }
  Write-Out '# Pacote para a ordem de serviço'
  Write-Out 'confirmada = regra; rascunho ou pendente = hipótese.'
  $count = 0
  foreach ($id in $Argv) {
    $file = Find-IdPath $id
    if (-not $file) { Die "id não encontrado: $id" }
    $st = Get-ConfValue 'status' $file
    Write-Out ''
    Write-Out "## $id ($st)"
    Write-Out ''
    foreach ($line in (Get-TextLines $file)) { Write-Out $line }
    Write-Out ''
    $count++
  }
  Write-Out "mem pacote: $count"
}

function Invoke-Gatilho([string[]]$Argv) {
  if ($Argv.Count -lt 1 -or -not $Argv[0]) { Die 'uso: mem gatilho <palavra>' }
  $palavra = $Argv[0]
  $count = 0
  foreach ($file in (Get-CardsById)) {
    $gat = Get-ConfValue 'gatilhos' $file
    if (-not $gat) { continue }
    if ($gat.IndexOf($palavra, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
    $id = Get-ConfValue 'id' $file
    $ctx = Get-ConfValue 'contexto' $file
    Write-Out "$id | $ctx | $gat"
    $count++
  }
  Write-Out "mem gatilho: $count"
}

function Invoke-Pendentes {
  $count = 0
  foreach ($file in (Get-CardsById)) {
    $status = Get-ConfValue 'status' $file
    if ($status -in @('pendente', 'rascunho', 'conflito')) {
      $id = Get-ConfValue 'id' $file
      $titulo = Get-ConfValue 'titulo' $file
      Write-Out "$id | $status | $titulo"
      $count++
    }
  }
  Write-Out "mem pendentes: $count"
}

function Get-NormWords([string]$Value) {
  $raw = (ConvertTo-AsciiFold $Value).ToLowerInvariant()
  $raw = [regex]::Replace($raw, '[^a-z]+', ' ')
  $stop = ' de da do das dos a o e em no na nos nas para com por um uma que se os as '
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($w in ($raw -split '\s+')) {
    if (-not $w) { continue }
    if ($stop.Contains(" $w ")) { continue }
    $out.Add($w) | Out-Null
  }
  return ($out -join ' ')
}

function Invoke-Dupes {
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($file in (Get-CardFiles)) {
    $id = Get-ConfValue 'id' $file
    $tipo = Get-ConfValue 'tipo' $file
    $ctx = Get-ConfValue 'contexto' $file
    $tags = (Get-ConfValue 'tags' $file) -replace '\s', ''
    $words = Get-NormWords (Get-ConfValue 'titulo' $file)
    $lines.Add("$id`t$tipo`t$ctx`t$tags`t$words") | Out-Null
  }
  $arr = $lines.ToArray()
  [Array]::Sort($arr, [System.StringComparer]::Ordinal)
  $count = 0
  for ($i = 0; $i -lt $arr.Length; $i++) {
    for ($j = $i + 1; $j -lt $arr.Length; $j++) {
      $a = $arr[$i].Split("`t")
      $b = $arr[$j].Split("`t")
      if ($a[1] -ne $b[1] -or $a[2] -ne $b[2]) { continue }
      $hit = $false
      if ($a[3] -and $a[3] -ne '[]' -and $a[3] -eq $b[3]) { $hit = $true }
      if (-not $hit -and $a[4] -and $b[4]) {
        $w1 = @($a[4].Split(' '))
        $w2 = @($b[4].Split(' '))
        $shared = 0
        foreach ($ww in $w1) { if ($ww -and ($w2 -contains $ww)) { $shared++ } }
        $union = @($w1 + $w2 | Where-Object { $_ } | Select-Object -Unique).Count
        if ($shared -ge 2 -and $union -gt 0 -and ($shared * 2) -ge $union) { $hit = $true }
      }
      if ($hit) {
        Write-Out "DUP $($a[0]) $($b[0])"
        $count++
      }
    }
  }
  Write-Out "mem dupes: $count"
}

$scriptArgs = @($args)
$rest = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $scriptArgs.Count; $i++) {
  $item = [string]$scriptArgs[$i]
  if ($item -eq '--sistema') {
    if ($i + 1 -ge $scriptArgs.Count -or -not $scriptArgs[$i + 1]) { Die '--sistema exige um slug.' }
    $script:MemSistema = [string]$scriptArgs[$i + 1]
    $i++
    continue
  }
  if ($item -in @('-h', '--help', 'help')) { Show-Usage; exit 0 }
  $rest.Add($item) | Out-Null
}
if ($rest.Count -eq 0) { Show-Usage; exit 1 }

Import-Maquina
$cmd = $rest[0]
$cmdArgs = @()
if ($rest.Count -gt 1) { $cmdArgs = $rest.GetRange(1, $rest.Count - 1).ToArray() }

switch ($cmd) {
  'init' { Invoke-Init $cmdArgs }
  { $_ -in @('novo', 'index', 'find', 'grep', 'show', 'gatilho', 'pacote', 'pendentes', 'dupes', 'lint') } {
    Resolve-MemDir
    switch ($cmd) {
      'novo' { Invoke-Novo $cmdArgs }
      'index' { Invoke-Index }
      'find' { Invoke-Find $cmdArgs }
      'grep' { Invoke-Grep $cmdArgs }
      'show' { Invoke-Show $cmdArgs }
      'gatilho' { Invoke-Gatilho $cmdArgs }
      'pacote' { Invoke-Pacote $cmdArgs }
      'pendentes' { Invoke-Pendentes }
      'dupes' { Invoke-Dupes }
      'lint' { Invoke-Lint }
    }
  }
  default { Die "comando desconhecido: $cmd" }
}
exit 0
