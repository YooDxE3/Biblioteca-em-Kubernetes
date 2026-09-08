# Tutorial 1 — AWS: EKS, ECR e Network Load Balancer

**Status: roteiro documentado, não executado em conta AWS.** Os resultados descritos são critérios de validação esperados. Não existem IPs, capturas ou tempos de implantação medidos na AWS neste trabalho.

## 1. Ambiente e pré-requisitos

Região: `us-east-1` (Norte da Virgínia). EKS convencional, versão 1.35 em suporte padrão; um nó gerenciado `t3.medium` (2 vCPUs, 4 GiB), Amazon Linux 2023, x86-64 e disco gp3 de 20 GiB. A VPC ocupa duas zonas; existe apenas um nó de aplicação. Não há alta disponibilidade da aplicação.

Em uma execução futura, usar uma conta com faturamento e permissões para EKS, EC2/VPC, CloudFormation, IAM, ECR e ELB. Instalar AWS CLI v2, eksctl, kubectl, Helm, Docker, curl e OpenSSL. Os blocos deste tutorial usam **Bash** (Linux/WSL), não PowerShell. Executar a partir da raiz do pacote. Consultar as versões compatíveis na documentação oficial e registrar `aws --version`, `eksctl version`, `kubectl version --client`, `helm version` e `docker version`.

Autenticar pelo método institucional/SSO da conta. Não colocar chaves nos arquivos entregues. Exemplo de configuração por SSO:

```bash
aws configure sso
aws sso login --profile SEU_PERFIL
export AWS_PROFILE=SEU_PERFIL
export AWS_REGION=us-east-1
export CLUSTER=biblioteca-t3
aws sts get-caller-identity
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
export IMAGE="$ECR/biblioteca:1.0"
```

Substituir `SEU_PERFIL` pelo perfil configurado. A identidade exibida deve pertencer à conta de laboratório pretendida.

## 2. Publicar a imagem já construída

Usar a imagem `biblioteca:1.0` validada localmente; não realizar outro build. Se este terminal usa outro motor Docker, transferir a imagem com `docker save` e `docker load` antes desta etapa.

```bash
aws ecr create-repository --repository-name biblioteca --region "$AWS_REGION"
aws ecr get-login-password --region "$AWS_REGION" |
  docker login --username AWS --password-stdin "$ECR"
docker tag biblioteca:1.0 "$IMAGE"
docker push "$IMAGE"
aws ecr describe-images --repository-name biblioteca \
  --image-ids imageTag=1.0 --region "$AWS_REGION"
```

Registrar o digest da imagem. O repositório ECR é privado. O grupo de nós criado pelo eksctl deve possuir permissão de pull do ECR; confirmar as políticas do papel IAM do nó em caso de `ImagePullBackOff`.

## 3. Criar o cluster

O arquivo `cloud/eks-cluster.yaml` define um nó e desabilita o NAT Gateway. Os nós ficam em sub-redes públicas para o laboratório, com SSH desabilitado. A API e os grupos de segurança devem ser revistos antes de qualquer uso de produção. A escolha reduz componentes cobrados e precisa constar da comparação.

```bash
aws eks describe-cluster-versions --region "$AWS_REGION"
eksctl create cluster -f cloud/eks-cluster.yaml
aws eks update-kubeconfig --name "$CLUSTER" --region "$AWS_REGION"
kubectl config current-context
kubectl get nodes -o wide
```

Antes de criar, confirmar que a versão 1.35 aparece como disponível e em suporte padrão. Se indisponível, escolher uma versão suportada, atualizar o YAML e registrar a alteração. Não deixar a versão entrar em suporte estendido na projeção de preços.

## 4. Instalar o controlador de balanceamento

O Service deste pacote exige o **AWS Load Balancer Controller**. Um Service isolado não instala o controlador. A receita abaixo fixa o chart 1.14.0 e a política da versão 2.14.1, conforme a referência consultada. Confirmar compatibilidade se a versão do cluster for alterada.

```bash
curl -fsSLo /tmp/biblioteca-lbc-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json
aws iam create-policy --policy-name BibliotecaT3LoadBalancerPolicy \
  --policy-document file:///tmp/biblioteca-lbc-policy.json
eksctl create iamserviceaccount --cluster "$CLUSTER" \
  --region "$AWS_REGION" --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/BibliotecaT3LoadBalancerPolicy" \
  --approve
export VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" \
  --region "$AWS_REGION" --query cluster.resourcesVpcConfig.vpcId --output text)
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller --version 1.14.0 \
  --namespace kube-system \
  --set clusterName="$CLUSTER" \
  --set region="$AWS_REGION" --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set replicaCount=1 \
  --set controllerConfig.featureGates.ALBGatewayAPI=false \
  --set controllerConfig.featureGates.NLBGatewayAPI=false
kubectl -n kube-system rollout status deployment/aws-load-balancer-controller \
  --timeout=300s
```

O Gateway API fica desabilitado porque este laboratório usa Service de camada 4. A opção evita introduzir CRDs de Gateway que não fazem parte da arquitetura. A réplica única do controlador é uma escolha de laboratório; não representa uma configuração resiliente.

## 5. Implantar e acessar

```bash
bash scripts/aplicar-nuvem.sh aws "$IMAGE"
kubectl -n biblioteca-t3 get service biblioteca -w
```

Interromper a observação com Ctrl+C quando surgir o hostname externo. Abrir `http://HOSTNAME_DO_NLB/login`. O Service usa porta pública 80, destino 8080 e NLB voltado à internet; o balanceamento entre zonas está habilitado para atender à arquitetura com apenas um nó. O valor do Secret é gerado em memória pelo script.

## 6. Validar e registrar

```bash
kubectl -n biblioteca-t3 get deployment,pods,service -o wide
kubectl -n biblioteca-t3 describe deployment biblioteca
kubectl -n biblioteca-t3 logs deployment/biblioteca
kubectl -n biblioteca-t3 get events --sort-by=.metadata.creationTimestamp
```

Resultados esperados: Deployment disponível 1/1, Pod Running e Ready 1/1, hostname externo, login `admin/admin`, cadastro e consulta de um autor e livro. Validar também a API e o bloqueio de `/usuarios` para `user/user`, conforme a matriz de testes do documento. Registrar região, imagem, nó, telas e logs sem segredos. Medir o tempo real somente se o roteiro for executado.

## 7. Limpeza

Excluir primeiro o Service enquanto o controlador ainda está funcionando e aguardar a remoção do NLB no painel EC2/Load Balancers. Isso permite que o controlador libere balanceador, interfaces e endereços associados.

```bash
kubectl -n biblioteca-t3 delete service biblioteca --wait=true
kubectl delete namespace biblioteca-t3
helm uninstall aws-load-balancer-controller -n kube-system
eksctl delete iamserviceaccount --cluster "$CLUSTER" --region "$AWS_REGION" \
  --namespace kube-system --name aws-load-balancer-controller
eksctl delete cluster --name "$CLUSTER" --region "$AWS_REGION" --wait
aws ecr delete-repository --repository-name biblioteca \
  --region "$AWS_REGION" --force
aws iam delete-policy \
  --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/BibliotecaT3LoadBalancerPolicy"
```

Esses comandos destinam-se exclusivamente aos recursos criados para este roteiro. Conferir CloudFormation, EKS, instâncias, volumes EBS, NLBs, interfaces de rede, endereços públicos e ECR. Apagar também um eventual provedor OIDC órfão somente depois de confirmar que pertence a este cluster e não é utilizado por outro recurso. Não usar remoções abrangentes de recursos da conta.

## Referências

- [EKS: nós gerenciados](https://docs.aws.amazon.com/eks/latest/eksctl/nodegroup-managed.html)
- [eksctl: VPC e NAT Gateway](https://docs.aws.amazon.com/eks/latest/eksctl/vpc-configuration.html)
- [AWS Load Balancer Controller com Helm](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html)
- [Network Load Balancers no EKS](https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html)
- [Preços do EKS](https://aws.amazon.com/eks/pricing/)
