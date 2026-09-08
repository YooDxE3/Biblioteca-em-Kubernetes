$ErrorActionPreference='Stop'
$raiz=Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $raiz
New-Item -ItemType Directory -Force -Path evidencias,.runtime,tools|Out-Null
function Executar([string]$Programa,[string[]]$Argumentos,[string]$Log='') {
  $preferencia=$ErrorActionPreference
  $ErrorActionPreference='Continue'
  if($Log){ & $Programa @Argumentos 2>&1 | Tee-Object -FilePath $Log | Out-Host }
  else { & $Programa @Argumentos 2>&1 | Out-Host }
  $codigo=$LASTEXITCODE
  $ErrorActionPreference=$preferencia
  if($codigo -ne 0){throw "Falha em $Programa (codigo $codigo). Consulte o log acima."}
}
function EsperarAplicacao([string]$Url) {
  for($i=0;$i -lt 90;$i++){
    try {if((Invoke-WebRequest "$Url/login" -UseBasicParsing -TimeoutSec 4).StatusCode -eq 200){return}}catch{}
    Start-Sleep -Seconds 3
  }
  throw "Aplicacao nao respondeu em $Url. Consulte os logs."
}
try {
  Executar 'docker' @('version') 'evidencias/docker-version.txt'
  $anteriores=@(docker ps -a --filter 'label=trabalho=biblioteca-t3' --format '{{.Names}}')
  if($LASTEXITCODE -ne 0){throw 'Nao foi possivel listar os containers do trabalho.'}
  if($anteriores -contains 'biblioteca-t3-docker') {
    Executar 'docker' @('logs','biblioteca-t3-docker') 'evidencias/docker-tentativa-anterior.txt'
    Executar 'docker' @('rm','-f','biblioteca-t3-docker') 'evidencias/reinicio-container.txt'
  }
  foreach($porta in @(18080,18081)) {
    $ocupada=Get-NetTCPConnection -LocalPort $porta -State Listen -ErrorAction SilentlyContinue
    if($ocupada){throw "Porta $porta ocupada. Encerre a demo anterior ou o programa que a utiliza."}
  }
  if(-not (Test-Path tools/kind.exe)) {
    $url='https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-windows-amd64'
    Invoke-WebRequest $url -OutFile tools/kind.exe -UseBasicParsing
    $soma=(Invoke-WebRequest "$url.sha256sum" -UseBasicParsing).Content.Split(' ')[0].Trim()
    if((Get-FileHash tools/kind.exe -Algorithm SHA256).Hash.ToLower() -ne $soma.ToLower()){throw 'Checksum do kind invalido.'}
  }
  $env:KUBECONFIG=Join-Path $raiz '.runtime/kubeconfig'
  $env:KIND_EXPERIMENTAL_PROVIDER='docker'
  $bytes=New-Object byte[] 32
  $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
  $rng.GetBytes($bytes);$rng.Dispose()
  $segredo=[Convert]::ToBase64String($bytes)
  $env:API_SECURITY_TOKEN_SECRET=$segredo
  $envFile=Join-Path $raiz '.runtime/docker.env'
  [IO.File]::WriteAllText($envFile,"API_SECURITY_TOKEN_SECRET=$segredo`n")
  Executar 'docker' @('build','--platform','linux/amd64','--progress','plain','-t','biblioteca:1.0','.') 'evidencias/docker-build.txt'
  Executar 'docker' @('image','ls','biblioteca') 'evidencias/docker-image.txt'
  Executar 'docker' @('history','biblioteca:1.0') 'evidencias/docker-history.txt'
  Executar 'docker' @('run','-d','--name','biblioteca-t3-docker','--label','trabalho=biblioteca-t3','-p','127.0.0.1:18080:8080','--env-file',$envFile,'biblioteca:1.0') 'evidencias/docker-run.txt'
  Remove-Item -LiteralPath $envFile
  EsperarAplicacao 'http://127.0.0.1:18080'
  & "$PSScriptRoot/testar-api.ps1" -BaseUrl 'http://127.0.0.1:18080' -Destino 'evidencias/docker-api.json'
  Executar 'docker' @('logs','biblioteca-t3-docker') 'evidencias/docker-app.txt'
  Executar '.\tools\kind.exe' @('create','cluster','--name','biblioteca-t3','--config','k8s/kind.yaml','--kubeconfig',$env:KUBECONFIG,'--wait','300s') 'evidencias/kind-create.txt'
  Executar '.\tools\kind.exe' @('load','docker-image','biblioteca:1.0','--name','biblioteca-t3')
  Executar 'kubectl' @('apply','-f','k8s/namespace.yaml')
  $secretObj=@{apiVersion='v1';kind='Secret';metadata=@{name='biblioteca-secret';namespace='biblioteca-t3'};type='Opaque';stringData=@{'jwt-secret'=$segredo}}
  $secretObj|ConvertTo-Json -Depth 6|kubectl apply -f -
  if($LASTEXITCODE -ne 0){throw 'Falha ao criar Secret'}
  Executar 'kubectl' @('apply','-f','k8s/deployment.yaml','-f','k8s/service-local.yaml')
  Executar 'kubectl' @('-n','biblioteca-t3','rollout','status','deployment/biblioteca','--timeout=300s') 'evidencias/k8s-rollout.txt'
  EsperarAplicacao 'http://127.0.0.1:18081'
  & "$PSScriptRoot/testar-api.ps1" -BaseUrl 'http://127.0.0.1:18081' -Destino 'evidencias/kubernetes-api.json'
  Executar 'kubectl' @('get','nodes','-o','wide') 'evidencias/k8s-nodes.txt'
  Executar 'kubectl' @('-n','biblioteca-t3','get','deployment,pods,svc','-o','wide') 'evidencias/k8s-recursos.txt'
  Executar 'kubectl' @('-n','biblioteca-t3','logs','deployment/biblioteca') 'evidencias/k8s-app.txt'
  [pscustomobject]@{data=(Get-Date -Format o);docker='validado';kubernetes='validado';nuvens='nao executadas'}|ConvertTo-Json|Set-Content -Encoding UTF8 evidencias/status-local.json
  Write-Host 'Demo pronta: Docker http://localhost:18080 e Kubernetes http://localhost:18081'
  Write-Host 'Login: admin / admin. Para encerrar, use ENCERRAR-DEMO.cmd.'
} catch {
  $_|Out-String|Set-Content -Encoding UTF8 evidencias/erro-inicializacao.txt
  Write-Host $_ -ForegroundColor Red
  Write-Host 'A execucao parou. Os recursos ja criados podem ser removidos com ENCERRAR-DEMO.cmd.'
  exit 1
} finally {
  Remove-Item Env:API_SECURITY_TOKEN_SECRET -ErrorAction SilentlyContinue
  if(Test-Path '.runtime/docker.env'){Remove-Item -LiteralPath '.runtime/docker.env'}
}
