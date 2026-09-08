# Objetivo, escopo e aplicação

Este trabalho apresenta a aplicação Biblioteca em contêiner e organiza três procedimentos de implantação: AWS EKS, Google Cloud GKE e DigitalOcean com K3s. A modalidade adotada pela equipe combina **demonstração local** com **tutoriais escritos para os provedores**. Nenhuma conta de nuvem foi utilizada; resultados esperados nos tutoriais não são apresentados como execução real.

Conforme autorização do professor, confirmada pela equipe, as implantações reais nos provedores foram substituídas pela demonstração local em Docker e Kubernetes e pelos tutoriais escritos de AWS, Google Cloud e DigitalOcean. Esta entrega atende a essa modalidade autorizada. As evidências documentam a execução local; os procedimentos de nuvem são roteiros de implantação e não registros de execução.

## Projeto e versão

- Origem: [dpRanghetti/biblioteca](https://github.com/dpRanghetti/biblioteca).
- Commit de referência: `5a409647ab7277212b7b5ce5237d44ab04323d1d`.
- Spring Boot 4.0.6, Java 21, Maven Wrapper 3.3.4 com distribuição Maven 3.9.15.
- Interface Thymeleaf; API REST com JWT; Spring Data JPA; H2 2.4.240 observado na execução.
- Porta interna: 8080. Banco: `jdbc:h2:mem:banco`.

A alteração de configuração remove o segredo JWT de exemplo das propriedades e exige `API_SECURITY_TOKEN_SECRET` no ambiente. O código de negócio original foi preservado. Os novos arquivos tratam da construção, implantação, testes e documentação. O pacote contém o código necessário e não depende de um repositório da equipe já publicado.

## Arquitetura

Na execução Docker, o navegador acessa `localhost:18080`, mapeado para a porta 8080 do container. No Kubernetes local, `localhost:18081` é encaminhado ao NodePort 30080 do nó kind, ao Service e ao Pod da Biblioteca. Em ambos, o H2 vive dentro do processo Java.

Nos tutoriais de nuvem, o NLB da AWS e o LoadBalancer do GCP expõem porta 80; a VPS usa `IP:30080`. A imagem permanece a mesma. A troca de endereço do registro e do mecanismo de exposição é uma adaptação de infraestrutura, sem outro build da aplicação.

O banco H2 não é compartilhado entre containers ou ambientes. Reiniciar o processo apaga os dados cadastrados; os usuários iniciais são recriados pela aplicação. Por isso o Deployment usa uma réplica e estratégia `Recreate`, evitando duas instâncias com dados divergentes durante atualização. Essa estratégia implica uma interrupção na troca do Pod.

# Construção e execução Docker

## Pré-requisitos locais

Windows com Docker Desktop em modo de containers Linux, virtualização/WSL2 funcionando, PowerShell e kubectl. O iniciador usa kind 0.33.0 para criar um cluster isolado. Recomenda-se reservar memória suficiente para Docker, nó Kubernetes e build Java; a necessidade efetiva depende dos limites configurados no Docker Desktop. Git é necessário para obter o original, mas o código já está incluído neste pacote.

O Java instalado no Windows não participa do build Docker: a imagem de construção fornece Java 21. Na análise inicial havia Java 8 no PATH; usar esse Java para compilar o projeto seria incompatível com o requisito. Uma distribuição Java 21 portátil foi usada na verificação direta complementar, sem substituir o Java do sistema.

## Execução assistida no Windows

1. Extrair **todo o ZIP** para uma pasta; não baixar somente o arquivo `.cmd`.
2. Abrir o Docker Desktop e aguardar o motor estar pronto.
3. Abrir `INICIAR-DEMO.cmd` dentro da pasta extraída.
4. Aguardar build, testes da API, criação do cluster e Deployment disponível.
5. Acessar `http://localhost:18080/login` (Docker) e `http://localhost:18081/login` (Kubernetes).
6. Entrar com `admin/admin` para administração ou `user/user` para testar permissões.
7. Ao terminar a apresentação e as capturas, abrir `ENCERRAR-DEMO.cmd`.

Os logs ficam em `evidencias/`. O arquivo `.runtime/kubeconfig` permite acesso apenas ao cluster local do trabalho e deve permanecer fora da entrega pública. O iniciador não publica imagens nem cria recursos em nuvem. Uma nova execução recria o container Docker do trabalho; para repetir a demonstração completa, encerrar o cluster anterior antes de iniciar.

## Decisões do Dockerfile

O primeiro estágio usa Temurin JDK 21 e o Maven Wrapper do projeto. `clean verify` executa o teste existente e empacota o JAR. O segredo necessário ao teste é gerado temporariamente durante o build; não é um segredo de execução. O estágio final usa Temurin JRE 21, recebe apenas o JAR e roda com usuário numérico não administrador. `MaxRAMPercentage=65.0` limita a fração da memória que o Java pode dedicar ao heap; a memória total também inclui áreas nativas.

As tags das imagens-base acompanham correções do Java 21. Para repetir exatamente um build já realizado, registrar os digests das imagens-base presentes no log; a tag `21-jre` isolada não garante identidade eterna. A imagem final do trabalho é identificada pela tag e pelo digest observado.

`.dockerignore` exclui credenciais, logs, evidências, ferramentas, documentação e artefatos locais do contexto. O Dockerfile está incluído integralmente no apêndice técnico e no pacote.

## Comandos essenciais — PowerShell

Executar na raiz do projeto. O iniciador automatiza estes passos; não executá-los simultaneamente com ele, pois usam o mesmo nome de container.

```powershell
docker version
docker build --platform linux/amd64 --progress plain -t biblioteca:1.0 .
docker image ls biblioteca
docker history biblioteca:1.0
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
$env:API_SECURITY_TOKEN_SECRET = [Convert]::ToBase64String($bytes)
docker run -d --name biblioteca-t3-docker --label trabalho=biblioteca-t3 `
  -p 127.0.0.1:18080:8080 -e API_SECURITY_TOKEN_SECRET biblioteca:1.0
Remove-Item Env:API_SECURITY_TOKEN_SECRET
docker logs biblioteca-t3-docker
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/testar-api.ps1 `
  -BaseUrl http://127.0.0.1:18080 -Destino evidencias/docker-api.json
```

A criação de arquivos de evidência pressupõe a existência da pasta `evidencias`; o iniciador a cria automaticamente. O valor do segredo não deve aparecer no texto dos comandos, em capturas ou em transcrições.

# Kubernetes local

## Recursos e decisões

| Recurso | Função e escolha |
|---|---|
| Namespace biblioteca-t3 | Agrupa somente os recursos do trabalho |
| Secret biblioteca-secret | Recebe o segredo JWT gerado em memória |
| Deployment biblioteca | Uma réplica e atualização Recreate por causa do H2 |
| Recursos do container | Requests 250m CPU/384Mi; limites 1 CPU/768Mi |
| Startup probe | Verifica /login a cada 5 s, até 60 falhas na inicialização |
| Readiness probe | Verifica quando o Pod pode receber tráfego |
| Liveness probe | Detecta ausência de resposta após a inicialização |
| Service NodePort | Encaminha o tráfego local ao container na porta 8080 |
| Contexto isolado | Kubeconfig dentro de .runtime, sem substituir contexto pessoal |

A resposta HTTP da página `/login` é um sinal simples de saúde para o laboratório, não uma avaliação exaustiva de dependências. A startup probe evita que um início lento seja confundido prematuramente com falha do processo.

## Passos equivalentes — PowerShell

Depois do build da imagem e com o executável `tools/kind.exe` disponível:

```powershell
$env:KUBECONFIG = Join-Path (Get-Location) '.runtime/kubeconfig'
$env:KIND_EXPERIMENTAL_PROVIDER = 'docker'
.\tools\kind.exe create cluster --name biblioteca-t3 `
  --config k8s/kind.yaml --kubeconfig $env:KUBECONFIG --wait 300s
.\tools\kind.exe load docker-image biblioteca:1.0 --name biblioteca-t3
kubectl apply -f k8s/namespace.yaml
```

Criar o Secret antes de aplicar o Deployment. O script do pacote o gera e envia pela entrada padrão, evitando gravar seu valor em YAML de entrega. `k8s/secret.example.yaml` é somente um modelo com marcador, não o Secret utilizado.

```powershell
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
$secret = @{
  apiVersion='v1'; kind='Secret'
  metadata=@{name='biblioteca-secret';namespace='biblioteca-t3'}
  type='Opaque'
  stringData=@{'jwt-secret'=[Convert]::ToBase64String($bytes)}
}
$secret | ConvertTo-Json -Depth 6 | kubectl apply -f -
Remove-Variable secret,bytes
kubectl apply -f k8s/deployment.yaml -f k8s/service-local.yaml
kubectl -n biblioteca-t3 rollout status deployment/biblioteca --timeout=300s
kubectl get nodes
kubectl -n biblioteca-t3 get deployment,pods,service -o wide
kubectl -n biblioteca-t3 logs deployment/biblioteca
```

Não aplicar toda a pasta `k8s/` de uma vez: ela contém Services alternativos, configuração kind e um exemplo de Secret. Selecionar os arquivos do ambiente evita sobrescrever o Service ou usar um marcador como segredo.

No local, `kind load docker-image` disponibiliza a imagem sem registro externo. Isso comprova o uso de imagem no cluster local, mas **não equivale a publicar a imagem num registro**. A publicação está documentada nos três roteiros de nuvem.

# Testes e coleta de evidências

## Matriz de aceitação

| Teste | Resultado esperado |
|---|---|
| Build Maven | Finalização com BUILD SUCCESS e teste existente aprovado |
| Build Docker | Imagem biblioteca:1.0 disponível, histórico registrado |
| Login web admin | Acesso à página inicial e aos usuários |
| Autores | Cadastro e consulta com o nome informado |
| Livros | Cadastro e consulta com vínculo ao autor |
| Permissões | user/user recebe 403 ao acessar /usuarios |
| API sem Bearer | HTTP 401 em /api/autores |
| Login API | Token recebido em POST /api/auth/login |
| API autenticada | Cadastro e consulta de autor/livro com token |
| Kubernetes | Deployment disponível, Pod Running e Ready 1/1 |
| Reinício | Dados anteriores deixam de existir; usuários padrão são recriados |
| Limpeza | Container e cluster do laboratório excluídos ao encerrar |

O script `scripts/testar-api.ps1` salva apenas o resultado dos testes, sem o token. A API retorna 404 quando a lista está vazia; depois de cadastrar, retorna 200 com os registros. Esse comportamento do projeto deve ser distinguido de rota inexistente ou falha do cluster.

## Roteiro manual da interface

Entrar como administrador, abrir Autores e cadastrar um autor. Em Livros, cadastrar título, ISBN, ano e selecionar o autor. Consultar as duas listagens. Abrir Usuários e confirmar a administração disponível. Sair, entrar como usuário comum e acessar `/usuarios` diretamente: o resultado esperado é a página 403. Registrar também que os links administrativos não aparecem para esse usuário.

Usar dados fictícios ou públicos de demonstração. A aplicação possui credenciais acadêmicas padrão; não são adequadas a um serviço publicado para uso real. O console H2 deve ser acessado somente com perfil autorizado.

## Diagnóstico

```powershell
kubectl -n biblioteca-t3 get events --sort-by=.metadata.creationTimestamp
kubectl -n biblioteca-t3 describe deployment biblioteca
kubectl -n biblioteca-t3 describe pod NOME_DO_POD
kubectl -n biblioteca-t3 logs deployment/biblioteca
kubectl -n biblioteca-t3 logs deployment/biblioteca --previous
```

`--previous` só produz logs quando existe uma instância anterior do container. Para Secret ausente, conferir nome e chave; para imagem indisponível, conferir tag, carga no kind ou autenticação do registro. Para falta de memória, procurar OOMKilled. Para acesso externo indisponível com Pod saudável, conferir mapeamento, Service, firewall e endereço.

# Organização da entrega e apresentação

O pacote inclui código da Biblioteca, arquivos Docker, manifestos, scripts locais, três tutoriais e comparação. O PDF reúne o material; a versão DOCX e o Markdown permitem edição. As evidências são locais e identificadas pelo ambiente. Contas, tokens, Secret real e kubeconfig não pertencem ao pacote de entrega.

## Divisão para três integrantes

| Integrante | Responsabilidade sugerida |
|---|---|
| Andre Luiz de Oliveira Zampieri | Docker, execução local e explicação do EKS |
| Gabriel Henrique Friedrichsen | Manifestos Kubernetes e explicação do GKE |
| Hendreu Satoshi Zampieri Itami | VPS/K3s e apresentação da comparação |

Todos devem conhecer a imagem utilizada, a limitação do H2, o fluxo de tráfego, os testes e a justificativa da recomendação. A divisão acima é organizacional; não afirma autoria individual de etapas já executadas.

## Apresentação de 8–10 minutos

| Tempo | Conteúdo |
|---|---|
| 0–1 min | Objetivo, escopo local e três tutoriais |
| 1–3 min | Dockerfile, imagem e aplicação em execução |
| 3–5 min | Pod, Service, login e uma operação na Biblioteca |
| 5–7 min | Diferenças entre EKS, GKE e VPS/K3s |
| 7–9 min | Custos, responsabilidade operacional e recomendação |
| 9–10 min | Limitação do H2, evidências e encerramento |

Preparar a execução antes da apresentação, pois downloads e build não cabem no tempo de exposição. Manter as capturas disponíveis caso o ambiente local precise ser reiniciado. Não usar capturas locais como se fossem acesso às nuvens.

## Conferência final para 10/09/2026

A identificação dos três integrantes e RAs está preenchida. O pacote reúne PDF, DOCX, Markdown, código, manifestos, scripts, tutoriais e evidências da execução local validada. A equipe deve revisar o material e ensaiar a apresentação. Os preços têm data de consulta explícita em 07/09/2026; se a entrega ocorrer em 10/09, reconsultar as fontes nessa data. Um integrante deve enviar o PDF e o ZIP para diogo.p.ranghetti@gmail.com, identificando os três integrantes no corpo da mensagem. Nenhum e-mail foi enviado automaticamente.

## Referências gerais

- [Projeto Biblioteca](https://github.com/dpRanghetti/biblioteca)
- [Docker: builds em múltiplos estágios](https://docs.docker.com/build/building/multi-stage/)
- [Docker: boas práticas de build](https://docs.docker.com/build/building/best-practices/)
- [Kubernetes: Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes: Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Kubernetes: probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [kind: início rápido](https://kind.sigs.k8s.io/docs/user/quick-start/)
- Ranghetti, Diogo P. Aula 06 — Trabalho Prático: Docker, Kubernetes e Comparação de Provedores. Material fornecido à equipe, 62 slides.

## Versão local validada

A execução final utilizou kind v0.33.0 com Kubernetes v1.35.5. A imagem do nó está fixada por digest em k8s/kind.yaml para reproduzir a versão testada. O cliente kubectl utilizado foi v1.36.1.


