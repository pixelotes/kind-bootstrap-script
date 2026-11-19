# Kubernetes Playground Setup

This script sets up a local Kubernetes playground using [kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker) with [Argo CD](https://argo-cd.readthedocs.io/) for GitOps-based application deployment.

## What the script does

1. **Creates a kind cluster** called `k8s-playground` (one control plane, one worker) from `./config/kind-config.yaml`, or reuses it if it already exists.
2. **Installs Argo CD** from the vendored manifest in `./manifests/argocd.yaml` and waits for all its components to be ready.
3. **Exposes the Argo CD UI** as a NodePort on 30080, published on the same port of your laptop.
4. **Hands Argo CD one Application per component** from `./argocd/`. Argo CD installs them from their Helm charts and retries until they settle.
5. **Prints the URLs and the Argo CD admin password.**

Installed by default:

| App | What it does |
|---|---|
| external-secrets-operator | Syncs secrets from an external store into Kubernetes |
| cert-manager | Issues and renews certificates |
| metrics-server | Makes `kubectl top` and autoscaling work |
| traefik | Ingress controller (kind ships without one) |
| falco | Runtime security, watches system calls |
| victorialogs, victoriametrics | Log and metric storage |
| headlamp | Web UI for the cluster |
| kyverno | Policy engine |

`argocd/kube-state-metrics.yaml` is also available but not in the default list.

> The community ingress-nginx controller was retired in March 2026 and the Kubernetes Dashboard project is archived, so this repo uses Traefik and Headlamp instead.

## Prerequisites

- Docker running (Docker Desktop, OrbStack or Docker Engine)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) and [kubectl](https://kubernetes.io/docs/tasks/tools/)

```bash
brew install kind kubectl
```

Tested with kind v0.33.0 (Kubernetes v1.37) and Argo CD v3.6.2.

## Usage

```bash
./start-cluster.sh   # create everything
./stop-cluster.sh    # delete the cluster
```

Watch the applications roll out:

```bash
kubectl -n argocd get applications -w
```

| Service | URL |
|---|---|
| Argo CD | <https://localhost:30080> (user `admin`, password printed by the script, self-signed certificate) |
| Headlamp | <http://localhost:30090> |
| Your Ingresses | `http://<host>.localhost:8080` and `https://<host>.localhost:8443`, through Traefik |

Headlamp logs in by itself with a lab-only `cluster-admin` service account. Don't reuse that setup on a real cluster.

## Running it from anywhere

Symlink the scripts into a folder in your `PATH`. The script resolves symlinks to find its config files.

```bash
ln -s "$PWD/start-cluster.sh" /usr/local/bin/start-cluster
ln -s "$PWD/stop-cluster.sh" /usr/local/bin/stop-cluster
```

Or add aliases to `~/.zshrc` or `~/.bashrc`:

```bash
alias start-cluster="/full/path/to/kind-bootstrap-script/start-cluster.sh"
alias stop-cluster="/full/path/to/kind-bootstrap-script/stop-cluster.sh"
```

## Adding more applications

1. Create an Argo CD `Application` manifest in `./argocd/`, for example `./argocd/my-new-app.yaml`.

   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: my-new-app
     namespace: argocd
   spec:
     # ... your application configuration
   ```

2. Add its name to the `apps` array at the top of `start-cluster.sh`. The name must match the file name without `.yaml`.

## Troubleshooting

- **Cluster creation fails**: check that Docker is running and has enough memory (6 GB or more for the full stack).
- **Port already in use**: something else is listening on 30080, 30090, 8080 or 8443. Change the `hostPort` values in `config/kind-config.yaml`.
- **An application stays Progressing or Degraded**: `kubectl -n argocd describe application <name>` shows the reason.
