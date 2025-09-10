# Generate a random suffix for unique resource names
resource "random_pet" "bucket_suffix" {
  length = 2
}

# Create a Google Cloud Storage bucket
resource "google_storage_bucket" "demo_bucket" {
  name     = "${var.bucket_prefix}-${var.environment}-${random_pet.bucket_suffix.id}"
  location = "US"

  # Enable versioning
  versioning {
    enabled = true
  }

  # Lifecycle management
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  # Security settings
  uniform_bucket_level_access = true
  
  # Force destroy for demo purposes (not recommended for production)
  force_destroy = true

  labels = {
    environment  = var.environment
    managed_by   = "terraform"
    created_by   = "github-actions"
    project      = "workload-identity-demo"
  }
}

# Create a sample object in the bucket
resource "google_storage_bucket_object" "demo_object" {
  name   = "demo-file.txt"
  bucket = google_storage_bucket.demo_bucket.name
  content = <<-EOT
    This file was created by Terraform via GitHub Actions!
    
    Deployment Details:
    - Environment: ${var.environment}
    - Region: ${var.region}
    - Bucket: ${google_storage_bucket.demo_bucket.name}
    - Created: ${timestamp()}
    
    This demonstrates secure deployment using Workload Identity Federation.
  EOT
}

# Optional: Create a Compute Engine instance (commented out to keep costs low)
# Uncomment to test more complex resources
/*
resource "google_compute_instance" "demo_vm" {
  name         = "${var.bucket_prefix}-vm-${random_pet.bucket_suffix.id}"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
    environment = var.environment
    managed_by  = "terraform"
  }

  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["cloud-platform"]
  }

  tags = ["terraform-demo", "github-actions"]
}

# Service account for the VM
resource "google_service_account" "vm_sa" {
  account_id   = "${var.bucket_prefix}-vm-sa-${random_pet.bucket_suffix.id}"
  display_name = "Demo VM Service Account"
  description  = "Service account for demo VM created by Terraform"
}

# IAM binding for the VM service account
resource "google_project_iam_member" "vm_sa_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}
*/

# Optional: GKE cluster configuration (if you want to work with existing cluster)
# Uncomment and modify to work with your existing cluster
/*
# Data source to reference existing GKE cluster
data "google_container_cluster" "existing_cluster" {
  name     = "your-existing-cluster-name"  # Replace with your cluster name
  location = var.region                    # or specific zone if regional
}

# Example: Create a namespace in the existing cluster
resource "kubernetes_namespace" "demo_namespace" {
  metadata {
    name = "terraform-demo-${var.environment}"
    
    labels = {
      managed_by   = "terraform"
      created_by   = "github-actions"
      environment  = var.environment
    }
  }
  
  depends_on = [data.google_container_cluster.existing_cluster]
}

# Example: Create a simple deployment
resource "kubernetes_deployment" "demo_app" {
  metadata {
    name      = "demo-app"
    namespace = kubernetes_namespace.demo_namespace.metadata[0].name
    
    labels = {
      app         = "demo"
      managed_by  = "terraform"
      environment = var.environment
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "demo"
      }
    }

    template {
      metadata {
        labels = {
          app = "demo"
        }
      }

      spec {
        container {
          image = "nginx:1.21"
          name  = "demo-app"
          
          port {
            container_port = 80
          }
          
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

# If using the Kubernetes provider, add this to your provider.tf:
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.existing_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.existing_cluster.master_auth[0].cluster_ca_certificate)
}

data "google_client_config" "default" {}
*/
# Test deployment trigger - Thu Sep 11 00:24:15 IST 2025
