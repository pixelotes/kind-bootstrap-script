#!/bin/bash

# Get the directory where this script is located
SCRIPT_CALLED_AS="$0"
SCRIPT_REAL_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_REAL_PATH")

if [ "$SCRIPT_CALLED_AS" != "$SCRIPT_REAL_PATH" ]; then
    echo "Script is symlinked!"
    echo "Called as: $SCRIPT_CALLED_AS"
    echo "Real path: $SCRIPT_REAL_PATH"
else
    echo "Script is not symlinked"
fi

CLUSTER_NAME="k8s-playground"

kind create cluster --name "${CLUSTER_NAME}" --config "${SCRIPT_DIR}"/config/kind-config.yaml

# Adjust kind params for victorialogs
docker exec "${CLUSTER_NAME}-control-plane" sh -c "sysctl -w fs.inotify.max_user_watches=524288"
docker exec "${CLUSTER_NAME}-control-plane" sh -c "sysctl -w fs.inotify.max_user_instances=512"
docker exec "${CLUSTER_NAME}-worker" sh -c "sysctl -w fs.inotify.max_user_watches=524288"
docker exec "${CLUSTER_NAME}-worker" sh -c "sysctl -w fs.inotify.max_user_instances=512"

# Install argocd
echo ""
echo "=========="
echo "= ARGOCD ="
echo "=========="

kubectl config use-context kind-"${CLUSTER_NAME}" && \
kubectl create namespace argocd && \
kubectl apply -n argocd -f "${SCRIPT_DIR}"/manifests/argocd.yaml

# Wait until argocd is fully ready
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
      --timeout=90s
done

# Create argocd nodeport
kubectl patch svc argocd-server -n argocd -p \
  '{"spec": {"type": "NodePort", "ports": [{"name": "http", "nodePort": 30080, "port": 80, "protocol": "TCP", "targetPort": 8080}, {"name": "https", "nodePort": 30443, "port": 443, "protocol": "TCP", "targetPort": 8080}]}}'

# Wait for argocd secret to be created
while ! kubectl get secret argocd-initial-admin-secret --namespace argocd; do echo "Waiting for my secret. CTRL-C to exit."; sleep 1; done

# Print argocd password
ARGOCD_SECRET=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo) && \
echo ""
echo "======================"
echo "= ARGOCD CREDENTIALS ="
echo "======================"
echo "ArgoCD password is $ARGOCD_SECRET"

# Install argo apps. App and manifest names must match
echo ""
echo "========================"
echo "= INSTALLING ARGO APPS ="
echo "========================"

apps=(
    "external-secrets-operator"
    "cert-manager" 
    "metrics-server"
    "nginx-ingress"
    "falco"
    "victorialogs"
    "victoriametrics"
    "k8s-dashboard"
    "kyverno"
)

for app in "${apps[@]}"; do
    echo "Installing $app..."
    kubectl apply -f "${SCRIPT_DIR}/argocd/${app}.yaml"
done
