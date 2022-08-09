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
    -var namespace=default \
    -var app_role_service_account=app
```

Command will print `kubeconfig` to set up in order to gain access to cluster through `kubectl`.

#### Deploy test application
```
kubectl create deployment hello-node --image=k8s.gcr.io/echoserver:1.4
kubectl expose deployment hello-node --type=NodePort --port=8080
```

#### Create AWS Load Balancer

**NOTE:** In order for AWS Load Balancer to work, the service needs to be exposed as `NodePort`

`kubectl apply -f` the following manifest, replace `<< ENVIRONMENT_NAME >>` with the value passed to terraform (`eu1`):
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test
  namespace: default
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/load-balancer-name: "<< ENVIRONMENT_NAME >>-ingress"
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello-node
                port:
                  number: 8080
```
