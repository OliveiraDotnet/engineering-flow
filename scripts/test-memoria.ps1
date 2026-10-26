#Requires -Version 7
# Fixtures fictícias. Literais sensíveis são montados em tempo de execução.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$ScriptDir = Split-Path -Parent $PSCommandPath
$PackRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$Mem = Join-Path $PackRoot 'tools/memoria.ps1'
$Protect = Join-Path $ScriptDir 'protect-engineering-flow-files.ps1'
$Install = Join-Path $ScriptDir 'install-agent-pack.ps1'
$Pwsh = (Get-Command pwsh).Source

function Fail([string]$Message) { Write-Output "FAIL: $Message"; exit 1 }
function Pass([string]$Message) { Write-Output "PASS: $Message" }
function Join-Parts([string[]]$Parts) { return -join $Parts }

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('ef-mem-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $Tmp 'repos') -Force | Out-Null
$conf = @"
[fixture]
descricao: temporaria
machine_id: 00000000-0000-4000-8000-000000000099
raiz_repos: $Tmp/repos

[semraiz]
descricao: sem raiz
machine_id: 00000000-0000-4000-8000-000000000098
"@
[System.IO.File]::WriteAllText((Join-Path $Tmp 'maquinas.conf'), ($conf -replace "`r`n","`n"), [Text.UTF8Encoding]::new($false))
$env:EF_MAQUINAS_CONF = Join-Path $Tmp 'maquinas.conf'
Remove-Item Env:EF_MAQUINA -ErrorAction SilentlyContinue

function Invoke-Mem([string[]]$Cmd) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $lines = & $Pwsh -NoProfile -File $Mem @Cmd 2>&1 | ForEach-Object { "$_" }
  $ErrorActionPreference = $prev
  $text = if ($lines) { ($lines -join "`n") } else { '' }
  return [pscustomobject]@{ Out = $text; Code = $LASTEXITCODE }
}

try {
  Write-Output '== C07 máquina =='
  $r = Invoke-Mem @('lint')
  if ($r.Code -eq 0) { Fail 'EF_MAQUINA ausente deveria falhar' }
  if ($r.Out -notmatch 'EF_MAQUINA ausente') { Fail 'mensagem de ausência' }
  Pass 'EF_MAQUINA ausente'

  $env:EF_MAQUINA = 'naoexiste'
  $r = Invoke-Mem @('lint')
  if ($r.Code -eq 0) { Fail 'bloco inválido deveria falhar' }
  if ($r.Out -notmatch 'não é um bloco') { Fail "mensagem de bloco inválido: $($r.Out)" }
  Pass 'EF_MAQUINA inválida'

  $env:EF_MAQUINA = 'semraiz'
  $r = Invoke-Mem @('lint')
  if ($r.Code -eq 0) { Fail 'bloco sem raiz deveria falhar' }
  if ($r.Out -notmatch 'não define raiz_repos') { Fail 'mensagem de raiz ausente' }
  Write-Output $r.Out
  Pass 'bloco sem raiz_repos'

  $env:EF_MAQUINA = 'fixture'
  $win = Join-Parts @('C:\','Repositorios')
  $nix = Join-Parts @('/mnt/','wd500')
  $hits = Get-ChildItem -Path (Join-Path $PackRoot 'tools'), (Join-Path $PackRoot 'scripts') -Recurse -Include '*.sh','*.ps1' -File |
    Select-String -SimpleMatch -Pattern $win,$nix
  if ($hits) { Fail 'caminho literal em script' }
  Pass 'scripts sem caminho literal'

  Write-Output '== C04 ciclo =='
  $r = Invoke-Mem @('--sistema','sisman','init','sisman','SIS')
  Write-Output $r.Out
  if ($r.Code -ne 0) { Fail "init: $($r.Out)" }
  if ($r.Out -notmatch [regex]::Escape("raiz_repos=$Tmp/repos")) { Fail 'init não mostrou a raiz' }
  if ($r.Out -notmatch [regex]::Escape("conhecimento=$Tmp/repos/sisman/conhecimento")) { Fail 'init não mostrou conhecimento' }
  if ($r.Out -notmatch 'mem init: 1') { Fail 'contagem do init' }
  $Know = Join-Path $Tmp 'repos/sisman/conhecimento'
  $meta = [IO.File]::ReadAllText((Join-Path $Know '.memoria.conf'))
  if ($meta -notmatch '(?m)^prefixo: SIS$') { Fail 'prefixo' }
  if ($meta -notmatch '(?m)^sistema: sisman$') { Fail 'sistema' }
  Pass 'init'

  $r = Invoke-Mem @('--sistema','sisman','init','sisman','SIS')
  if ($r.Code -eq 0) { Fail 'segundo init deveria falhar' }
  if ($r.Out -notmatch 'já inicializado') { Fail 'mensagem de reinicialização' }
  Pass 'init idempotente na falha'

  Push-Location $Know
  try { $r = Invoke-Mem @('lint') } finally { Pop-Location }
  if ($r.Code -ne 0) { Fail "lint no diretório por descoberta: $($r.Out)" }
  if ($r.Out -notmatch 'mem lint: 0') { Fail 'descoberta sem contagem' }
  Pass 'resolve a pasta da memória'

  $r = Invoke-Mem @('--sistema','sisman','novo','regra','--titulo','Regra de fixture','--origem','bot','--tags','os,regra','--gatilhos','OS','--corpo','Texto limpo da regra alfa-fixture.')
  Write-Output $r.Out
  if ($r.Code -ne 0) { Fail "novo bot: $($r.Out)" }
  if ($r.Out -notmatch 'id=SIS-RN-0001') { Fail 'id da regra' }
  if ($r.Out -notmatch 'status=rascunho') { Fail 'bot nasce rascunho' }
  if ($r.Out -notmatch 'mem novo: 1') { Fail 'contagem do novo' }
  Pass 'novo bot'

  $r = Invoke-Mem @('--sistema','sisman','novo','contexto','--titulo','Contexto da ordem','--origem','ditado','--contexto','os','--tags','os','--gatilhos','OS,ordem','--corpo','Texto limpo do contexto.')
  Write-Output $r.Out
  if ($r.Code -ne 0) { Fail "novo ditado: $($r.Out)" }
  if ($r.Out -notmatch 'id=SIS-CTX-0001') { Fail 'id do contexto' }
  if ($r.Out -notmatch 'status=pendente') { Fail 'ditado nasce pendente' }
  if (-not (Test-Path (Join-Path $Know 'contextos/os/CONTEXTO.md'))) { Fail 'CONTEXTO.md' }
  Pass 'novo ditado'

  $r = Invoke-Mem @('--sistema','sisman','novo','regra','--titulo','Nao nasce ativa','--origem','confirmada','--corpo','nao')
  if ($r.Code -eq 0) { Fail 'origem confirmada deveria falhar' }
  if ($r.Out -notmatch 'não nasce confirmada') { Fail 'mensagem de nascimento' }
  Pass 'não nasce confirmada'

  $r = Invoke-Mem @('--sistema','sisman','index')
  Write-Output $r.Out
  if ($r.Code -ne 0) { Fail "index: $($r.Out)" }
  if ($r.Out -notmatch 'mem index: 2') { Fail 'contagem do index' }
  $index = [IO.File]::ReadAllText((Join-Path $Know 'INDEX.md'))
  if ($index -notmatch 'SIS-RN-0001') { Fail 'index sem a regra' }
  if ($index -notmatch 'SIS-CTX-0001') { Fail 'index sem o contexto' }
  Pass 'index'

  $r = Invoke-Mem @('--sistema','sisman','find','--tipo','regra')
  Write-Output $r.Out
  if ($r.Out -notmatch 'mem find: 1') { Fail 'find tipo' }
  $r = Invoke-Mem @('--sistema','sisman','find','--contexto','os','--tipo','contexto')
  if ($r.Out -notmatch 'mem find: 1') { Fail 'find contexto' }
  $r = Invoke-Mem @('--sistema','sisman','find','--tags','os')
  if ($r.Out -notmatch 'mem find: 2') { Fail 'find tags' }
  $r = Invoke-Mem @('--sistema','sisman','find','--status','rascunho,pendente')
  if ($r.Out -notmatch 'mem find: 2') { Fail 'find status' }
  $r = Invoke-Mem @('--sistema','sisman','find','--tipo','regra','--status','pendente')
  if ($r.Out -notmatch 'mem find: 0') { Fail 'find vazio' }
  Pass 'find'

  $r = Invoke-Mem @('--sistema','sisman','grep','Texto limpo')
  Write-Output $r.Out
  if ($r.Out -notmatch 'mem grep: 2') { Fail 'grep contagem' }
  $r = Invoke-Mem @('--sistema','sisman','grep','ALFA-FIXTURE')
  if ($r.Out -notmatch 'mem grep: 1') { Fail 'grep sem diferenciar maiúsculas' }
  Pass 'grep'

  $r = Invoke-Mem @('--sistema','sisman','gatilho','OS')
  Write-Output $r.Out
  if ($r.Out -notmatch 'mem gatilho: 2') { Fail 'gatilho' }
  Pass 'gatilho'

  $r = Invoke-Mem @('--sistema','sisman','pendentes')
  Write-Output $r.Out
  if ($r.Out -notmatch 'mem pendentes: 2') { Fail 'pendentes' }
  Pass 'pendentes'

  $r = Invoke-Mem @('--sistema','sisman','dupes')
  Write-Output $r.Out
  if ($r.Out -notmatch 'mem dupes: 0') { Fail 'dupes iniciais' }
  Pass 'dupes zero'

  $r = Invoke-Mem @('--sistema','sisman','lint')
  Write-Output $r.Out
  if ($r.Code -ne 0 -or $r.Out -notmatch 'mem lint: 0') { Fail 'lint limpo' }
  Pass 'lint zero'

  $r = Invoke-Mem @('--sistema','sisman','show','SIS-RN-0001')
  Write-Output $r.Out
  if ($r.Out -notmatch 'mem show: 1') { Fail 'show' }
  if ($r.Out -notmatch 'status: rascunho') { Fail 'show status' }
  Pass 'show'

  $r = Invoke-Mem @('--sistema','sisman','pacote','SIS-CTX-0001','SIS-RN-0001')
  if ($r.Out -notmatch 'mem pacote: 2') { Fail 'pacote' }
  if ($r.Out -notmatch 'hipótese') { Fail 'pacote sem rótulo' }
  Pass 'pacote'

  Write-Output '== dupes =='
  $r = Invoke-Mem @('--sistema','dup','init','dup','DU')
  if ($r.Code -ne 0) { Fail "init dup: $($r.Out)" }
  foreach ($pair in @(
      @('Preco final do item','vendas','preco,final','Um.'),
      @('Outro assunto qualquer','vendas','preco, final','Dois.'),
      @('Limite diario de desconto','vendas','alfa','Tres.'),
      @('Limite diario de juros','vendas','beta','Quatro.'),
      @('Limite diario de desconto','caixa','alfa','Cinco.')
    )) {
    $made = Invoke-Mem @('--sistema','dup','novo','regra','--titulo',$pair[0],'--origem','bot','--contexto',$pair[1],'--tags',$pair[2],'--corpo',$pair[3])
    if ($made.Code -ne 0) { Fail "novo dup: $($made.Out)" }
  }
  $r = Invoke-Mem @('--sistema','dup','dupes')
  Write-Output $r.Out
  if ($r.Out -notmatch 'DUP DU-RN-0001 DU-RN-0002') { Fail 'par por tag' }
  if ($r.Out -notmatch 'DUP DU-RN-0003 DU-RN-0004') { Fail 'par por título' }
  if ($r.Out -notmatch 'mem dupes: 2') { Fail 'contagem de dupes' }
  Pass 'dupes'

  Write-Output '== index omite obsoleta =='
  $r = Invoke-Mem @('--sistema','idx','init','idx','IDX')
  if ($r.Code -ne 0) { Fail "init idx: $($r.Out)" }
  $made = Invoke-Mem @('--sistema','idx','novo','regra','--titulo','Cartao ativo','--origem','bot','--corpo','Ativo.')
  if ($made.Code -ne 0) { Fail $made.Out }
  $old = @'
---
id: IDX-RN-0099
tipo: regra
titulo: Cartao velho
escopo: projeto
tags: [velho]
status: obsoleta
fonte: [bot]
dono: revisor-entrega
criado: 2026-10-26
atualizado: 2026-10-26
gatilhos: []
---
Fora da lista principal.
'@
  $oldPath = Join-Path $Tmp 'repos/idx/conhecimento/projeto/velho.md'
  [IO.File]::WriteAllText($oldPath, ($old -replace "`r`n","`n") + "`n", [Text.UTF8Encoding]::new($false))
  $r = Invoke-Mem @('--sistema','idx','index')
  Write-Output $r.Out
  if ($r.Code -ne 0) { Fail "index com obsoleta: $($r.Out)" }
  if ($r.Out -notmatch 'mem index: 1') { Fail 'obsoleta entrou na contagem' }
  $idxText = [IO.File]::ReadAllText((Join-Path $Tmp 'repos/idx/conhecimento/INDEX.md'))
  if ($idxText -match 'IDX-RN-0099') { Fail 'obsoleta listada no index' }
  Pass 'index sem obsoleta'

  $cpfOk = Join-Parts @('529982247','25')
  $sum = 0
  for ($i = 0; $i -lt 9; $i++) { $sum += [int]::Parse($cpfOk.Substring($i,1)) * (10 - $i) }
  $mod = $sum % 11
  $dig = if ($mod -lt 2) { 0 } else { 11 - $mod }
  if ([int]::Parse($cpfOk.Substring(9,1)) -ne $dig) { Fail 'vetor de CPF não confere no primeiro dígito' }
  $sum = 0
  for ($i = 0; $i -lt 10; $i++) { $sum += [int]::Parse($cpfOk.Substring($i,1)) * (11 - $i) }
  $mod = $sum % 11
  $dig = if ($mod -lt 2) { 0 } else { 11 - $mod }
  if ([int]::Parse($cpfOk.Substring(10,1)) -ne $dig) { Fail 'vetor de CPF não confere no segundo dígito' }

  $r = Invoke-Mem @('--sistema','lab','init','lab','LAB')
  if ($r.Code -ne 0) { Fail "init lab: $($r.Out)" }
  $Lab = Join-Path $Tmp 'repos/lab/conhecimento'
  function Count-Md([string]$Root) { return @(Get-ChildItem -LiteralPath $Root -Recurse -Filter '*.md' -File).Count }

  Write-Output '== C05 e C06 lint =='
  function Block([string]$Name, [string]$Class, [string]$Body) {
    $before = Count-Md $Lab
    $got = Invoke-Mem @('--sistema','lab','novo','regra','--titulo',"Bloqueio $Name",'--origem','bot','--corpo',$Body)
    $after = Count-Md $Lab
    if ($got.Code -eq 0) { Fail "$Name deveria bloquear" }
    if ($got.Out -notmatch [regex]::Escape($Class)) { Fail "$Name sem ${Class}: $($got.Out)" }
    if ($before -ne $after) { Fail "$Name manteve arquivo" }
    Write-Output "PASS: bloqueia $Name ($Class)"
    Write-Output $got.Out
  }
  function Allow([string]$Name, [string]$Body) {
    $got = Invoke-Mem @('--sistema','lab','novo','regra','--titulo',"Livre $Name",'--origem','bot','--corpo',$Body)
    if ($got.Code -ne 0) { Fail "allow ${Name}: $($got.Out)" }
    if ($got.Out -notmatch 'mem novo: 1') { Fail "allow $Name contagem" }
    Write-Output "PASS: aceita $Name"
    Write-Output $got.Out
  }

  Block 'cpf-fmt' 'cpf-formatado' (Join-Parts @('529.','982.','247-','00'))
  Block 'cpf-ok' 'cpf-valido' $cpfOk
  Block 'email' 'email' (Join-Parts @('usuario.teste','@','example.com'))
  Block 'fone' 'telefone' (Join-Parts @('(','11',') ','90000','-','0000'))
  Block 'luhn' 'cartao' (Join-Parts @('4111','1111','1111','1111'))
  Block 'ag' 'agencia' (Join-Parts @('ag','encia ','1234'))
  Block 'conta' 'conta' (Join-Parts @('conta ','12345-6'))
  Block 'iban' 'iban' (Join-Parts @('IBAN ','BR00','000000','000000','000000','000C'))
  Block 'pix' 'pix' (Join-Parts @('pix',': ','fixture-chave'))
  Block 'kw' 'segredo' (Join-Parts @('se','nha: ','fixture'))
  Block 'server' 'segredo' (Join-Parts @('server','=','fixture-host'))
  Block 'datasource' 'segredo' (Join-Parts @('data source','=','fixture'))
  Block 'cs' 'segredo' (Join-Parts @('connection','strings'))
  Block 'jwt' 'segredo' (Join-Parts @('eyJ','abcdefghijk','.','abcdefghijk','.'))
  Block 'pem' 'segredo' (Join-Parts @('-----BEGIN ','PRIVATE KEY-----'))
  Block 'reval' 'revalidar_em' (Join-Parts @('revalidar_em',': 2026-10-26'))

  Allow 'cpf-ruim' (Join-Parts @('529982247','00'))
  Allow 'repetido' (Join-Parts @('111111111','11'))
  Allow 'username' (Join-Parts @('username ','fixture.user'))
  Allow 'limpo' 'Texto limpo de fixture, sem numero.'
  Allow 'luhn-ruim' (Join-Parts @('4111','1111','1111','1112'))
  Allow 'senha-solta' (Join-Parts @('se','nha sem separador'))

  $r = Invoke-Mem @('--sistema','lab','lint')
  if ($r.Code -ne 0) { Fail "lint do lab: $($r.Out)" }
  if ($r.Out -notmatch 'mem lint: 0') { Fail 'lab não ficou limpo' }
  Pass 'lint do lab'

  $sem = @'
---
id: LAB-RN-0098
tipo: regra
titulo: Sem ok
escopo: projeto
tags: [ok]
status: confirmada
fonte: [bot]
dono: revisor-entrega
criado: 2026-10-26
atualizado: 2026-10-26
gatilhos: []
---
Sem marcador.
'@
  [IO.File]::WriteAllText((Join-Path $Lab 'projeto/confirmada-sem.md'), (($sem -replace "`r`n","`n") + "`n"), [Text.UTF8Encoding]::new($false))
  $r = Invoke-Mem @('--sistema','lab','lint')
  Write-Output $r.Out
  if ($r.Code -eq 0) { Fail 'confirmada sem ok deveria falhar' }
  if ($r.Out -notmatch 'confirmada-sem-ok') { Fail 'classe confirmada-sem-ok' }
  Remove-Item (Join-Path $Lab 'projeto/confirmada-sem.md') -Force
  $ok = @'
---
id: LAB-RN-0097
tipo: regra
titulo: Com ok
escopo: projeto
tags: [ok]
status: confirmada
fonte: [bot]
dono: revisor-entrega
confirmado_por: matheus: ok
criado: 2026-10-26
atualizado: 2026-10-26
gatilhos: []
---
Com marcador.
'@
  $okPath = Join-Path $Lab 'projeto/confirmada-ok.md'
  [IO.File]::WriteAllText($okPath, (($ok -replace "`r`n","`n") + "`n"), [Text.UTF8Encoding]::new($false))
  $r = Invoke-Mem @('--sistema','lab','lint')
  if ($r.Code -ne 0) { Fail "confirmada com ok: $($r.Out)" }
  Pass 'confirmada só com ok do Matheus'

  $extra = Join-Parts @("`n",'server','=','fixture')
  [IO.File]::AppendAllText($okPath, $extra, [Text.UTF8Encoding]::new($false))
  $r = Invoke-Mem @('--sistema','lab','index')
  Write-Output $r.Out
  if ($r.Code -eq 0) { Fail 'index deveria abortar' }
  if ($r.Out -notmatch 'index abortado') { Fail 'mensagem de aborto do index' }
  if ($r.Out -notmatch 'segredo') { Fail 'index sem a classe' }
  Pass 'index aborta com lint'

  Write-Output '== C08 gitignore =='
  $prot = Join-Path $Tmp 'protegido'
  New-Item -ItemType Directory -Path $prot | Out-Null
  & git -C $prot init -q
  $gi = Join-Path $prot '.gitignore'
  $prefix = [byte[]](0xEF,0xBB,0xBF) + [Text.Encoding]::UTF8.GetBytes("# custom`r`nkeep`r`n")
  [IO.File]::WriteAllBytes($gi, $prefix)
  & $Pwsh -NoProfile -File $Protect -RepoPath $prot
  if ($LASTEXITCODE -ne 0) { Fail 'protect falhou' }
  $once = [IO.File]::ReadAllBytes($gi)
  & $Pwsh -NoProfile -File $Protect -RepoPath $prot
  $twice = [IO.File]::ReadAllBytes($gi)
  if ($once.Length -ne $twice.Length) { Fail 'segunda proteção alterou o arquivo' }
  for ($i = 0; $i -lt $prefix.Length; $i++) { if ($twice[$i] -ne $prefix[$i]) { Fail 'protect alterou o prefixo' } }
  for ($i = 0; $i -lt $once.Length; $i++) { if ($once[$i] -ne $twice[$i]) { Fail 'protect não é idempotente' } }
  $lines = [Text.Encoding]::UTF8.GetString($twice) -split '\r?\n'
  foreach ($line in @('Planejamento/','planejamento/','conhecimento/')) {
    $n = @($lines | Where-Object { $_ -ceq $line }).Count
    if ($n -ne 1) { Fail "$line apareceu $n vezes no protect" }
  }
  Pass 'protect idempotente e preserva BOM/CRLF'

  $inst = Join-Path $Tmp 'instalado'
  New-Item -ItemType Directory -Path $inst | Out-Null
  & git -C $inst init -q
  & $Pwsh -NoProfile -File $Install -RepoPath $inst -Profile core -Confirm:$false
  $snap = [IO.File]::ReadAllBytes((Join-Path $inst '.gitignore'))
  & $Pwsh -NoProfile -File $Install -RepoPath $inst -Profile core -Confirm:$false
  $again = [IO.File]::ReadAllBytes((Join-Path $inst '.gitignore'))
  if ($snap.Length -ne $again.Length) { Fail 'segunda instalação alterou o .gitignore' }
  for ($i = 0; $i -lt $snap.Length; $i++) { if ($snap[$i] -ne $again[$i]) { Fail 'segunda instalação alterou o .gitignore' } }
  $ilines = [Text.Encoding]::UTF8.GetString($again) -split '\r?\n'
  foreach ($line in @('Planejamento/','planejamento/','conhecimento/')) {
    $n = @($ilines | Where-Object { $_ -ceq $line }).Count
    if ($n -ne 1) { Fail "$line apareceu $n vezes na instalação" }
  }
  Pass 'instalador idempotente'
  Write-Output 'TEST_MEMORIA_PS1_OK'
} finally {
  if ($Tmp -like (Join-Path ([IO.Path]::GetTempPath()) 'ef-mem-*') -and (Test-Path -LiteralPath $Tmp)) {
    Remove-Item -LiteralPath $Tmp -Recurse -Force
  }
}
