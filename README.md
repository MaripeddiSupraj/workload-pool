# 📄 **Deploying Terraform to GCP with GitHub Actions using Workload Identity**

This repository provides a complete, working Proof of Concept (POC) for securely deploying Terraform infrastructure to Google Cloud Platform (GCP) from GitHub Actions workflows using **Workload Identity Federation** – Google's recommended best practice for keyless authentication.

## 📚 **Complete Documentation**

- **📖 [Comprehensive Blog Post](BLOG_POST.md)** - Detailed guide with architecture, security benefits, and real-world examples
- **🧪 [Testing Guide](TESTING_GUIDE.md)** - Step-by-step testing instructions for the complete POC
- **📋 [Setup Script](scripts/setup-gcp.sh)** - Automated GCP configuration script

## 🚀 **Quick Start**

1. **Run the setup script**: `./scripts/setup-gcp.sh`
2. **Add GitHub secrets** (script provides the values)
3. **Create a pull request** to test the workflow
4. **Merge to deploy** your infrastructure

## 📁 **Project Structure**

```
├── .github/workflows/
│   └── terraform.yml          # GitHub Actions CI/CD workflow
├── terraform/
│   ├── main.tf               # Main Terraform configuration
│   ├── provider.tf           # Provider and backend setup
│   ├── variables.tf          # Input variables
│   └── outputs.tf            # Output values
├── scripts/
│   └── setup-gcp.sh          # Automated GCP setup script
├── BLOG_POST.md              # Complete technical blog post
├── TESTING_GUIDE.md          # Comprehensive testing guide
└── README.md                 # This file
```

## **🎯 Core Concept: Why Workload Identity Federation?**

Traditional approaches using static service account keys have significant security drawbacks:

* **Static Credentials:** Long-lived keys that provide access until manually revoked
* **Leakage Risk:** Credentials can be accidentally exposed in logs or git history
* **Manual Management:** Requires manual key rotation and management

**Workload Identity Federation** solves these problems by establishing a trust relationship between GCP and GitHub, enabling:

🔐 **Short-lived tokens** instead of static keys  
⚡ **Automatic token rotation** and renewal  
🎯 **Fine-grained access control** per repository/branch  
📊 **Better audit trails** and attribution  

### Authentication Flow:
1. GitHub Actions requests an OIDC token from GitHub
2. The workflow presents this token to GCP's Workload Identity Pool
3. GCP verifies the token authenticity and exchanges it for a GCP access token
4. Terraform uses the temporary GCP token for resource management

---

## **🛠️ Automated Setup**

We've created a comprehensive setup script that handles all the complex GCP configuration automatically.

### **Quick Setup:**

```bash
# Clone this repository
git clone <your-repo-url>
cd workload-pool

# Run the automated setup script
chmod +x scripts/setup-gcp.sh
./scripts/setup-gcp.sh
```

The script will:
- ✅ Check prerequisites and enable required APIs
- ✅ Create service account with appropriate permissions
- ✅ Set up Workload Identity Pool and OIDC provider
- ✅ Create Terraform state bucket with versioning
- ✅ Configure all necessary IAM bindings
- ✅ Provide GitHub secrets configuration

### **Manual Setup (Alternative)**

If you prefer manual setup, follow the detailed instructions in the [Blog Post](BLOG_POST.md).

---

## **Part 2: 📁 Terraform Configuration**

Now, let's create the Terraform files for our POC.

### **2.1. Project Structure**

The project structure is organized as follows:

```
.
├── .github/
│   └── workflows/
│       └── terraform.yml
├── terraform/
│   ├── main.tf
│   ├── provider.tf
│   ├── backend.tf
│   └── variables.tf
├── scripts/
│   └── setup-gcp.sh
└── README.md
```

### **2.2. Provider Configuration**

Notice that this file **does not contain any credentials**. The authentication will be handled by the GitHub Actions environment.

### **2.3. Terraform Backend**

It's a best practice to store your Terraform state file remotely. We'll configure it to use a GCS bucket.

### **2.4. Main Configuration**

This is our simple POC resource: a GCS bucket with a unique name.

---

## **Part 3: 🚀 GitHub Repository and Actions Setup**

### **3.1. Add GitHub Secrets**

We need to provide the Workload Identity Provider name and the Service Account email to our workflow. Go to your GitHub repository > `Settings` > `Secrets and variables` > `Actions`.

Create the following **repository secrets**:

* `GCP_SERVICE_ACCOUNT`: The email of the service account we created.
* `GCP_WORKLOAD_IDENTITY_PROVIDER`: The full resource name of the WIF provider.
* `GCP_PROJECT_ID`: Your GCP Project ID.

### **3.2. Create the GitHub Actions Workflow**

The workflow file includes comprehensive CI/CD pipeline with plan and apply stages.

---

## **🎮 Testing Your POC**

Follow the comprehensive [Testing Guide](TESTING_GUIDE.md) to validate your setup:

1. **Verify GCP Resources**: Confirm all components are created correctly
2. **Test Pull Request Workflow**: Create a PR and verify the plan generation
3. **Test Deployment**: Merge the PR and verify resource creation
4. **Security Validation**: Ensure no static credentials are stored
5. **Error Scenarios**: Test failure conditions and recovery

### **Quick Test:**

```bash
# Create test branch and trigger workflow
git checkout -b test-deployment
echo "# Test deployment" >> terraform/main.tf
git add . && git commit -m "test: Trigger workflow"
git push origin test-deployment

# Create PR and observe the workflow in GitHub Actions tab
```

---

## **📊 What Gets Deployed**

This POC creates the following resources:

- **GCS Bucket**: With versioning and lifecycle policies
- **Demo Object**: Text file demonstrating successful deployment
- **State Management**: Remote state stored in GCS
- **IAM Resources**: Service account and Workload Identity configuration

All resources are tagged for easy identification and include cost optimization features.

---

## **🛡️ Security Features**

- ✅ **Zero Static Credentials**: No service account keys stored anywhere
- ✅ **Short-lived Tokens**: OIDC tokens expire automatically
- ✅ **Repository Scoping**: Access limited to specific GitHub repositories
- ✅ **Audit Trail**: Complete logging of all authentication and deployment activities
- ✅ **Principle of Least Privilege**: Minimal required permissions only

---

## **🔧 Troubleshooting**

For detailed troubleshooting, see the [Testing Guide](TESTING_GUIDE.md#troubleshooting-common-issues).

### **Quick Fixes:**

| Issue | Solution |
|-------|----------|
| Authentication failures | Verify GitHub secrets and Workload Identity configuration |
| Permission denied | Check service account IAM roles |
| State lock issues | Remove orphaned Terraform locks from GCS bucket |
| Workflow not triggering | Check path filters and branch protection rules |

### **Useful Commands:**

```bash
# Verify setup script execution
./scripts/setup-gcp.sh

# Check Workload Identity configuration
gcloud iam workload-identity-pools describe github-actions-pool \
    --project=${GCP_PROJECT_ID} --location=global

# Test service account impersonation (optional)
gcloud auth print-access-token \
    --impersonate-service-account=github-actions-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com
```

---

## **🚀 Production Considerations**

Before using this in production:

1. **Environment Separation**: Use separate projects/service accounts for dev/staging/prod
2. **Enhanced Monitoring**: Implement Cloud Monitoring and alerting
3. **Security Scanning**: Add Checkov or similar tools to the workflow
4. **State Management**: Consider using Terraform Cloud or remote backends with encryption
5. **Approval Workflows**: Implement manual approval gates for production deployments

See the [Blog Post](BLOG_POST.md) for detailed production recommendations.

---

## **📚 Additional Resources**

- 📖 **[Complete Blog Post](BLOG_POST.md)** - Comprehensive guide with architecture details
- 🧪 **[Testing Guide](TESTING_GUIDE.md)** - Step-by-step testing instructions
- 🔗 **[Google Cloud Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)**
- 🔗 **[GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)**
- 🔗 **[Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)**

---

## **🎯 Next Steps**

1. **Deploy the POC**: Run through the setup and testing process
2. **Customize**: Adapt the Terraform configuration for your use case
3. **Scale**: Implement multi-environment workflows
4. **Secure**: Add additional security scanning and monitoring
5. **Share**: Use this as a template for your team's infrastructure deployments

**Congratulations!** 🎉 You now have a secure, production-ready foundation for deploying infrastructure to GCP using modern DevOps best practices.
