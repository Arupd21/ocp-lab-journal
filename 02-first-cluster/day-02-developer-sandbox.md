# Day 2 — First OpenShift Cluster (Developer Sandbox)

**Date:** 2026-06-02

## Goal
Stand up a real OpenShift cluster, log in via `oc`, deploy a workload, expose it via Route, and reach it from the public internet.

## Pivot: From CRC to Developer Sandbox

Original plan was to run OpenShift locally via CodeReady Containers (CRC) inside WSL2. This failed at `crc setup` with:
CRC has a hard check against WSL2 because nested KVM inside the Hyper-V-managed WSL2 VM doesn't reliably support libvirt. Windows 11 Home additionally lacks Hyper-V, so CRC-on-Windows was also off the table.

Pivoted to **Red Hat OpenShift Developer Sandbox** — a free shared OpenShift 4.21 cluster on ROSA (AWS). Tradeoff: namespace-scoped access (no cluster-admin), but the workload-level surface area is identical to real OpenShift and matches everything in EX280 scope.

For cluster-admin work (etcd, MachineConfig, upgrades, node operations), the plan now is OpenShift IPI on AWS, spun up on weekends. Better setup than CRC would have given anyway — CRC is single-node only.

## Cluster Details

- **Platform:** Red Hat OpenShift Service on AWS (ROSA)
- **OpenShift version:** 4.21.15
- **Kubernetes version:** 1.34.6
- **Client version:** oc 4.21.15 (exact match — zero version skew)
- **API server:** `https://api.rm3.7wse.p1.openshiftapps.com:6443`
- **Assigned namespaces:** `arupd21-dev`, `arupd21-stage`

## Workload Deployed

Used `oc new-app` (OpenShift-idiomatic) rather than raw manifests:

```bash
oc new-app --name=nginx-hello --image=nginxinc/nginx-unprivileged:1.27
oc expose service/nginx-hello
```

Chose `nginx-unprivileged:1.27` instead of the standard `nginx` image specifically because OpenShift's default `restricted-v2` SCC blocks containers running as root. `nginx-unprivileged` runs as non-root on port 8080 — first real demonstration of SCC behavior gating workload choices.

## Troubleshooting Journey

Encountered an "Application is not available" page on the Route. The full chain was healthy internally:

- Deployment: `1/1 Running`
- Service endpoints: `10.131.1.102:8080`
- Route status: `Admitted: True`, `targetPort: 8080-tcp`
- In-cluster curl from inside pod: HTTP 200
- In-cluster curl from a temporary `curlimages/curl` pod via Service DNS: HTTP 200

Yet external HTTP requests returned the router's fallback error page.

**Root cause:** ROSA shared clusters serve Routes only on TLS by default. The wildcard cert covers `*.apps.rm3.7wse.p1.openshiftapps.com` and the router was rejecting plain HTTP on user-created Routes.

**Fix:**

```bash
oc patch route nginx-hello --type=merge \
  -p '{"spec":{"tls":{"termination":"edge","insecureEdgeTerminationPolicy":"Redirect"}}}'
```

This added edge TLS termination at the router (router terminates TLS, talks plain HTTP to the pod) plus an HTTP→HTTPS redirect for clients hitting the bare hostname.

Result: page served correctly at both `http://` and `https://` URLs.

## Key Concepts Reinforced

| Concept | What I touched |
|---------|----------------|
| `oc login` with token auth | Bearer token from console, copied via "Copy login command" |
| `oc new-app` | Generates Deployment + Service + ImageStream in one shot |
| ImageStreams | OCP's container image abstraction — auto-created by `new-app` |
| Routes | OpenShift's L7 ingress object, served by the cluster's HAProxy router |
| Edge TLS termination | Router terminates TLS; talks plain HTTP to backend pod |
| `insecureEdgeTerminationPolicy` | Controls how the router handles non-TLS requests on a TLS Route |
| SCC implications | Why `nginx-unprivileged` was needed |
| Endpoints | Service-to-pod link; verified via `oc get endpoints` |
| `oc auth can-i --list` | Per-namespace authorization audit |

## Permissions Confirmed via `oc auth can-i --list`

In namespace `arupd21-dev`:
- Full CRUD: `buildconfigs`, `imagestreams`, `imagestreamtags`, `routes`, `deployments`, `services`, `configmaps`, `secrets`
- Read/list: most OpenShift virtualization CRDs (cluster-shared resources)
- **Forbidden (as expected for non-admin):** `nodes`, cluster-level Operators, MachineConfigs

## Next

Day 3 — Explore the OpenShift console (web UI), understand Topology view, work with multiple workloads in the namespace, dig into the YAML of generated resources.

Week 2 — AWS IPI install for cluster-admin scenarios.
