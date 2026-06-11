# Day 4 — OpenShift IPI on AWS

## Cluster Details
- Version: 4.22.0
- Platform: AWS IPI (us-east-1)
- Domain: aruplab.click
- Nodes: 3 masters + 2 workers (m5.xlarge)
- Install time: 41m 29s
- ClusterID: 6c770922-32a6-4af0-bed6-034ec76c4dd3

## Labs Completed

### Lab 1 — must-gather
```bash
oc adm must-gather --dest-dir=/tmp/must-gather-day4
```
- Result: ClusterOperators all healthy and stable
- Use case: First step on every GSS support case

### Lab 2 — etcd Backup
```bash
MASTER=$(oc get nodes -l node-role.kubernetes.io/master \
  -o jsonpath='{.items[0].metadata.name}')
oc debug node/$MASTER -- chroot /host \
  /usr/local/bin/cluster-backup.sh /home/core/assets/backup
```
- Snapshot: 97MB | Keys: 11,518 | etcd: v3.6.0
- Files: snapshot_2026-06-11_160839.db + static_kuberesources.tar.gz
- Use case: Pre-maintenance backup, disaster recovery

### Lab 3 — Cluster Operators
```bash
oc get co
```
- Result: 32/32 Available=True, Progressing=False, Degraded=False
- Use case: First health check on any cluster issue
