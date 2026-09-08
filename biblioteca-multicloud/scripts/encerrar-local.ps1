$ErrorActionPreference='Stop'
$raiz=Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $raiz
$env:KUBECONFIG=Join-Path $raiz '.runtime/kubeconfig'
$env:KIND_EXPERIMENTAL_PROVIDER='docker'
if(Test-Path tools/kind.exe){
  & .\tools\kind.exe delete cluster --name biblioteca-t3 --kubeconfig $env:KUBECONFIG
  if($LASTEXITCODE -ne 0){throw 'Nao foi possivel excluir o cluster do trabalho.'}
}
$nomes=@(docker ps -a --filter 'label=trabalho=biblioteca-t3' --format '{{.Names}}')
if($LASTEXITCODE -ne 0){throw 'Docker indisponivel.'}
if($nomes -contains 'biblioteca-t3-docker'){
  docker rm -f biblioteca-t3-docker
  if($LASTEXITCODE -ne 0){throw 'Nao foi possivel remover o container do trabalho.'}
}
New-Item -ItemType Directory -Force -Path evidencias|Out-Null
docker ps -a --filter 'label=trabalho=biblioteca-t3' --format '{{.Names}}'|Set-Content -Encoding UTF8 evidencias/limpeza-containers.txt
"Limpeza executada em $(Get-Date -Format o). Imagens locais preservadas para repetir a demonstracao."|Set-Content -Encoding UTF8 evidencias/limpeza.txt
Write-Host 'Recursos de execucao do trabalho removidos. Os arquivos e as evidencias foram preservados.'
