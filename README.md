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

4. **Deploys Applications**:
   - Installs a predefined list of applications via ArgoCD manifests
   - Current applications: external-secrets-operator, cert-manager, metrics-server, nginx-ingress, falco

5. **Retrieves Admin Password**:
   - Waits for the initial admin secret to be created
   - Displays the ArgoCD admin password


## Prerequisites

- Docker installed and running
- Kind CLI installed
- kubectl installed

## Usage

1. Make the scripts executable:
   ```bash
   chmod +x start-cluster.sh
   chmod +x stop-cluster.sh
   ```

2. Run the script:
   ```bash
   ./start-cluster.sh
   ```

3. Access ArgoCD UI:
   - URL: `http://<container_ip>:30080` or `https://<container_ip>:30443`
   - Username: `admin`
   - Password: (displayed by the script)
  
> ℹ️ **Info**  
> If using orbstack instead of docker, you can access from:
> ```bash
> http://k8s-playground-control-plane.orb.local:30080
> ```

4. Stop and delete the cluster:
   ```bash
   ./stop-cluster.sh
   ```

## Creating Aliases

To create convenient command aliases, use symbolic links:

```bash
# Create start-cluster alias
ln /full/path/to/your/start-cluster.sh /usr/local/bin/start-cluster

# Create stop-cluster alias (assuming you have a stop script)
ln /full/path/to/your/stop-cluster.sh /usr/local/bin/stop-cluster

# Alternative: Add an alias to your ~/.bashrc (or ~/.zshrc if you use Zsh)
alias start-cluster="/full/path/to/your/start-cluster.sh"
alias stop-cluster="/full/path/to/your/stop-cluster.sh"

Then reload your shell config:

source ~/.bashrc
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

## Troubleshooting

- **Cluster creation fails**: Check if Docker is running and you have sufficient resources
- **ArgoCD pods not ready**: Increase timeout values or check cluster resources
- **Cannot access ArgoCD UI**: Verify the NodePort service patch was applied successfully
- **Applications not deploying**: Check ArgoCD logs and ensure manifest files exist in the correct locations
