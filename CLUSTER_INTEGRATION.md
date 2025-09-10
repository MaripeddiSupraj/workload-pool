# 🚀 Working with Your Existing GKE Cluster

Since you mentioned you already have a cluster, here's how to adapt this POC to work with your existing GKE cluster instead of just creating storage resources.

## 📋 Prerequisites for Cluster Integration

1. **Existing GKE Cluster**: Your cluster should be running and accessible
2. **Cluster Access**: Your service account needs appropriate permissions
3. **Kubernetes Provider**: We'll add the Kubernetes Terraform provider

## 🔧 Configuration Steps

### 1. Add Cluster Permissions to Service Account

Update your setup script or run these commands manually:

```bash
# Add GKE permissions to the service account
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
    --member="serviceAccount:github-actions-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/container.developer"

# For namespace and deployment management
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
    --member="serviceAccount:github-actions-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/container.admin"
```

### 2. Update Terraform Configuration

The `main.tf` file already includes commented examples for working with an existing cluster. To enable cluster integration:

1. **Uncomment the GKE section** in `terraform/main.tf`
2. **Update the cluster name** to match your existing cluster:
   ```hcl
   data "google_container_cluster" "existing_cluster" {
     name     = "your-actual-cluster-name"  # ⬅️ Update this
     location = var.region
   }
   ```

3. **Add the Kubernetes provider** to `terraform/provider.tf`:
   ```hcl
   kubernetes = {
     source  = "hashicorp/kubernetes"
     version = ">= 2.0"
   }
   ```

### 3. Add Cluster Variables

Add these variables to `terraform/variables.tf`:

```hcl
variable "cluster_name" {
  description = "Name of the existing GKE cluster"
  type        = string
  default     = "your-cluster-name"  # Update with your cluster name
}

variable "cluster_location" {
  description = "Location of the existing GKE cluster"
  type        = string
  default     = "us-central1"  # Update with your cluster location
}
```

### 4. Update GitHub Workflow

If your cluster is in a different project or requires special authentication, update the workflow to set the appropriate context:

```yaml
# Add to .github/workflows/terraform.yml after authentication
- name: Configure kubectl
  run: |
    gcloud container clusters get-credentials ${{ vars.CLUSTER_NAME || 'your-cluster-name' }} \
      --region=${{ vars.CLUSTER_LOCATION || 'us-central1' }} \
      --project=${{ secrets.GCP_PROJECT_ID }}
```

## 🎯 What This Deployment Will Create

With the cluster integration enabled, the Terraform deployment will create:

1. **GCS Bucket**: For demonstration and state storage
2. **Kubernetes Namespace**: Named `terraform-demo-{environment}`
3. **Kubernetes Deployment**: Simple nginx application with 2 replicas
4. **Resource Labels**: For tracking and management

## 🔍 Cluster Information Commands

To get information about your existing cluster:

```bash
# List your clusters
gcloud container clusters list

# Get cluster details
gcloud container clusters describe YOUR_CLUSTER_NAME --region=YOUR_REGION

# Get cluster endpoint and credentials
gcloud container clusters get-credentials YOUR_CLUSTER_NAME --region=YOUR_REGION
```

## 🧪 Testing with Your Cluster

1. **Run the basic POC first** without cluster integration to ensure everything works
2. **Uncomment the cluster code** in `main.tf`
3. **Update the cluster name and location** variables
4. **Create a test PR** to see the plan
5. **Verify the namespace and deployment** are created successfully

### Verification Commands:

```bash
# Check if namespace was created
kubectl get namespaces | grep terraform-demo

# Check if deployment was created
kubectl get deployments -n terraform-demo-dev

# Check if pods are running
kubectl get pods -n terraform-demo-dev

# Get deployment details
kubectl describe deployment demo-app -n terraform-demo-dev
```

## 🛡️ Security Considerations for Cluster Access

1. **Principle of Least Privilege**: Only grant necessary cluster permissions
2. **Namespace Isolation**: Use separate namespaces for different environments
3. **Network Policies**: Consider implementing network policies for pod communication
4. **RBAC**: Use Kubernetes RBAC for fine-grained access control

### Example RBAC Configuration:

```yaml
# Add to your Terraform configuration
resource "kubernetes_role" "terraform_role" {
  metadata {
    namespace = kubernetes_namespace.demo_namespace.metadata[0].name
    name      = "terraform-deployer"
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "create", "update", "patch", "delete"]
  }
}
```

## 🚀 Advanced Cluster Integration

For more advanced scenarios, consider:

1. **Helm Charts**: Use the Helm Terraform provider for complex applications
2. **Istio Service Mesh**: Deploy and manage Istio resources
3. **ArgoCD Integration**: Use Terraform to bootstrap GitOps workflows
4. **Multiple Clusters**: Extend to manage multiple clusters across regions

### Example Helm Integration:

```hcl
# Add to provider.tf
helm = {
  source  = "hashicorp/helm"
  version = ">= 2.0"
}

# Add to main.tf
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  
  create_namespace = true
}
```

## 📊 Monitoring and Observability

Since you have an existing cluster, consider adding monitoring resources:

```hcl
# Example: Deploy Prometheus monitoring
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# Use Helm to deploy monitoring stack
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
}
```

## 🎯 Next Steps

1. **Start with basic POC**: Get the foundational setup working first
2. **Add cluster integration**: Uncomment and configure the cluster components
3. **Test incrementally**: Test each component separately
4. **Expand functionality**: Add more complex Kubernetes resources as needed
5. **Implement monitoring**: Add observability for your deployed applications

This approach gives you a secure, automated way to deploy and manage applications on your existing GKE cluster using the same Workload Identity Federation pattern.

---

**Happy Kubernetes Deployment! ⚡🚀**
