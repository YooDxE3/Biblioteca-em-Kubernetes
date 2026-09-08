param([string]$BaseUrl='http://127.0.0.1:8080', [string]$Destino='evidencias/api.json')
$ErrorActionPreference='Stop'
$resultados = [System.Collections.Generic.List[object]]::new()
function Registrar($nome,$ok,$detalhe) {
  $resultados.Add([pscustomobject]@{teste=$nome;aprovado=[bool]$ok;detalhe=$detalhe})
  if(-not $ok){throw "Falhou: $nome ($detalhe)"}
}
try {
  $pagina=Invoke-WebRequest "$BaseUrl/login" -UseBasicParsing
  Registrar 'Pagina de login' ($pagina.StatusCode -eq 200) "HTTP $($pagina.StatusCode)"
  try { Invoke-WebRequest "$BaseUrl/api/autores" -UseBasicParsing | Out-Null; $codigo=200 }
  catch { $codigo=[int]$_.Exception.Response.StatusCode }
  Registrar 'API sem token bloqueada' ($codigo -eq 401) "HTTP $codigo"
  $auth=Invoke-RestMethod "$BaseUrl/api/auth/login" -Method Post -ContentType 'application/json' -Body '{"username":"admin","password":"admin"}'
  Registrar 'Login JWT' (-not [string]::IsNullOrWhiteSpace($auth.token)) 'Token recebido; valor omitido'
  $headers=@{Authorization="Bearer $($auth.token)"}
  $autor=Invoke-RestMethod "$BaseUrl/api/autores" -Headers $headers -Method Post -ContentType 'application/json' -Body '{"nome":"Machado de Assis","nacionalidade":"Brasileira"}'
  Registrar 'Cadastrar autor' ($autor.id -gt 0) "Autor ID $($autor.id)"
  $body=@{titulo='Dom Casmurro';isbn='9788535914849';anoPublicacao=1899;autor=@{id=$autor.id}}|ConvertTo-Json -Depth 4
  $livro=Invoke-RestMethod "$BaseUrl/api/livros" -Headers $headers -Method Post -ContentType 'application/json' -Body $body
  Registrar 'Cadastrar livro' ($livro.id -gt 0) "Livro ID $($livro.id)"
  $autores=Invoke-RestMethod "$BaseUrl/api/autores" -Headers $headers
  $livros=Invoke-RestMethod "$BaseUrl/api/livros" -Headers $headers
  Registrar 'Consultar autores' (@($autores).id -contains $autor.id) 'Registro localizado'
  Registrar 'Consultar livros' (@($livros).id -contains $livro.id) 'Registro localizado'
  $user=Invoke-RestMethod "$BaseUrl/api/auth/login" -Method Post -ContentType 'application/json' -Body '{"username":"user","password":"user"}'
  Registrar 'Login JWT de usuario comum' (-not [string]::IsNullOrWhiteSpace($user.token)) 'Token recebido; valor omitido'
} finally {
  [pscustomobject]@{data=(Get-Date -Format o);url=$BaseUrl;testes=$resultados}|ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $Destino
}
Write-Host 'Testes da API aprovados.'
