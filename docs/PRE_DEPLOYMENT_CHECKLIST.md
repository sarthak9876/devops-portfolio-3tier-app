# Pre-Deployment Checklist

Complete this checklist BEFORE deploying any resources to AWS.

## ✅ Environment Setup
- [ ] AWS CLI installed and configured (`aws --version`)
- [ ] AWS credentials configured (`aws sts get-caller-identity`)
- [ ] Docker installed and running (`docker ps`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] Terraform installed (`terraform --version`)
- [ ] Git configured with username and email
- [ ] GitHub repository created and cloned locally

## ✅ AWS Account Configuration
- [ ] AWS account created AFTER July 15, 2025 (for free tier credits)
- [ ] Verified $100+ signup credits available
- [ ] Billing alerts configured at $50, $100, $150, $180
- [ ] AWS Budget created ($200 total)
- [ ] SNS email subscription confirmed
- [ ] Default region set to us-east-1 or us-west-2
- [ ] MFA enabled on root account (security best practice)

## ✅ Cost Protection
- [ ] Billing alarms showing in CloudWatch (us-east-1 region)
- [ ] Cost calculator script tested (`./scripts/cost-calculator.sh`)
- [ ] Shutdown script tested (`./scripts/shutdown/stop-all-resources.sh`)
- [ ] Understand how to stop resources when not working
- [ ] Phone calendar reminder set to check costs weekly

## ✅ Local Testing Environment
- [ ] Minikube installed and can start (`minikube start`)
- [ ] Can deploy test pods to Minikube (`kubectl run test --image=nginx`)
- [ ] Docker Compose working for local app testing
- [ ] System resources sufficient (8GB+ RAM, 50GB+ disk, 2+ CPU cores)

## ✅ Security
- [ ] .gitignore configured (no secrets in repo)
- [ ] AWS IAM user created (not using root account)
- [ ] SSH key pair generated for EC2 access (`ssh-keygen`)
- [ ] GitHub SSH key configured (if using SSH remote)
- [ ] Understand: NEVER commit .pem files, .tfstate, or secrets

## ✅ Documentation
- [ ] README.md created with project overview
- [ ] Repository structure documented
- [ ] Cost tracking document initialized
- [ ] Architecture documentation placeholder created

## ✅ Knowledge Check
- [ ] Understand what m7i-flex.large instances are
- [ ] Know the difference between stopped vs terminated EC2 instances
- [ ] Understand Terraform state management basics
- [ ] Know how to check AWS service limits
- [ ] Understand basic Kubernetes concepts (pods, services, deployments)

## ✅ Final Sanity Checks
- [ ] Run validation script: `./scripts/validate-environment.sh`
- [ ] All validation checks pass (or only warnings, no errors)
- [ ] Have at least 2 hours of uninterrupted time for initial deployment
- [ ] Know how to reach AWS support if needed

## 🚨 Red Flags - DO NOT PROCEED IF:
- ❌ No billing alarms configured
- ❌ Less than $180 in available credits
- ❌ Using root AWS account (create IAM user!)
- ❌ Don't know how to stop/terminate resources
- ❌ Haven't tested shutdown scripts
- ❌ Planning to leave resources running 24/7 without monitoring

---

**Date Completed:** _________________

**Completed By:** _________________

**Ready to Proceed:** ☐ Yes  ☐ No (fix issues first)

**Next Phase:** Phase 1 - Application Selection & Containerization
