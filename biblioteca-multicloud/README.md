# Biblioteca — trabalho de deploy multicloud

Entrega: 10/09/2026. Escopo combinado: demonstração local e tutoriais escritos de AWS EKS, Google GKE e DigitalOcean com K3s.

| Integrante | RA |
|---|---|
| Andre Luiz de Oliveira Zampieri | 14623 |
| Gabriel Henrique Friedrichsen | 14552 |
| Hendreu Satoshi Zampieri Itami | 240061 |

## Comece por aqui

- RELATORIO.pdf: documento para leitura e revisão.
- RELATORIO.docx: versão editável, com a identificação do grupo.
- docs/: tutoriais, comparação de custos e roteiro de apresentação de 8–10 minutos em base-local.md.
- evidencias/: logs e capturas reais; diagnostico.md explica a pendência do Docker.
- Dockerfile, src/, k8s/, cloud/ e scripts/: código e configuração da demonstração.

## Estado real

O build Java e os oito testes da API em Docker passaram. O Kubernetes local também foi validado: nó Ready, Deployment com 1/1 disponível, oito testes da API aprovados e capturas da interface, incluindo bloqueio de permissões. O escopo combinado de demonstração local e tutoriais escritos está concluído. A substituição das implantações em nuvem pela demonstração local e pelos tutoriais escritos foi autorizada pelo professor, conforme confirmação da equipe. AWS, GCP e VPS permanecem como tutoriais não executados, de acordo com essa autorização.

## Executar a demonstração

1. Extraia o ZIP inteiro para uma pasta; não abra apenas o CMD nem execute dentro do ZIP.
2. Abra o Docker Desktop e aguarde o mecanismo Linux ficar disponível. Tenha kubectl no PATH e acesso à internet para baixar imagens e dependências. O kind acompanha o pacote.
3. Se existir uma demonstração anterior deste trabalho, execute ENCERRAR-DEMO.cmd antes de iniciar outra. Isso remove os recursos temporários da Biblioteca e seus dados H2.
4. Execute INICIAR-DEMO.cmd nessa pasta. Ele compila, testa, inicia Docker e tenta criar o Kubernetes local, salvando os registros em evidencias/.
5. Após sucesso, abra http://localhost:18080 (Docker) e http://localhost:18081 (Kubernetes). Login acadêmico: admin / admin; usuário comum: user / user.
6. Ao terminar, execute ENCERRAR-DEMO.cmd. Os dados da aplicação ficam em memória e não persistem ao reiniciar.

Não use reset de fábrica para solucionar o erro sem antes proteger os dados dos outros projetos existentes no Docker. O relatório registra as evidências disponíveis na sua geração; se novas execuções forem realizadas, atualize também o documento editável e as capturas.

## Antes de entregar

- Conferir as evidências reais de Docker e Kubernetes na pasta evidencias.
- Reconsultar os preços oficiais em 10/09/2026; as estimativas atuais foram consultadas em 07/09/2026.
- Revisar o texto e ensaiar o roteiro entre os três integrantes.
- Não incluir .runtime, kubeconfig, tokens ou segredos na entrega.



