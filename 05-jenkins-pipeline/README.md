# Day 6 — Jenkins CI/CD Pipeline on Kubernetes

## Date: 2026-06-12
## Environment: Minikube v1.38.1, Jenkins 2.555.3, Helm 3.16.4

## Architecture
    GitHub (ocp-lab-journal) → Jenkins → Helm → Kubernetes (minikube)

## Components Deployed
    - Jenkins 2.555.3 via Helm chart (jenkins/jenkins 5.9.25)
    - Jenkins agent: alpine/helm:3.16.4 pod
    - Target: httpbin app in default namespace

## Pipeline Stages
    1. Checkout   - pulls from github.com/Arupd21/ocp-lab-journal
    2. Helm Lint  - validates httpbin chart
    3. Deploy     - helm upgrade --install httpbin
    4. Verify     - helm status confirms deployment

## Key Commands

### Install Jenkins via Helm
    helm repo add jenkins https://charts.jenkins.io
    helm repo update
    helm install jenkins jenkins/jenkins \
      -n jenkins --create-namespace \
      -f jenkins-values.yaml

### Access Jenkins
    kubectl port-forward svc/jenkins 8080:8080 -n jenkins
    # URL: http://localhost:8080
    # User: admin

### Get admin password
    kubectl exec --namespace jenkins -it svc/jenkins \
      -c jenkins -- /bin/cat \
      /run/secrets/additional/chart-admin-password && echo

### Grant Jenkins RBAC permissions
    kubectl create clusterrolebinding jenkins-admin \
      --clusterrole=cluster-admin \
      --serviceaccount=jenkins:default

## Issues Fixed
    1. helm not found in default agent → used alpine/helm:3.16.4 container
    2. secrets forbidden → granted cluster-admin to jenkins serviceaccount
    3. helm status release not found → added --namespace default flag
    4. bitnami/kubectl shell issue → moved verify to helm container

## Lessons Learned
    1. Jenkins on K8s uses dynamic pod agents — each build gets a fresh pod
    2. Default agent image has no helm/kubectl — must specify custom containers
    3. Service account RBAC must be granted before helm can query cluster
    4. helm upgrade --install = idempotent deploy (create or update)
    5. Jenkinsfile lives in Git — pipeline is code, versioned and auditable
