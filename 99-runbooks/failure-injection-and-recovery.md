# Runbook: Deployment Failure Modes — Injection, Diagnosis, Recovery

Four failure scenarios practiced via deliberate injection on a real OpenShift cluster (ROSA 4.21, Developer Sandbox). Each documents the symptom signature, the diagnostic commands that surface root cause, and the recovery patterns used in production.

## Scenario 1 — Bad image tag

### Symptom
- Old pod stays `1/1 Running`
- New pod stuck in `ImagePullBackOff` or `ErrImagePull`
- `oc get deployment` shows desired/available mismatch
- `oc rollout status --timeout=30s` times out

### Diagnosis

```bash
oc rollout status deployment/<name> --timeout=30s
oc rollout history deployment/<name>
oc describe pod -l <selector> | tail -30
```

The new pod's Events section shows: `Failed to pull image "...": manifest unknown`.

### Recovery

```bash
oc rollout undo deployment/<name>
oc rollout status deployment/<name>
```

Reverts to the previous ReplicaSet. Recovery time: <30s. Investigate root cause afterward.

### Key insight
Kubernetes is conservative — it keeps the old working pod running until the new one is healthy. This buys you time. The Deployment object updates immediately, but pod-level damage is contained.

## Scenario 2 — Selector / label mismatch (silent failure)

### Symptom
- Pod is `1/1 Running` ✓
- Service exists ✓
- Route admitted ✓
- Browser shows "Application is not available"
- *Nothing in pod, deployment, or events looks wrong*

### Diagnosis

The diagnostic shortcut that finds this in 5 seconds:

```bash
oc get endpoints <service-name>
```

If `ENDPOINTS: <none>`, the Service cannot find pods. That's the signal.

Then compare what's mismatched:

```bash
oc get svc <service-name> -o jsonpath='{.spec.selector}'
oc get pods -l <expected-label> --show-labels
```

### Recovery

Fix the selector to match real pod labels:

```bash
oc patch service <name> --type=merge -p '{"spec":{"selector":{"app":"<correct-label>"}}}'
```

Endpoints repopulate within seconds. Verify with `oc get endpoints`.

### Key insight
Pod healthy + Service exists + Route admitted ≠ workload reachable. The selector contract between Service and pod labels is invisible until you check Endpoints. Add `oc get endpoints` as your first reflex when an exposed workload appears unreachable.

## Scenario 3 — Wrong ConfigMap (or Secret) reference

### Symptom
- New pod stuck in `ContainerCreating` for >30s (doesn't progress to Running)
- Existing pod stays healthy
- No `ImagePullBackOff`, no `CrashLoopBackOff`
- Most engineers wait, assuming it's slow scheduling

### Diagnosis

```bash
oc describe pod -l <selector> | tail -30
```

Events show:
Warning  FailedMount  ...  MountVolume.SetUp failed for volume "X":
configmap "<name>" not found

The retry pattern in the event (`x8 over 112s`) confirms the kubelet is looping on the missing reference.

### Recovery

Option A — rollback to previous working ReplicaSet:
```bash
oc rollout undo deployment/<name>
```

Option B — forward-fix the reference (GitOps-preferred):
```bash
oc patch deployment <name> --type=merge -p \
  '{"spec":{"template":{"spec":{"volumes":[{"name":"<vol-name>","configMap":{"name":"<correct-name>"}}]}}}}'
```

### Key insight
`ContainerCreating` is a *vague* status. It covers volume mount failures, network attachment failures, image pull failures, and more. Always check pod Events on a pod stuck >30s in this state.

## Scenario 4 — Resource Quota exhaustion

### Symptom
- Deployment shows large gap between desired and available (e.g., `2/100`)
- No "Pending" pods to inspect
- `oc get pods` shows fewer pods than expected
- *The pods that should exist don't exist at all*

This is the trickiest because the failure happens at **admission**, before pods are scheduled.

### Diagnosis

```bash
oc get deployment <name>    # observe desired/available gap
oc get pods -l <selector> --no-headers | wc -l   # confirm count
oc get rs -l <selector> -o jsonpath='{.items[?(@.spec.replicas>0)].metadata.name}'

# Then describe the active ReplicaSet
oc describe rs <active-rs-name> | tail -30
```

Events show repeated:
Warning  FailedCreate  ...  Error creating: pods "..." is forbidden:
exceeded quota: <quota-name>,
requested: count/pods=1, used: count/pods=50, limited: count/pods=50

OR for compute quota:
exceeded quota: compute-deploy,
requested: requests.cpu=50m, used: requests.cpu=3, limited: requests.cpu=3

Also check current quota status:
```bash
oc describe resourcequota -n <ns>
```

### Recovery

Scale back to a sustainable number:
```bash
oc scale deployment/<name> --replicas=<within-quota>
```

If the legitimate requirement exceeds quota, the fix is at the cluster-admin level — request a quota increase from the team that owns the namespace.

### Key insight
ResourceQuota is enforced at the API admission level, not the scheduler. Rejected pods *never exist* — so don't look for them. Look at the ReplicaSet that's trying to create them. Multiple quotas can apply simultaneously (pod count, request totals, limit totals); whichever is exceeded first wins the rejection.

## Decision Tree
Workload not working?
│
├─ Pod running but request fails externally
│   └─ Check oc get endpoints first
│       ├─ Endpoints = <none> → Selector mismatch (Scenario 2)
│       └─ Endpoints populated → Check Route (Day 2 patterns: TLS, host)
│
├─ Pod in ContainerCreating > 30s
│   └─ oc describe pod → Events
│       ├─ FailedMount → Volume/ConfigMap issue (Scenario 3)
│       ├─ FailedAttachVolume → CSI / storage issue
│       └─ NetworkPlugin error → CNI / Multus issue
│
├─ Pod in ImagePullBackOff / ErrImagePull
│   └─ oc describe pod → "manifest unknown" or "unauthorized"
│       ├─ Tag missing → wrong image:tag (Scenario 1)
│       └─ Pull secret issue → registry auth
│
├─ Pod in CrashLoopBackOff
│   └─ oc logs <pod> --previous
│       ├─ "operation not permitted" → SCC blocks image
│       ├─ App-specific error → fix config/code
│       └─ OOMKilled → bump memory limit
│
├─ Pod Running with restarts climbing, status stays Running
│   └─ Liveness probe killing it → check probe path/port semantics
│
└─ Desired replicas > available, but no failing pods exist
└─ oc describe rs <active> → Events
└─ FailedCreate / "exceeded quota" → quota (Scenario 4)

## Recovery Pattern Patterns

| Approach | When to use |
|----------|-------------|
| `oc rollout undo` | Quickest rollback; recent change broke things |
| `oc patch` | Targeted forward-fix; you know exactly what to change |
| `oc apply -f` | GitOps-style; apply the corrected manifest |
| `oc edit` | Interactive; exploratory fix |
| `oc delete + oc apply` | Last resort; resources stuck on immutable fields |

In production, `rollout undo` is the right reflex for any rollout-introduced failure. Forensics after recovery, not during.

## Time-to-Recover Benchmarks (from these exercises)

- Scenario 1 (bad image): rollback in ~30s, full ready in ~60s
- Scenario 2 (selector mismatch): patch in <5s, endpoints repopulate instantly
- Scenario 3 (configmap reference): patch in <5s, new ReplicaSet healthy in ~30s
- Scenario 4 (quota exhaustion): scale fix instant, pod cleanup ~30s

If your real-world recovery times are significantly longer, the bottleneck is usually diagnosis, not the fix itself. Internalize the decision tree above to compress diagnosis time.
