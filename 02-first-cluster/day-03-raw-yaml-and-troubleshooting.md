# Day 3 — Raw YAML, Custom Content, and Real Troubleshooting

**Date:** 2026-06-07

## Goal
Move beyond `oc new-app` and deploy a workload entirely from raw YAML manifests, end-to-end: Deployment → Service → Route → ConfigMap. Encounter and resolve real failures along the way.

## Workload Deployed

Apache httpd 2.4 on Red Hat UBI9, serving a custom `index.html` mounted via ConfigMap.

registry.access.redhat.com/ubi9/httpd-24:latest

## Manifest Files (httpbin-manifests/)

| File | Resource |
|------|----------|
| deployment.yaml | Deployment with resource requests/limits, tcpSocket probes, volume mount |
| service.yaml | ClusterIP Service, named port `http` |
| route.yaml | Edge-terminated Route with HTTP→HTTPS redirect |
| configmap.yaml | ConfigMap containing the custom `index.html` |

Applied with `oc apply -f <file>`.

## Three Failures Diagnosed and Resolved

The deployment didn't work first try — went through three distinct failure modes, each instructive. Documented in detail in `99-runbooks/pod-startup-failures.md`.

1. **SCC blocked the first image** (`kong/httpbin:0.2.2`) — the bundled `pipenv` binary failed to exec under the namespace-assigned UID. Switched to UBI9-httpd, which is built for arbitrary-UID OpenShift environments.
2. **Wrong image tag** (`docker.io/mccutchen/go-httpbin:v2`) — the bare `v2` tag didn't exist at the registry. Diagnosed via `oc describe pod` events showing `manifest unknown`.
3. **Liveness probe returned 403** — UBI9-httpd serves a 403 at `/` until content exists in `/var/www/html`. Switched probes from `httpGet` to `tcpSocket` — sufficient for liveness and resilient to changing content.

## Concepts Cemented

| Concept | Implementation |
|---------|----------------|
| Deployment selector / pod template label contract | `spec.selector.matchLabels` must match `spec.template.metadata.labels` |
| Resource requests vs limits | `requests` = scheduler input; `limits` = enforcement ceiling |
| Probe types — HTTP vs TCP vs exec | tcpSocket for opaque applications; HTTP when path semantics known |
| OpenShift SCC | `restricted-v2` is default; assigns random UID from namespace range |
| ConfigMap volume mount | Cluster-side text content mounted as a file inside the container |
| Live config update | `oc edit configmap` propagates content to mounted volume without pod restart |
| Edge TLS termination | Router terminates TLS, talks plain HTTP to backend pod |

## The Custom Page

The mounted `index.html` documents itself — explicitly states what's serving it and where the content came from. Visitors to the page see the full path:Route → Service → Endpoint → Pod → ConfigMap volume

Working live at:
`https://httpbin-arupd21-dev.apps.rm3.7wse.p1.openshiftapps.com`

## Phase 5 — Deliberate Failure Injection

Four failure scenarios injected and recovered, building the L3 muscle of "break-then-fix as a learning method."

### What I broke

1. **Bad image tag** — `oc set image` to nonexistent tag → ImagePullBackOff
2. **Service selector mismatch** — patched service to select on nonexistent label → endpoints disappear silently
3. **Wrong ConfigMap volume reference** — patched deployment to reference nonexistent ConfigMap → new pods stuck in ContainerCreating
4. **Resource quota exhaustion** — scaled to 100 replicas → hit pod-count quota (50) and CPU quota (3)

### What I learned

- Kubernetes is conservative: old healthy pods stay running while new broken pods fail
- `oc get endpoints` is the diagnostic shortcut for "Service appears broken"
- `ContainerCreating` is a vague status; always check events
- ResourceQuota rejects at admission; the broken pods never exist — look at the ReplicaSet, not pods
- `oc rollout undo` is the universal first-response for rollout-introduced failures

### Recovery times observed

- Image tag fix: 30 seconds to healthy
- Selector mismatch fix: instant (endpoints repopulate)
- ConfigMap reference fix: 30 seconds to new healthy ReplicaSet
- Quota exhaustion fix: instant (scale-back), 30s cleanup

Complete runbook in [99-runbooks/failure-injection-and-recovery.md](../99-runbooks/failure-injection-and-recovery.md)

## Next

Day 4 — AWS-based OpenShift IPI install for cluster-admin scenarios. MachineConfig, etcd operations, node management, and Operator installation — all of which require cluster-admin and aren't available in Sandbox.
