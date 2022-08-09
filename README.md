# Prerequisites
- Terraform installed
- aws-cli installed
- AWS Credentials set up

# Usage
#### Create cluster
```
terraform apply \
    -var environment=eu1 \
    -var aws_region=eu-central-1 \
    -var app_role_namespace=default \
    -var app_role_service_account=app
```

Command will print `kubeconfig` to set up in order to gain access to cluster through `kubectl`.
