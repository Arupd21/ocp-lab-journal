# Runbook: Pod Startup Failures on OpenShift

Three failure modes encountered while deploying a real workload on OpenShift Sandbox (ROSA 4.21). Each has distinct symptoms and remediation. Documented from live troubleshooting, not theory.

## Failure 1 — SCC blocks image (`exec: operation not permitted`)

### Symptoms
- Pod cycles through `CrashLoopBackOff`
- `oc logs <pod>` shows a single line: `exec /path/to/binary: operation not permitted`
- No application output at all
- Probes don't get a chance to run

### Root cause
The container image's startup binary expects to run as a specific UID baked into the image. OpenShift's `restricted-v2` SCC (the namespace default) assigns the pod a random UID from the namespace's pre-allocated range — not the image's expected one. The kernel rejects `exec` because the running UID lacks permission on the binary.

### Diagnosis commands

```bash
oc logs <pod>
oc get pod <pod> -o jsonpath='{.metadata.annotations.openshift\.io/scc}'
oc get pod <pod> -o jsonpath='{.spec.containers[0].securityContext}'
oc get namespace <ns> -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}'
```

The third command reveals the assigned UID; the fourth reveals the namespace's allowed range. If the image expects a UID outside that range, the SCC blocks execution.

### Remediation options
1. **Use an SCC-friendly image** (e.g., `nginxinc/nginx-unprivileged` instead of `nginx`, or any `registry.access.redhat.com/ubi9/*` image). Best for most cases.
2. **Bind the workload's ServiceAccount to a more permissive SCC** (`anyuid`) — requires cluster-admin, not available on Sandbox.
3. **Override `runAsUser` in pod spec** — fails on `restricted-v2` if outside namespace range; only useful on permissive clusters.

## Failure 2 — Image registry path/tag doesn't exist (`ImagePullBackOff`)

### Symptoms
- Pod stuck in `ImagePullBackOff` or `ErrImagePull`
- `oc describe pod` events show: `Failed to pull image "X": manifest unknown`

### Root cause
Tag specified in the manifest doesn't exist at the registry. Common with bare major tags (e.g., `:v2`) when the image only publishes semver-pinned tags (e.g., `:2.18.3`). On some clusters, mirror configurations also obscure the actual fetch path in the events log.

### Diagnosis commands

```bash
oc describe pod <pod> | tail -30
```

Read the events. Look for `manifest unknown`, `unauthorized`, or `no such host`.

### Remediation
- Confirm the image and tag exist (browse the registry's web UI or `skopeo inspect docker://<image>:<tag>`).
- Pin to a specific version, not a bare major tag.
- Prefer registries the cluster can reach: `registry.access.redhat.com` and `quay.io` are nearly always allowed; `docker.io` works on most clusters but may be slower or rate-limited.

## Failure 3 — Probes fail on a healthy container (`Running` with restart loop)

### Symptoms
- Pod status: `Running`, NOT `CrashLoopBackOff`
- `RESTARTS` counter steadily increasing (5+ restarts in 5 minutes)
- `READY` stays at `0/1`
- `oc describe pod` events show: `Liveness probe failed: HTTP probe failed with statuscode: 403` (or 404, or connection refused)

### Root cause
The container application is alive and listening. But the HTTP path the probe requests returns a non-2xx status. Kubernetes treats anything outside `[200,400)` as a probe failure → kills the container → restarts → repeats.

Example: UBI9-httpd starts cleanly but returns `403` at `/` until `index.html` is present in `/var/www/html`. An HTTP probe configured for `path: /` fails permanently.

### Diagnosis commands

```bash
oc describe pod <pod> | tail -40
oc exec <pod> -- curl -s -o /dev/null -w "%{http_code}\n" http://localhost:<port>
```

The `curl` from inside the pod confirms whether the application is responsive at all (returning anything non-zero exit), separately from whether the probe path returns 2xx.

### Remediation
1. **Switch to `tcpSocket` probes** when the application's HTTP semantics are opaque or default content isn't desired. Probe just confirms the port is accepting TCP connections — sufficient for liveness in most cases.

```yaml
   livenessProbe:
     tcpSocket:
       port: 8080
     initialDelaySeconds: 15
     periodSeconds: 20
```

2. **Probe a known-good HTTP path** (e.g., a custom `/healthz` if the application provides one).
3. **Provide content** so the default path returns 2xx (e.g., mount an `index.html` via ConfigMap).

## Summary Decision Tree

Pod failing?
├─ exec: operation not permitted → SCC / UID mismatch → use SCC-friendly image
├─ manifest unknown → Image tag missing → fix tag or registry path
├─ Liveness probe failed: 4xx → App alive but path returns wrong code → tcpSocket probe, or fix path
└─ pod stays at 0/1 with restarts → almost always probe-related (see #3)

## Lessons
- `restricted-v2` is the default SCC; production-grade containers are designed for it. If an image doesn't run on it, the image is at fault.
- Lint-clean YAML can still be rejected by the API server (case sensitivity on `kind:`, schema validation server-side).
- `tcpSocket` probes are underrated. Use them when you don't control the application's HTTP behavior.
- Always check `oc describe pod` events as the *first* diagnostic step — most failures are in plain English there.
