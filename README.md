# Kubernetes Playground Setup

This script sets up a local Kubernetes playground environment using Kind (Kubernetes in Docker) with ArgoCD for GitOps-based application deployment.

## What the Script Does

1. **Creates Kind Cluster**: Sets up a local Kubernetes cluster named `k8s-playground` using the configuration in `./config/kind-config.yaml`

2. **Installs ArgoCD**: 
   - Creates the `argocd` namespace
   - Deploys ArgoCD using manifests from `./manifests/argocd.yaml`
   - Waits for all ArgoCD components to be ready (server, application controller, repo server, applicationset controller, notifications controller)

3. **Configures ArgoCD Access**:
   - Patches the ArgoCD server service to use NodePort for external access
   - HTTP available on port 30080
   - HTTPS available on port 30443

4. **Retrieves Admin Password**:
   - Waits for the initial admin secret to be created
   - Displays the ArgoCD admin password

5. **Deploys Applications**:
   - Installs a predefined list of applications via ArgoCD manifests
   - Current applications: external-secrets-operator, cert-manager, metrics-server, nginx-ingress

## Prerequisites

- Docker installed and running
- Kind CLI installed
- kubectl installed
- Directory structure with required configuration files:
  ```
  ./config/kind-config.yaml
  ./manifests/argocd.yaml
  ./argocd/external-secrets-operator.yaml
  ./argocd/cert-manager.yaml
  ./argocd/metrics-server.yaml
  ./argocd/nginx-ingress.yaml
  ```

## Usage

1. Make the script executable:
   ```bash
   chmod +x start-cluster.sh
   ```

2. Run the script:
   ```bash
   ./start-cluster.sh
   ```

3. Access ArgoCD UI:
   - URL: `http://localhost:30080` or `https://localhost:30443`
   - Username: `admin`
   - Password: (displayed by the script)

## Creating Aliases

To create convenient command aliases, use symbolic links:

```bash
# Create start-cluster alias
ln -s /full/path/to/your/script.sh /usr/local/bin/start-cluster

# Create stop-cluster alias (assuming you have a stop script)
ln -s /full/path/to/your/stop-script.sh /usr/local/bin/stop-cluster

# Alternative: Add to your local bin directory
mkdir -p ~/bin
ln -s /full/path/to/your/script.sh ~/bin/start-cluster
ln -s /full/path/to/your/stop-script.sh ~/bin/stop-cluster

# Make sure ~/bin is in your PATH (add to ~/.bashrc or ~/.zshrc if needed)
export PATH="$HOME/bin:$PATH"
```

After creating the aliases, you can simply run:
```bash
start-cluster
stop-cluster
```

## Adding More Applications

To add new applications to the deployment:

1. **Create ArgoCD Application Manifest**: Create a new YAML file in the `./argocd/` directory
   ```yaml
   # Example: ./argocd/my-new-app.yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: my-new-app
     namespace: argocd
   spec:
     # ... your application configuration
   ```

2. **Update the Script**: Add your application name to the `apps` array in the script:
   ```bash
   apps=(
   "external-secrets-operator"
   "cert-manager"
   "metrics-server"
   "nginx-ingress"
   "my-new-app"  # Add your new app here
   )
   ```

3. **Important**: The application name in the array must match the filename (without .yaml extension) in the `./argocd/` directory.

## Stopping the Cluster

To stop and delete the cluster:
```bash
kind delete cluster --name k8s-playground
```

Consider creating a separate `stop-cluster.sh` script with this command for convenience.

## Troubleshooting

- **Cluster creation fails**: Check if Docker is running and you have sufficient resources
- **ArgoCD pods not ready**: Increase timeout values or check cluster resources
- **Cannot access ArgoCD UI**: Verify the NodePort service patch was applied successfully
- **Applications not deploying**: Check ArgoCD logs and ensure manifest files exist in the correct locations