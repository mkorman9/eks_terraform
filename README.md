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
It will also print a definition of `ServiceAccount` to apply.
Created ServiceAccount will gain access to AWS services as defined in `app_role_policy.json`

#### Add Metrics Server
Metrics Server is not installed on EKS by default
```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl get deployment metrics-server -n kube-system
```
