# Comparação de custos e operação

## Premissas e limites

Consulta: **07/09/2026**, horário de Brasília. Entrega prevista: **10/09/2026**. Reconsultar as fontes no dia da entrega, conforme o enunciado; não alterar a data de consulta sem conferir os preços novamente. Moeda: USD. Não houve contratação nem faturamento real nas nuvens.

O cenário financeiro é uma estimativa do **custo fixo para manter a infraestrutura disponível**, por 730 horas mensais. Inclui um nó de aproximadamente 2 vCPUs/4 GiB, uma réplica da Biblioteca e 1 GiB de imagem armazenada no registro pago. Esse 1 GiB é uma premissa de orçamento, não o tamanho medido da imagem. Não inclui descontos por compromisso, Spot, créditos de inscrição ou franquias promocionais.

A comparação aproxima memória e vCPUs anunciadas, mas não iguala desempenho ou disponibilidade: T3 usa créditos de CPU, E2-medium usa CPU compartilhada e Droplet Basic também compartilha CPU. Na VPS o control plane ocupa a mesma máquina da aplicação; EKS e GKE o executam separadamente. Os discos diferem em capacidade e tecnologia. Nenhuma conclusão de desempenho foi medida nas nuvens.

## Configurações comparadas

| Critério | AWS | Google Cloud | DigitalOcean |
|---|---|---|---|
| Produto | EKS convencional | GKE Standard zonal | Droplet Basic Regular + K3s |
| Região | us-east-1 | us-central1-a | nyc3 |
| Nó | 1 × t3.medium | 1 × e2-medium | 1 × 2 vCPUs / 4 GiB |
| Sistema | Amazon Linux 2023 | COS_CONTAINERD | Ubuntu 24.04 LTS |
| Arquitetura | x86-64 | x86-64 | x86-64 |
| Disco | gp3, 20 GiB | pd-standard, 20 GiB | SSD, 80 GiB incluídos |
| Exposição | NLB em 2 zonas | LoadBalancer regional | NodePort 30080 |
| Registro | ECR privado, 1 GiB | Artifact Registry, 1 GiB | Docker Hub público |

## Estimativa mensal — USD

| Componente | AWS | Google Cloud | DigitalOcean |
|---|---:|---:|---:|
| Gerenciamento do cluster | 73,00 | 73,00 | 0,00 — administrado pela equipe |
| Computação | 30,37 | 24,46 | 24,00 — pacote mensal |
| Disco do nó | 1,60 | 0,80 | Incluído |
| Registro da imagem | 0,10 | 0,10 | 0,00 — plano público |
| Balanceador: parcela fixa | 16,43 | 18,25 | 0,00 — NodePort |
| IPv4 público | 10,95 | 3,65 | Incluído no pacote |
| **Total fixo mensal estimado** | **132,44** | **120,26** | **24,00** |
| **Projeção fixa de laboratório por 3 h** | **0,54** | **0,49** | **0,11** |
| Tempo de implantação | Não medido | Não medido | Não medido |

Os totais usam os valores sem arredondamento intermediário. A projeção de 3 horas rateia disco/registro sobre 730 horas e supõe remoção imediata de todos os recursos ao terminar. É uma aproximação de orçamento, não uma promessa de fatura. Tempo de provisionamento, armazenamento mantido, arredondamentos, tráfego e serviços opcionais podem acrescentar valores.

O Droplet selecionado é um **plano empacotado**, limitado a US$ 24/mês, e não o produto v5 por recurso. Para 3 horas usa-se US$ 0,03571/h. A documentação informa teto de 672 horas mensais para esses planos e cobrança mínima de 60 segundos ou US$ 0,01. Portanto, não se deve multiplicar a tarifa horária por 730 e ignorar o teto mensal.

## Memória de cálculo e fontes

| Item | Tarifa usada | Cálculo mensal | Fonte |
|---|---|---|---|
| EKS suporte padrão | 0,10 / cluster-h | 0,10 × 730 = 73,00 | [EKS](https://aws.amazon.com/eks/pricing/) |
| EC2 t3.medium | 0,0416 / h | 0,0416 × 730 = 30,368 | [AWS: tabela us-east-1](https://docs.aws.amazon.com/prescriptive-guidance/latest/optimize-costs-microsoft-workloads/right-size-selection.html) |
| EBS gp3 | 0,08 / GiB-mês | 20 × 0,08 = 1,60 | [EBS](https://aws.amazon.com/ebs/pricing/) |
| ECR | 0,10 / GiB-mês | 1 × 0,10 = 0,10 | [ECR](https://aws.amazon.com/ecr/pricing/) |
| NLB | 0,0225 / h | 0,0225 × 730 = 16,425 | [ELB](https://aws.amazon.com/elasticloadbalancing/pricing/) |
| IPv4 AWS | 0,005 / IP-h | 3 × 0,005 × 730 = 10,95 | [VPC AWS](https://aws.amazon.com/vpc/pricing/) |
| GKE suporte padrão | 0,10 / cluster-h | 0,10 × 730 = 73,00 | [GKE](https://cloud.google.com/kubernetes-engine/pricing) |
| E2-medium | 0,03350571 / h | 0,03350571 × 730 = 24,4591683 | [Compute Engine, general purpose](https://cloud.google.com/products/compute/pricing/general-purpose) |
| Persistent Disk Standard | 0,04 / GiB-mês | 20 × 0,04 = 0,80 | [Discos GCP](https://cloud.google.com/products/block-storage) |
| Artifact Registry | 0,10 / GiB-mês | 1 × 0,10 = 0,10 | [Artifact Registry](https://cloud.google.com/artifact-registry/pricing) |
| Encaminhamento GCP | 0,025 / h | 0,025 × 730 = 18,25 | [Load Balancing](https://cloud.google.com/load-balancing/pricing) |
| IPv4 do nó GCP | 0,005 / IP-h | 1 × 0,005 × 730 = 3,65 | [VPC GCP](https://cloud.google.com/vpc/network-pricing) |
| Droplet Basic Regular | 24,00 / mês | Pacote com teto mensal | [Droplets](https://www.digitalocean.com/pricing/droplets) |

Na AWS contam-se um IPv4 do nó e dois IPv4 do NLB em duas zonas. No GCP conta-se um IPv4 do nó; o endereço associado à regra de encaminhamento não recebe cobrança adicional de IPv4 nessa categoria. Confirmar a quantidade realmente alocada se o roteiro for executado.

## Custos variáveis e itens fora do cenário

O total fixo considera **zero tráfego de aplicação para fins de cálculo**, para tornar comparável o custo de disponibilidade. Uma demonstração real gera tráfego; adicionar a cobrança medida ou uma hipótese explícita de uso. A ausência dessa parcela na tabela não significa que a rede seja gratuita.

- **AWS:** adicionar NLCU do NLB (US$ 0,006 por NLCU-h na região usada), transferência de dados aplicável e eventuais créditos excedentes de CPU T3. Como sensibilidade, média de 1 NLCU ao longo de 730 horas acrescentaria **US$ 4,38/mês**; não é uma medição nem reserva criada. Não há NAT Gateway no YAML escolhido.
- **Google Cloud:** adicionar processamento do balanceador (US$ 0,008/GiB em cada direção indicada na tarifa) e egress conforme origem/destino/faixa. Não há Cloud NAT no roteiro.
- **DigitalOcean:** há franquia de saída no plano; o excedente informado é US$ 0,01/GiB. A franquia se acumula proporcionalmente ao uso e é compartilhada no nível da equipe; não presumir 4.000 GiB integrais num teste de três horas. Consultar também limites de pull do Docker Hub.
- **DNS, domínio, backups, observabilidade adicional, suporte pago e impostos:** não contratados no cenário. A configuração GKE não exporta logs/métricas; no EKS não se habilitam logs pagos do control plane. Logs de diagnóstico são coletados por kubectl. Impostos e conversão de moeda dependem da contratação.

Fontes: [rede AWS](https://aws.amazon.com/vpc/pricing/), [ELB](https://aws.amazon.com/elasticloadbalancing/pricing/), [rede GCP](https://cloud.google.com/vpc/network-pricing), [regras de cobrança DigitalOcean](https://docs.digitalocean.com/products/droplets/details/pricing/), [limites Docker Hub](https://docs.docker.com/docker-hub/usage/).

## Créditos e gratuidade

Benefícios não foram descontados do total normal. O GKE publica crédito mensal de gerenciamento de até US$ 74,40 por conta de faturamento, aplicável a condições específicas de clusters zonais/Autopilot; a elegibilidade deve ser confirmada. O Artifact Registry possui faixa gratuita de armazenamento. AWS e DigitalOcean podem oferecer créditos de entrada conforme elegibilidade. Essas condições não tornam nós, redes e armazenamento universalmente gratuitos.

O Docker Hub público é uma modalidade de serviço com tarifa zero dentro de seus limites; seu uso foi explicitado no cenário VPS. Uma organização que exija registro privado ou outro plano deve acrescentar esse custo.

## Comparação qualitativa

| Critério | AWS EKS | Google GKE | VPS + K3s |
|---|---|---|---|
| Facilidade | Mais componentes: IAM, VPC, nós e controlador de LB | Integração direta entre cluster, registro e exposição | Instalação inicial curta; rede e sistema ficam com a equipe |
| Kubernetes gerenciado | Control plane gerenciado | Control plane gerenciado | Não; controle e nó administrados pela equipe |
| Escalabilidade | Node groups e autoscaling disponíveis | Node pools e autoscaling disponíveis | Exige ampliar VPS ou adicionar servidores |
| Registro | ECR com IAM dos nós | Artifact Registry com identidade dos nós | Docker Hub público; privado exige autenticação |
| Observabilidade | Logs kubectl; CloudWatch opcional | Logs kubectl; Cloud Logging/Monitoring opcionais | Logs kubectl/journalctl; pilha adicional manual |
| Responsabilidade | Workloads, permissões, configuração e ciclo dos nós | Workloads, IAM, configuração e ciclo dos nós | Também SO, K3s, atualizações, backup e recuperação |
| Vantagem | Integração com o ecossistema AWS e controle de infraestrutura | Integração consistente para Kubernetes e menor parcela fixa que EKS neste recorte | Menor custo fixo e controle direto do servidor |
| Limitação | Mais passos e componentes cobrados | Taxa do cluster e dependências do provedor | Nó único e maior esforço operacional |
| Cenário indicado | Equipe já integrada à AWS | Equipe que procura Kubernetes gerenciado no GCP | Laboratório pequeno e demonstração temporária |

Essas avaliações decorrem da arquitetura e dos procedimentos documentados; não são notas de desempenho ou facilidade medidas em implantações reais nos provedores.

## Recomendação

Para este laboratório temporário da Biblioteca, recomendamos **VPS DigitalOcean com K3s**, caso uma implantação externa venha a ser necessária: apresenta o menor custo fixo estimado neste conjunto e atende ao requisito de executar Kubernetes com uma réplica. A equipe assume a administração do servidor, o que também oferece oportunidade de aprendizagem.

Se o objetivo mudar para um serviço mantido por uma equipe que precisa reduzir o trabalho de administração do control plane, o **GKE** é uma alternativa coerente entre os dois gerenciados deste recorte. O EKS ganha relevância quando a organização já depende dos serviços AWS. A recomendação é específica a este cenário, não um ranking universal.

Em qualquer provedor, a aplicação atual continua demonstrativa: H2 em memória, usuários acadêmicos e uma réplica impedem tratá-la como um serviço de produção persistente e altamente disponível.

## Endereços das fontes de preços

- EKS: https://aws.amazon.com/eks/pricing/

- AWS: tabela us-east-1: https://docs.aws.amazon.com/prescriptive-guidance/latest/optimize-costs-microsoft-workloads/right-size-selection.html

- EBS: https://aws.amazon.com/ebs/pricing/

- ECR: https://aws.amazon.com/ecr/pricing/

- ELB: https://aws.amazon.com/elasticloadbalancing/pricing/

- VPC AWS: https://aws.amazon.com/vpc/pricing/

- GKE: https://cloud.google.com/kubernetes-engine/pricing

- Compute Engine, general purpose: https://cloud.google.com/products/compute/pricing/general-purpose

- Discos GCP: https://cloud.google.com/products/block-storage

- Artifact Registry: https://cloud.google.com/artifact-registry/pricing

- Load Balancing: https://cloud.google.com/load-balancing/pricing

- VPC GCP: https://cloud.google.com/vpc/network-pricing

- Droplets: https://www.digitalocean.com/pricing/droplets

- rede AWS: https://aws.amazon.com/vpc/pricing/

- rede GCP: https://cloud.google.com/vpc/network-pricing

- regras de cobrança DigitalOcean: https://docs.digitalocean.com/products/droplets/details/pricing/

- limites Docker Hub: https://docs.docker.com/docker-hub/usage/
