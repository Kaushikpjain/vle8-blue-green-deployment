# VLE-8: Blue-Green Deployment using DevOps Tools

## Objective
Implement Blue-Green Deployment using AWS, Terraform, Ansible,
Docker, Kubernetes, GitHub and Jenkins.

## Architecture
- Terraform provisions a dedicated Ubuntu EC2 instance.
- Ansible installs Docker and K3s.
- Docker builds Blue v1 and Green v2 application images.
- Kubernetes runs two replicas in each environment.
- A Kubernetes Service selects the active environment.
- Jenkins automates deployment, validation, approval and traffic switching.
- Rollback changes the Service selector back to Blue.

## Application environments

| Environment | Image | Replicas |
|---|---|---:|
| Blue | vle8-bluegreen:v1 | 2 |
| Green | vle8-bluegreen:v2 | 2 |

## Infrastructure
- AWS Region: ap-southeast-2
- OS: Ubuntu 22.04
- Instance: t3.small
- Kubernetes: K3s
- Container runtime: containerd

## Terraform
```bash
cd terraform
export TF_DATA_DIR=/tmp/vle8-terraform-data
terraform init
terraform validate
terraform plan
terraform apply

```
