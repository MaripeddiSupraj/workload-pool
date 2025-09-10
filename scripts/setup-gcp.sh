#!/bin/bash

# Terraform GCP Setup Script with Workload Identity Federation
# This script sets up all necessary GCP resources for the demo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        print_warning "Terraform is not installed locally. This is optional for setup."
    fi
    
    print_success "Prerequisites check completed"
}

# Get user input
get_user_input() {
    print_status "Getting configuration details..."
    
    # Get current project if available
    CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
    
    read -p "Enter your GCP Project ID [$CURRENT_PROJECT]: " GCP_PROJECT_ID
    GCP_PROJECT_ID=${GCP_PROJECT_ID:-$CURRENT_PROJECT}
    
    if [ -z "$GCP_PROJECT_ID" ]; then
        print_error "GCP Project ID is required"
        exit 1
    fi
    
    read -p "Enter your GitHub repository (format: username/repo-name): " GITHUB_REPO
    if [ -z "$GITHUB_REPO" ]; then
        print_error "GitHub repository is required"
        exit 1
    fi
    
    # Set default values
    GCP_SERVICE_ACCOUNT="github-actions-sa"
    WIF_POOL="github-actions-pool"
    WIF_PROVIDER="github-actions-provider"
    STATE_BUCKET="${GCP_PROJECT_ID}-terraform-state"
    
    print_success "Configuration collected"
    echo "Project ID: $GCP_PROJECT_ID"
    echo "GitHub Repo: $GITHUB_REPO"
    echo "State Bucket: $STATE_BUCKET"
}

# Enable required APIs
enable_apis() {
    print_status "Enabling required GCP APIs..."
    
    gcloud services enable \
        iam.googleapis.com \
        iamcredentials.googleapis.com \
        cloudresourcemanager.googleapis.com \
        storage.googleapis.com \
        compute.googleapis.com \
        --project="$GCP_PROJECT_ID"
    
    print_success "APIs enabled successfully"
}

# Create service account
create_service_account() {
    print_status "Creating service account..."
    
    # Check if service account already exists
    if gcloud iam service-accounts describe "${GCP_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" --project="$GCP_PROJECT_ID" &>/dev/null; then
        print_warning "Service account already exists"
    else
        gcloud iam service-accounts create "$GCP_SERVICE_ACCOUNT" \
            --display-name="GitHub Actions Service Account" \
            --description="Service account for GitHub Actions workflows" \
            --project="$GCP_PROJECT_ID"
        print_success "Service account created"
    fi
}

# Grant IAM roles
grant_iam_roles() {
    print_status "Granting IAM roles to service account..."
    
    SERVICE_ACCOUNT_EMAIL="${GCP_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
    
    # Grant necessary roles
    ROLES=(
        "roles/storage.admin"
        "roles/compute.instanceAdmin.v1"
        "roles/iam.serviceAccountUser"
    )
    
    for ROLE in "${ROLES[@]}"; do
        gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
            --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
            --role="$ROLE" \
            --quiet
    done
    
    print_success "IAM roles granted"
}

# Create workload identity pool and provider
create_workload_identity() {
    print_status "Creating Workload Identity Pool and Provider..."
    
    # Create workload identity pool
    if gcloud iam workload-identity-pools describe "$WIF_POOL" --location="global" --project="$GCP_PROJECT_ID" &>/dev/null; then
        print_warning "Workload Identity Pool already exists"
    else
        gcloud iam workload-identity-pools create "$WIF_POOL" \
            --project="$GCP_PROJECT_ID" \
            --location="global" \
            --display-name="GitHub Actions Pool" \
            --description="Workload Identity Pool for GitHub Actions"
        print_success "Workload Identity Pool created"
    fi
    
    # Get the full pool ID
    WIF_POOL_ID=$(gcloud iam workload-identity-pools describe "$WIF_POOL" \
        --project="$GCP_PROJECT_ID" \
        --location="global" \
        --format="value(name)")
    
    # Create OIDC provider
    if gcloud iam workload-identity-pools providers describe "$WIF_PROVIDER" \
        --workload-identity-pool="$WIF_POOL" \
        --location="global" \
        --project="$GCP_PROJECT_ID" &>/dev/null; then
        print_warning "Workload Identity Provider already exists"
    else
        gcloud iam workload-identity-pools providers create-oidc "$WIF_PROVIDER" \
            --project="$GCP_PROJECT_ID" \
            --workload-identity-pool="$WIF_POOL" \
            --location="global" \
            --issuer-uri="https://token.actions.githubusercontent.com" \
            --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
            --attribute-condition="assertion.repository=='$GITHUB_REPO'"
        print_success "Workload Identity Provider created"
    fi
}

# Bind service account to workload identity
bind_service_account() {
    print_status "Binding service account to Workload Identity..."
    
    SERVICE_ACCOUNT_EMAIL="${GCP_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
    
    # Get the full pool ID again to ensure we have it
    WIF_POOL_ID=$(gcloud iam workload-identity-pools describe "$WIF_POOL" \
        --project="$GCP_PROJECT_ID" \
        --location="global" \
        --format="value(name)")
    
    gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT_EMAIL" \
        --project="$GCP_PROJECT_ID" \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/${WIF_POOL_ID}/attribute.repository/${GITHUB_REPO}"
    
    print_success "Service account bound to Workload Identity"
}

# Create state bucket
create_state_bucket() {
    print_status "Creating Terraform state bucket..."
    
    if gsutil ls -b "gs://$STATE_BUCKET" &>/dev/null; then
        print_warning "State bucket already exists"
    else
        gsutil mb -p "$GCP_PROJECT_ID" "gs://$STATE_BUCKET"
        
        # Enable versioning
        gsutil versioning set on "gs://$STATE_BUCKET"
        
        # Set lifecycle policy to delete old versions
        cat > /tmp/lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": 30,
          "isLive": false
        }
      }
    ]
  }
}
EOF
        gsutil lifecycle set /tmp/lifecycle.json "gs://$STATE_BUCKET"
        rm /tmp/lifecycle.json
        
        print_success "State bucket created with versioning and lifecycle policy"
    fi
}

# Update backend configuration
update_backend_config() {
    print_status "Updating Terraform backend configuration..."
    
    PROVIDER_FILE="terraform/provider.tf"
    if [ -f "$PROVIDER_FILE" ]; then
        # Update the backend bucket name
        sed -i.bak "s/REPLACE_WITH_YOUR_STATE_BUCKET/$STATE_BUCKET/g" "$PROVIDER_FILE"
        rm "${PROVIDER_FILE}.bak" 2>/dev/null || true
        print_success "Backend configuration updated"
    else
        print_warning "Provider file not found, skipping backend update"
    fi
}

# Generate GitHub secrets information
generate_github_secrets() {
    print_status "Generating GitHub Secrets information..."
    
    WIF_PROVIDER_FULL_NAME="projects/${GCP_PROJECT_ID}/locations/global/workloadIdentityPools/${WIF_POOL}/providers/${WIF_PROVIDER}"
    SERVICE_ACCOUNT_EMAIL="${GCP_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
    
    echo ""
    echo "==========================================="
    echo "GitHub Repository Secrets Configuration"
    echo "==========================================="
    echo ""
    echo "Add the following secrets to your GitHub repository:"
    echo "Repository Settings > Secrets and variables > Actions"
    echo ""
    echo "Secret Name: GCP_PROJECT_ID"
    echo "Secret Value: $GCP_PROJECT_ID"
    echo ""
    echo "Secret Name: GCP_SERVICE_ACCOUNT"
    echo "Secret Value: $SERVICE_ACCOUNT_EMAIL"
    echo ""
    echo "Secret Name: GCP_WORKLOAD_IDENTITY_PROVIDER"
    echo "Secret Value: $WIF_PROVIDER_FULL_NAME"
    echo ""
    echo "==========================================="
    echo ""
}

# Test the setup
test_setup() {
    print_status "Testing the setup..."
    
    # Test if we can impersonate the service account
    SERVICE_ACCOUNT_EMAIL="${GCP_SERVICE_ACCOUNT}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
    
    if gcloud auth print-access-token --impersonate-service-account="$SERVICE_ACCOUNT_EMAIL" &>/dev/null; then
        print_success "Service account impersonation test passed"
    else
        print_warning "Service account impersonation test failed - this might be normal if you don't have impersonation rights"
    fi
    
    # Test bucket access
    if gsutil ls "gs://$STATE_BUCKET" &>/dev/null; then
        print_success "State bucket access test passed"
    else
        print_error "State bucket access test failed"
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "GCP Workload Identity Federation Setup"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    get_user_input
    enable_apis
    create_service_account
    grant_iam_roles
    create_workload_identity
    bind_service_account
    create_state_bucket
    update_backend_config
    test_setup
    generate_github_secrets
    
    print_success "Setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Add the GitHub secrets shown above to your repository"
    echo "2. Commit and push your code to trigger the workflow"
    echo "3. Check the Actions tab in your GitHub repository"
    echo ""
}

# Run main function
main "$@"
