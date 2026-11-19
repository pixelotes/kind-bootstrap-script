#!/bin/bash
# Bootstrap: create the kind cluster, install Argo CD, then hand Argo CD the
# applications listed in `apps` below. Argo CD installs them from their Helm
# charts and retries until they settle.
set -euo pipefail

# Resolve the repo folder even when this script is called through a symlink
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
CLUSTER_NAME="k8s-playground"

# Apps to install (file name in argocd/<name>.yaml, without the extension)
apps=(
  "external-secrets-operator"
  "cert-manager"
  "metrics-server"
  "traefik"
  "falco"
  "victorialogs"
  "victoriametrics"
  "headlamp"
  "kyverno"
)

# 0) Pre-flight checks
for bin in docker kind kubectl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Missing required binary: $bin" >&2
    exit 1
  fi
done

# 1) Create the cluster (reuse it if it already exists)
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "Cluster ${CLUSTER_NAME} already exists, reusing it."
else
  kind create cluster --name "${CLUSTER_NAME}" --config "${SCRIPT_DIR}/config/kind-config.yaml"
fi

kubectl config use-context "kind-${CLUSTER_NAME}"

# Falco and VictoriaLogs open lots of inotify watches
for node in $(kind get nodes --name "${CLUSTER_NAME}"); do
  docker exec "${node}" sysctl -w fs.inotify.max_user_watches=524288 >/dev/null
  docker exec "${node}" sysctl -w fs.inotify.max_user_instances=512 >/dev/null
done

# 2) Install Argo CD
echo ""
echo "=========="
echo "= ARGOCD ="
echo "=========="

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
# Server-side apply: the Argo CD CRDs are too big for client-side apply
kubectl apply -n argocd --server-side --force-conflicts -f "${SCRIPT_DIR}/manifests/argocd.yaml"

components=(
  "argocd-server"
  "argocd-application-controller"
  "argocd-repo-server"
  "argocd-applicationset-controller"
  "argocd-notifications-controller"
)

for component in "${components[@]}"; do
  echo "Waiting for $component..."
  kubectl wait --namespace argocd \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name="${component}" \
    --timeout=180s
done

# Expose the Argo CD UI on NodePort 30080 (mapped to host port 30080 in kind-config.yaml)
kubectl patch svc argocd-server -n argocd -p \
  '{"spec": {"type": "NodePort", "ports": [{"name": "http", "nodePort": 30080, "port": 80, "protocol": "TCP", "targetPort": 8080}, {"name": "https", "nodePort": 30443, "port": 443, "protocol": "TCP", "targetPort": 8080}]}}'

until kubectl get secret argocd-initial-admin-secret --namespace argocd >/dev/null 2>&1; do
  echo "Waiting for argocd-initial-admin-secret..."
  sleep 2
done
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# 3) Hand the applications to Argo CD
echo ""
echo "========================"
echo "= INSTALLING ARGO APPS ="
echo "========================"

for app in "${apps[@]}"; do
  echo "  - ${app}"
  kubectl apply -f "${SCRIPT_DIR}/argocd/${app}.yaml" >/dev/null
done

cat <<MSG

=================================
= CLUSTER READY                 =
=================================
Context:   kind-${CLUSTER_NAME}
Argo CD:   https://localhost:30080  (admin / ${ARGOCD_PASS})
Headlamp:  http://localhost:30090
Ingress:   http://<host>.localhost:8080 (Traefik)

The applications are queued in Argo CD. Watch them roll out with:
  kubectl -n argocd get applications -w
MSG
