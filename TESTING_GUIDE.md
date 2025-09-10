# 🧪 Testing Guide for GCP Workload Identity Federation POC

This guide provides step-by-step instructions for testing the complete Terraform + GitHub Actions + Workload Identity Federation setup.

## 📋 Pre-Test Checklist

Before running the tests, ensure you have completed:

- [ ] Ran the `setup-gcp.sh` script successfully
- [ ] Added all required GitHub secrets
- [ ] Committed all Terraform files to your repository
- [ ] Your GitHub repository has Actions enabled

## 🔍 Test Scenarios

### Test 1: Basic Setup Validation

#### 1.1 Verify GCP Resources
```bash
# Check if service account exists
gcloud iam service-accounts describe github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com

# Check workload identity pool
gcloud iam workload-identity-pools describe github-actions-pool \
  --location=global --project=${PROJECT_ID}

# Check OIDC provider
gcloud iam workload-identity-pools providers describe github-actions-provider \
  --workload-identity-pool=github-actions-pool \
  --location=global --project=${PROJECT_ID}

# Verify state bucket
gsutil ls gs://${PROJECT_ID}-terraform-state
```

#### 1.2 Test GitHub Secrets
Go to your repository → Settings → Secrets and variables → Actions

Verify these secrets exist:
- `GCP_PROJECT_ID`
- `GCP_SERVICE_ACCOUNT`
- `GCP_WORKLOAD_IDENTITY_PROVIDER`

### Test 2: Pull Request Workflow

#### 2.1 Create Test Branch
```bash
# Create and switch to test branch
git checkout -b test-pr-workflow

# Make a small change to trigger the workflow
echo "
# Test comment for PR workflow
" >> terraform/main.tf

# Commit and push
git add .
git commit -m "test: Add comment to trigger PR workflow"
git push origin test-pr-workflow
```

#### 2.2 Create Pull Request
1. Go to your GitHub repository
2. Click "Compare & pull request"
3. Create the pull request

#### 2.3 Verify PR Workflow
Check that the workflow:
- [ ] Starts automatically
- [ ] Authenticates to GCP successfully
- [ ] Runs `terraform plan`
- [ ] Comments the plan on the PR
- [ ] Shows green checkmarks for all steps

#### Expected Results:
```
✅ Terraform Format and Style
✅ Terraform Initialization
✅ Terraform Validation
✅ Terraform Plan
```

### Test 3: Deployment Workflow

#### 3.1 Merge Pull Request
1. Review the Terraform plan in the PR comment
2. Merge the pull request
3. Monitor the "Terraform Apply" workflow

#### 3.2 Verify Deployment
Check the Actions tab for:
- [ ] Successful authentication
- [ ] Terraform apply completion
- [ ] Resource creation

#### 3.3 Verify Created Resources
```bash
# List buckets to find the created one
gsutil ls -p ${PROJECT_ID}

# Check the demo object
gsutil ls gs://gcp-terraform-demo-dev-*/
gsutil cat gs://gcp-terraform-demo-dev-*/demo-file.txt
```

#### Expected Resources:
- GCS bucket with pattern: `gcp-terraform-demo-dev-<random-suffix>`
- Demo text file inside the bucket
- Terraform state file in the state bucket

### Test 4: Security Validation

#### 4.1 Verify No Static Keys
```bash
# Search for any JSON keys in the repository
find . -name "*.json" -exec grep -l "private_key" {} \; 2>/dev/null || echo "✅ No private keys found"

# Check GitHub secrets don't contain private keys
# (Manual verification in GitHub UI - ensure no key files are uploaded)
```

#### 4.2 Test Token Expiration
The OIDC tokens should be short-lived (typically 10 minutes). Re-run a workflow after 15 minutes to verify new tokens are generated.

### Test 5: Error Scenarios

#### 5.1 Test Authentication Failure
1. Temporarily modify the `GCP_WORKLOAD_IDENTITY_PROVIDER` secret with an invalid value
2. Trigger a workflow
3. Verify it fails with authentication error
4. Restore the correct value

#### 5.2 Test Permission Errors
```bash
# Temporarily remove a required IAM binding
gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Run workflow - should fail
# Then restore the binding
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"
```

## 🔧 Troubleshooting Common Issues

### Issue 1: "Error: Failed to get default credentials"
**Cause**: Workload Identity Federation not properly configured
**Solution**:
```bash
# Re-run the identity federation setup
./scripts/setup-gcp.sh
```

### Issue 2: "Permission denied" errors
**Cause**: Insufficient IAM permissions
**Solution**:
```bash
# Check current permissions
gcloud projects get-iam-policy ${PROJECT_ID} \
  --filter="bindings.members:serviceAccount:github-actions-sa@${PROJECT_ID}.iam.gserviceaccount.com"

# Add missing permissions as needed
```

### Issue 3: Terraform state lock
**Cause**: Previous workflow didn't complete properly
**Solution**:
```bash
# List and remove state locks if needed
gsutil ls gs://${PROJECT_ID}-terraform-state/**/.terraform.lock.info
# If locks exist, remove them carefully:
# gsutil rm gs://${PROJECT_ID}-terraform-state/**/terraform.lock.info
```

### Issue 4: Workflow not triggering
**Cause**: Path filters or branch protection
**Solution**:
- Check the `paths` filter in `.github/workflows/terraform.yml`
- Ensure your changes affect files in the `terraform/` directory
- Verify branch protection rules

## 📊 Performance Testing

### Measure Workflow Performance
Track these metrics:
- **Authentication time**: Should be < 30 seconds
- **Terraform init time**: Should be < 60 seconds
- **Terraform plan time**: Should be < 2 minutes
- **Terraform apply time**: Should be < 5 minutes

### Load Testing
```bash
# Test multiple concurrent workflows
for i in {1..3}; do
  # Create test branches and trigger workflows
  git checkout -b load-test-$i
  echo "# Load test $i" >> terraform/main.tf
  git commit -am "test: Load test $i"
  git push origin load-test-$i &
done
```

## 🛡️ Security Testing

### Test 1: Repository Access Control
Verify that only your specific repository can access the service account:
```bash
# The attribute condition should restrict access
gcloud iam workload-identity-pools providers describe github-actions-provider \
  --workload-identity-pool=github-actions-pool \
  --location=global \
  --project=${PROJECT_ID} \
  --format="value(attributeCondition)"
```

### Test 2: Branch Restrictions
If you've configured branch restrictions, test that only allowed branches can deploy:
```bash
# Create a branch that shouldn't be able to deploy
git checkout -b unauthorized-branch
echo "# Unauthorized change" >> terraform/main.tf
git commit -am "test: Unauthorized deployment attempt"
git push origin unauthorized-branch

# Verify this fails or is restricted
```

## 📝 Test Results Documentation

### Create Test Report
Document your test results:

```markdown
# Test Results - $(date)

## Basic Setup ✅/❌
- [ ] GCP Resources Created
- [ ] GitHub Secrets Configured
- [ ] Repository Setup Complete

## Workflow Tests ✅/❌
- [ ] PR Workflow Triggered
- [ ] Plan Generated Successfully
- [ ] Apply Workflow Executed
- [ ] Resources Created

## Security Tests ✅/❌
- [ ] No Static Credentials
- [ ] Token Expiration Working
- [ ] Access Control Verified

## Performance Metrics
- Authentication Time: X seconds
- Plan Time: X seconds
- Apply Time: X seconds

## Issues Found
1. Issue description and resolution
2. ...

## Recommendations
1. Suggestion for improvement
2. ...
```

## 🎯 Success Criteria

Your POC is successful if:
- ✅ All workflows complete without errors
- ✅ Resources are created in GCP as expected
- ✅ No static credentials are stored anywhere
- ✅ Authentication happens via OIDC tokens only
- ✅ State is properly managed in GCS
- ✅ PR workflows show plan comments
- ✅ Security validations pass

## 🚀 Next Steps After Testing

Once your POC is working:

1. **Document Lessons Learned**: Update your runbook with any issues encountered
2. **Extend to Production**: Apply the same pattern to your production workloads
3. **Add Monitoring**: Set up alerts for workflow failures
4. **Security Review**: Have your security team review the implementation
5. **Training**: Train your team on the new deployment process

## 📞 Getting Help

If tests fail:
1. Check the GitHub Actions logs for detailed error messages
2. Review the GCP audit logs for authentication issues
3. Verify all prerequisites are met
4. Try running the setup script again
5. Open an issue with detailed error logs

---

**Happy Testing! 🧪✨**
