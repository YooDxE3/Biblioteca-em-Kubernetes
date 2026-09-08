# Tutorial 3 — DigitalOcean Droplet com K3s

**Status: roteiro documentado, não executado em VPS.** As verificações abaixo descrevem resultados esperados.

## 1. Configuração proposta

DigitalOcean, região `nyc3` (Nova York), Droplet Basic Regular de 2 vCPUs, 4 GiB de RAM, SSD de 80 GiB e franquia de transferência de 4.000 GiB. Sistema Ubuntu 24.04 LTS x86-64. Um único servidor executa o controle do Kubernetes e a aplicação. Não é o produto DOKS gerenciado.

Em uma execução futura, criar o Droplet pelo painel: Create → Droplets → Ubuntu 24.04 LTS → Basic/Regular → plano 2 vCPUs/4 GiB → NYC3 → autenticação por chave SSH → nome `biblioteca-t3`. Não habilitar backups pagos no cenário base. Registrar o preço mostrado antes da criação e conferir a disponibilidade do plano na região.

Criar um Cloud Firewall e associá-lo ao Droplet. Entrada: TCP 22 somente do IP administrativo e TCP 30080 somente dos IPs usados para a demonstração. Saída: permitir o tráfego necessário para DNS, atualizações e pull das imagens. Não abrir a API Kubernetes 6443 nem as portas internas do K3s para a internet; usar `kubectl` via SSH. Para uma demonstração pública sem restrição de origem, a exposição e os riscos das credenciais acadêmicas precisariam ser revistos.

## 2. Publicar a imagem e transferir arquivos

Usar Bash em Linux/WSL. Criar no Docker Hub um repositório público `biblioteca` dentro do usuário da equipe. A publicação futura pressupõe permissão para distribuir o código fornecido pelo professor; para repositório privado, configurar pull autenticado. Não publicar chaves ou o Secret.

```bash
export DOCKERHUB_USER=SUBSTITUIR_PELO_USUARIO
export VPS_IP=SUBSTITUIR_PELO_IPV4
export IMAGE="docker.io/$DOCKERHUB_USER/biblioteca:1.0"
docker login
docker tag biblioteca:1.0 "$IMAGE"
docker push "$IMAGE"
ssh root@"$VPS_IP" 'mkdir -p /opt/biblioteca-t3'
scp -r k8s scripts root@"$VPS_IP":/opt/biblioteca-t3/
ssh root@"$VPS_IP"
```

O build não é repetido na VPS. `scp` copia somente os manifestos e scripts, sem credenciais locais. Se usar Windows sem WSL, executar `ssh`/`scp` no PowerShell adaptando as variáveis.

## 3. Instalar o K3s

Os próximos comandos são executados **dentro da VPS**, como administrador:

```bash
apt-get update
apt-get install -y curl ca-certificates openssl
curl -fsSL https://get.k3s.io -o /tmp/install-k3s.sh
less /tmp/install-k3s.sh
INSTALL_K3S_CHANNEL=stable sh /tmp/install-k3s.sh \
  --disable traefik --disable servicelb
kubectl get nodes -o wide
k3s --version
cd /opt/biblioteca-t3
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export IMAGE=docker.io/SUBSTITUIR_PELO_USUARIO/biblioteca:1.0
bash scripts/aplicar-nuvem.sh vps "$IMAGE"
```

O canal stable resolve uma versão na data de execução; registrar `k3s --version` e, para repetição exata, substituir por `INSTALL_K3S_VERSION` com a versão registrada. Traefik e ServiceLB ficam desabilitados porque a exposição escolhida é NodePort. O K3s já inclui containerd e kubectl; não é necessário instalar Docker no servidor.

## 4. Acesso e evidências

Abrir `http://IP_DA_VPS:30080/login` a partir de um IP autorizado no firewall. O mesmo manifesto NodePort usado no cluster local encaminha 30080 → Service 80 → container 8080.

```bash
kubectl -n biblioteca-t3 get deployment,pods,service -o wide
kubectl -n biblioteca-t3 logs deployment/biblioteca
kubectl -n biblioteca-t3 get events --sort-by=.metadata.creationTimestamp
```

Verificar Pod Ready 1/1, login, cadastros e API. Um endereço inacessível com Pod saudável costuma exigir conferir firewall, IP, NodePort e regras de rede. Não reiniciar ou reinstalar o cluster sem investigar.

**HTTPS:** esta demonstração usa HTTP. Para publicação continuada, apontar um domínio ao servidor, usar Ingress ou proxy reverso com certificado de uma autoridade reconhecida, configurar renovação e expor 80/443. Esse acréscimo não foi implantado nem incluído no cenário financeiro. O H2 em memória e as credenciais iniciais também precisariam ser substituídos para uso real.

## 5. Limpeza

Dentro da VPS:

```bash
kubectl delete namespace biblioteca-t3
/usr/local/bin/k3s-uninstall.sh
exit
```

No painel DigitalOcean, abrir o Droplet `biblioteca-t3` → Destroy e excluir o servidor. Conferir separadamente volumes, snapshots, backups, IPs reservados e firewall criados para a atividade. Desligar o Droplet não equivale a excluí-lo para fins de cobrança. No Docker Hub, remover a tag/repositório do laboratório se não for mais necessário. Registrar a ausência de recursos ativos no painel, sem dados pessoais de faturamento.

## Referências

- [Criação de Droplets](https://docs.digitalocean.com/products/droplets/how-to/create/)
- [Preços oficiais dos Droplets](https://www.digitalocean.com/pricing/droplets)
- [Cloud Firewalls](https://docs.digitalocean.com/products/networking/firewalls/how-to/configure-rules/)
- [K3s: início rápido](https://docs.k3s.io/quick-start)
- [Requisitos do K3s](https://docs.k3s.io/installation/requirements)
- [Desinstalação do K3s](https://docs.k3s.io/installation/uninstall)
