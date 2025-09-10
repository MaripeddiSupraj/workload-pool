#!/bin/bash

# Quick Start Script for GCP Workload Identity Federation POC
# This script helps you get started quickly with the demo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_header() {
    echo "=============================================="
    echo "  GCP Workload Identity Federation POC"
    echo "  Quick Start Guide"
    echo "=============================================="
    echo ""
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check for required tools
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if ! command -v gcloud &> /dev/null; then
        missing_deps+=("gcloud")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_deps[*]}"
        echo ""
        echo "Please install the missing tools:"
        echo "- Git: https://git-scm.com/downloads"
        echo "- Google Cloud CLI: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Check if gcloud is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 > /dev/null; then
        print_error "gcloud is not authenticated"
        echo ""
        echo "Please run: gcloud auth login"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

check_git_repo() {
    print_status "Checking Git repository..."
    
    if [ ! -d ".git" ]; then
        print_error "This is not a Git repository"
        echo ""
        echo "Please run this script from the root of your Git repository"
        echo "or initialize a new repo with: git init"
        exit 1
    fi
    
    # Check if remote origin exists
    if ! git remote get-url origin &> /dev/null; then
        print_warning "No remote origin found"
        echo ""
        echo "You'll need to add a GitHub remote origin:"
        echo "git remote add origin https://github.com/yourusername/yourrepo.git"
        echo ""
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        REPO_URL=$(git remote get-url origin)
        print_success "Repository: $REPO_URL"
    fi
}

show_next_steps() {
    print_status "Setup completed! Here are your next steps:"
    echo ""
    echo "1. 🔧 Run the GCP setup script:"
    echo "   ./scripts/setup-gcp.sh"
    echo ""
    echo "2. 🔑 Add the GitHub secrets (setup script will show you the values)"
    echo "   Go to: GitHub Repository → Settings → Secrets and variables → Actions"
    echo ""
    echo "3. 🧪 Test the workflow:"
    echo "   git checkout -b test-deployment"
    echo "   echo '# Test change' >> terraform/main.tf"
    echo "   git add . && git commit -m 'test: Trigger workflow'"
    echo "   git push origin test-deployment"
    echo ""
    echo "4. 📊 Create a Pull Request and watch the workflow in the Actions tab"
    echo ""
    echo "5. 📚 For detailed instructions, see:"
    echo "   - README.md - Quick overview and troubleshooting"
    echo "   - BLOG_POST.md - Complete technical guide"
    echo "   - TESTING_GUIDE.md - Comprehensive testing instructions"
    echo ""
    print_success "Happy deploying! 🚀"
}

main() {
    print_header
    check_prerequisites
    check_git_repo
    show_next_steps
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Quick start script for GCP Workload Identity Federation POC"
        echo ""
        echo "OPTIONS:"
        echo "  --help, -h    Show this help message"
        echo "  --check       Only run prerequisite checks"
        echo ""
        echo "This script will:"
        echo "  1. Check that required tools are installed"
        echo "  2. Verify you're in a Git repository"
        echo "  3. Show you the next steps to get started"
        echo ""
        exit 0
        ;;
    --check)
        print_header
        check_prerequisites
        check_git_repo
        print_success "All checks passed!"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
