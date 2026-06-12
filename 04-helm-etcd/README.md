# Day 5 — Helm Chart Lifecycle + etcd Backup on Kubernetes

## Date: 2026-06-12
## Environment: WSL2 Ubuntu 24.04, Minikube v1.38.1, Kubernetes v1.35.1

---

## Part 1 — Helm Chart: httpbin

### Chart Structure
    helm create httpbin
    # Generated:
    # Chart.yaml       - chart metadata
    # values.yaml      - default values
    # templates/       - Kubernetes manifest templates
    # charts/          - chart dependencies

### Files Modified
    # Chart.yaml       - updated name, description, maintainer
    # values.yaml      - httpbin image, resources, ingress, serviceAccount, autoscaling
    # templates/
    #   deployment.yaml   - httpbin container with probes
    #   service.yaml      - ClusterIP service
    #   ingress.yaml      - nginx ingress with httpbin.local host
    #   serviceaccount.yaml - disabled (create: false)
    #   hpa.yaml          - disabled (enabled: false)
    #   NOTES.txt         - post-install instructions
    # Removed:
    #   httproute.yaml    - Gateway API not needed, removed to fix lint

### Helm Lint
    helm lint httpbin
    # Output: 1 chart(s) linted, 0 chart(s) failed

### Helm Install
    helm install httpbin ./httpbin
    # NAME:      httpbin
    # STATUS:    deployed
    # REVISION:  1

    kubectl get pods
    # httpbin-788955f945-vs67p   1/1   Running

    kubectl get svc httpbin
    # httpbin   ClusterIP   10.105.72.202   80/TCP

    kubectl get ingress
    # httpbin   nginx   httpbin.local   192.168.49.2   80

### Helm Upgrade — Scale to 2 replicas
    helm upgrade httpbin ./httpbin --set replicaCount=2
    # Release "httpbin" has been upgraded. Happy Helming!
    # REVISION: 2

    kubectl get pods
    # httpbin-788955f945-vs67p   1/1   Running
    # httpbin-788955f945-w9h8h   1/1   Running

### Helm Rollback — Back to revision 1
    helm rollback httpbin 1
    # Rollback was a success! Happy Helming!
    # REVISION: 3

    kubectl get pods
    # httpbin-788955f945-vs67p   1/1   Running  (back to 1 replica)

### Helm History
    helm history httpbin
    # REVISION  STATUS      DESCRIPTION
    # 1         superseded  Install complete
    # 2         superseded  Upgrade complete
    # 3         deployed    Rollback to 1

---

## Part 2 — etcd Backup on Kubernetes (Minikube)

### Find cert paths dynamically
    kubectl get pod etcd-minikube \
      -n kube-system \
      -o jsonpath='{.spec.containers[0].command}' \
      | tr ' ' '\n' | grep -E "cert|key|ca"

### Take etcd snapshot
    kubectl exec -n kube-system etcd-minikube -- \
      etcdctl snapshot save /tmp/etcd-backup.db \
      --endpoints=https://127.0.0.1:2379 \
      --cacert=/var/lib/minikube/certs/etcd/ca.crt \
      --cert=/var/lib/minikube/certs/etcd/server.crt \
      --key=/var/lib/minikube/certs/etcd/server.key

    # Output:
    # Snapshot saved at /tmp/etcd-backup.db
    # Size: 2.7 MB | etcd version: 3.6.0

---

## OCP vs Kubernetes etcd Backup Comparison

    # Feature              OpenShift IPI              Kubernetes (kubeadm/minikube)
    # Method               cluster-backup.sh          etcdctl snapshot save
    # Access               oc debug node + chroot     kubectl exec into etcd pod
    # Cert location        abstracted by script       /etc/kubernetes/pki/etcd/
    # Output               snapshot.db +              snapshot.db only
    #                      static_kuberesources.tar.gz
    # Snapshot size        97 MB (Day 4)              2.7 MB (minikube)
    # Supported by RH      Yes - only method          N/A
    # Distroless container No issue (script handles)  Must use etcdctl directly
    #                                                  (no sh/ls in container)

---

## Key Lessons

    # 1. helm lint catches template errors before touching cluster
    # 2. helm history tracks every revision — full audit trail
    # 3. helm rollback creates a NEW revision — it doesn't delete history
    # 4. httproute.yaml from helm create scaffold needs removal if not using Gateway API
    # 5. etcd v3.6 removed snapshot status subcommand — save output is the verification
    # 6. Distroless etcd container — only etcdctl binary available, no sh/ls
    # 7. Always find cert paths dynamically via jsonpath — never hardcode

---

## Helm Validation Best Practice (Interview Answer)

    # Step 1: helm lint ./chart          - local syntax check
    # Step 2: helm template ./chart      - render and review output
    # Step 3: helm install --dry-run     - simulate against cluster API
    # Step 4: helm install               - actual deploy
