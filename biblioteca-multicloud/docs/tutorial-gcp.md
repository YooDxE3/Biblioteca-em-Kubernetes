# Tutorial 2 — Google Cloud: GKE Standard e Artifact Registry

**Status: roteiro documentado, não executado em conta Google Cloud.** Resultados e endereços indicados são critérios esperados, não evidências coletadas.

## 1. Ambiente e ferramentas

GKE Standard **zonal**, região `us-central1` (Iowa), zona `us-central1-a`, um nó `e2-medium` (2 vCPUs compartilhadas, 4 GiB), Linux Container-Optimized OS com containerd, x86-64 e disco `pd-standard` de 20 GiB. A escolha Standard permite explicitar o nó para a comparação com EKS e VPS; o Autopilot tem modelo de recursos e cobrança diferente.

Uma execução futura exige projeto com faturamento, permissões para habilitar APIs, criar cluster, gerenciar contas de serviço/IAM e escrever no Artifact Registry. Usar Bash, Google Cloud CLI, `gke-gcloud-auth-plugin`, kubectl, Docker e OpenSSL. Registrar suas versões. No Cloud Shell, enviar o pacote e a imagem previamente criada; não presumir que a imagem do computador exista no Docker do Cloud Shell.

## 2. Definir projeto, APIs e registro

```bash
gcloud auth login
export PROJECT_ID=SUBSTITUIR_PELO_ID_DO_PROJETO
export REGION=us-central1
export ZONE=us-central1-a
export CLUSTER=biblioteca-t3
gcloud config set project "$PROJECT_ID"
gcloud services enable container.googleapis.com \
  artifactregistry.googleapis.com compute.googleapis.com iam.googleapis.com
gcloud artifacts repositories create biblioteca --repository-format=docker \
  --location "$REGION" --description 'Laboratorio Biblioteca T3'
gcloud auth configure-docker "$REGION-docker.pkg.dev"
export IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/biblioteca/biblioteca:1.0"
docker tag biblioteca:1.0 "$IMAGE"
docker push "$IMAGE"
gcloud artifacts docker images list \
  "$REGION-docker.pkg.dev/$PROJECT_ID/biblioteca" --include-tags
```

Substituir apenas o ID do projeto; os demais nomes são os recursos dedicados do laboratório. A imagem é a mesma construída localmente. Registrar digest e tamanho publicado.

## 3. Autorizar os nós a ler o registro

Uma conta de serviço específica torna explícita a permissão de pull e evita depender de permissões automáticas da conta padrão.

```bash
gcloud iam service-accounts create biblioteca-gke \
  --display-name 'Nos do laboratorio Biblioteca'
export NODE_SA="biblioteca-gke@$PROJECT_ID.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$NODE_SA" \
  --role roles/container.defaultNodeServiceAccount
gcloud artifacts repositories add-iam-policy-binding biblioteca \
  --location "$REGION" --member "serviceAccount:$NODE_SA" \
  --role roles/artifactregistry.reader
```

## 4. Criar o cluster

```bash
gcloud compute networks create biblioteca-t3-net --subnet-mode=custom
gcloud compute networks subnets create biblioteca-t3-subnet \
  --network biblioteca-t3-net --region "$REGION" --range 10.20.0.0/24 \
  --secondary-range pods=10.21.0.0/16,services=10.22.0.0/20
gcloud container clusters create "$CLUSTER" --zone "$ZONE" \
  --release-channel regular --num-nodes 1 --machine-type e2-medium \
  --image-type COS_CONTAINERD --disk-type pd-standard --disk-size 20 \
  --service-account "$NODE_SA" --scopes cloud-platform \
  --network biblioteca-t3-net --subnetwork biblioteca-t3-subnet \
  --enable-ip-alias --cluster-secondary-range-name pods \
  --services-secondary-range-name services \
  --logging=NONE --monitoring=NONE
gcloud container clusters get-credentials "$CLUSTER" --zone "$ZONE"
kubectl config current-context
kubectl get nodes -o wide
```

O canal regular seleciona uma versão disponibilizada pelo GKE; registrar a versão efetivamente criada com `gcloud container clusters describe`. Um cluster regional poderia criar nós em várias zonas, alterando substancialmente o custo. O roteiro é zonal, com um nó, sem autoscaling e sem exportação de logs/métricas para serviços pagos. `kubectl logs` continua disponível. A rede dedicada facilita a remoção posterior. O nó usa IP externo; não há Cloud NAT neste cenário.

## 5. Implantar e validar

```bash
bash scripts/aplicar-nuvem.sh gcp "$IMAGE"
kubectl -n biblioteca-t3 get service biblioteca -w
```

Aguardar um IP no campo `EXTERNAL-IP` e interromper com Ctrl+C. Abrir `http://IP_EXTERNO/login`. O LoadBalancer encaminha a porta 80 para 8080. Executar a matriz de testes, salvar a listagem de nós, Deployment/Pod/Service, login, operação na Biblioteca e logs. O IP e os tempos só devem ser registrados como reais após execução.

```bash
kubectl -n biblioteca-t3 get deployment,pods,service -o wide
kubectl -n biblioteca-t3 logs deployment/biblioteca
kubectl -n biblioteca-t3 get events --sort-by=.metadata.creationTimestamp
gcloud container clusters describe "$CLUSTER" --zone "$ZONE" \
  --format='yaml(currentMasterVersion,nodePools)'
```

## 6. Limpeza

```bash
kubectl -n biblioteca-t3 delete service biblioteca --wait=true
kubectl delete namespace biblioteca-t3
gcloud container clusters delete "$CLUSTER" --zone "$ZONE"
gcloud artifacts repositories delete biblioteca --location "$REGION"
gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$NODE_SA" \
  --role roles/container.defaultNodeServiceAccount
gcloud iam service-accounts delete "$NODE_SA"
gcloud compute networks subnets delete biblioteca-t3-subnet --region "$REGION"
gcloud compute networks delete biblioteca-t3-net
```

Conferir que a exclusão do Service removeu encaminhamento e balanceador antes de excluir o cluster. No console, verificar instâncias, discos, endereços reservados, regras de encaminhamento, imagens e redes. Se uma dependência impedir apagar a rede, identificar o recurso remanescente e confirmar que pertence ao laboratório. Não apagar recursos de outro projeto/trabalho.

## Referências

- [Implantação de aplicação no GKE](https://cloud.google.com/kubernetes-engine/docs/deploy-app-cluster)
- [Criação de cluster Standard](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-zonal-cluster)
- [Acesso ao Artifact Registry pelo GKE](https://cloud.google.com/artifact-registry/docs/integrate-gke)
- [Conta de serviço dos nós](https://cloud.google.com/kubernetes-engine/docs/how-to/service-accounts)
- [Preços do GKE](https://cloud.google.com/kubernetes-engine/pricing)
