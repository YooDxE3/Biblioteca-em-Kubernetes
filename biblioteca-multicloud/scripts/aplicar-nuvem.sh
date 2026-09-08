#!/usr/bin/env bash
# Execute da raiz do projeto, depois de selecionar explicitamente o contexto.
set -euo pipefail
PROVEDOR="${1:?Informe aws, gcp ou vps}"
IMAGEM="${2:?Informe o caminho da imagem publicada}"
case "$PROVEDOR" in
  aws) SERVICE=k8s/service-aws.yaml;;
  gcp) SERVICE=k8s/service-gcp.yaml;;
  vps) SERVICE=k8s/service-local.yaml;;
  *) echo 'Provedor invalido'; exit 1;;
esac
kubectl config current-context
kubectl apply -f k8s/namespace.yaml
# Gera o segredo em memoria e envia por stdin. Nao habilite set -x.
JWT_SECRET="$(openssl rand -base64 32)"
printf '{"apiVersion":"v1","kind":"Secret","metadata":{"name":"biblioteca-secret","namespace":"biblioteca-t3"},"type":"Opaque","stringData":{"jwt-secret":"%s"}}' "$JWT_SECRET" | kubectl apply -f -
unset JWT_SECRET
# Substitui a imagem antes de criar o Deployment, evitando pull de biblioteca:1.0.
kubectl set image --local -f k8s/deployment.yaml "biblioteca=$IMAGEM" -o yaml | kubectl apply -f -
kubectl apply -f "$SERVICE"
kubectl -n biblioteca-t3 rollout status deployment/biblioteca --timeout=300s
kubectl -n biblioteca-t3 get deployment,pods,service -o wide
