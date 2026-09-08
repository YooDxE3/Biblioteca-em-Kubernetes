## Problemas investigados e situação final

**1. Iniciador separado do restante do projeto.** Ao abrir uma cópia isolada de INICIAR-DEMO.cmd na pasta Downloads, o PowerShell informou que scripts/iniciar-local.ps1 não existia. A causa foi a ausência das subpastas junto ao iniciador. A execução a partir da pasta completa alcançou o build e os testes Docker. Extrair o ZIP inteiro antes de executar.

**2. Falha no armazenamento do Docker durante a criação do Kubernetes.** O build e oito verificações da API Docker passaram. Em seguida, o download da imagem do nó kind falhou com `read-only file system` no arquivo interno `io.containerd.metadata.v1.bolt/meta.db`. A falha impediu criar e validar o cluster; não constitui evidência de erro da aplicação Java.

Foi tentado um reinício autorizado do Docker Desktop e o encerramento do seu ambiente WSL. O Docker registrou erro ao preparar o dispositivo interno `/dev/sdd` e, na tentativa seguinte, erro de acesso ao socket `sailor-ingest.sock`. Naquela tentativa, a recuperação não foi concluída. Posteriormente, o usuário recuperou o Docker e uma nova consulta confirmou o mecanismo respondendo e a Biblioteca em execução. Não foi executado reset, exclusão de volumes ou remoção de distribuições WSL. A causa raiz do problema de armazenamento não foi confirmada.

O computador também apresentava pouco espaço livre no disco C: durante a investigação. Isso é um fator a investigar, não uma causa comprovada. Foram removidos somente downloads e ferramentas temporárias criados para este trabalho.

**3. Imagem do nó não executável após a recuperação.** Na nova tentativa, o nó kind falhou com `exec /usr/local/bin/entrypoint: exec format error`. A imagem informa Linux/amd64, compatível com o host x86_64, mas executar /bin/sh nela também falhou. Recarregar a mesma imagem não resolveu. A causa raiz não está confirmada. O nó temporário malsucedido foi removido; os volumes dos demais projetos foram preservados.

**Resolução e validação final:** após liberar espaço, o disco C: apresentou 8.888.406.016 bytes livres. Foi baixada uma nova imagem oficial Linux/amd64, kindest/node v1.35.5, fixada por digest em k8s/kind.yaml. Com essa imagem, o cluster foi criado, o nó ficou Ready, o Deployment atingiu 1/1 disponível e os oito testes da API passaram em http://127.0.0.1:18081. As capturas registram login, autores, livros, administração e bloqueio 403 para usuário comum. A troca da imagem resolveu a falha de execução observada; não prova a causa raiz da imagem anterior. As nuvens continuam como tutoriais não executados.

Os logs kind-create.txt, k8s-rollout.txt, k8s-nodes.txt, k8s-recursos.txt e kubernetes-api.json registram a execução final. O arquivo erro-inicializacao.txt é histórico da tentativa anterior, não o estado atual. O estado final consta em status-local.json.

