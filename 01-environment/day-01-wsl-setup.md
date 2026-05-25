# Day 1 — WSL2 Lab Environment Setup

**Date:** 2026-05-25

## Goal
Tune WSL2 for OpenShift lab work and install all required client tooling.

## WSL2 Configuration

Created `%UserProfile%\.wslconfig` with:
- Memory: 12 GB
- Swap: 4 GB
- Processors: 8
- autoMemoryReclaim: gradual (releases memory back to Windows when idle)
- sparseVhd: true (shrinks virtual disk when files are deleted)

Verified: `free -h` reports 11 Gi available, `nproc` reports 8.

## Installed Client Tools

| Tool | Version | Purpose |
|------|---------|---------|
| oc | 4.21.15 | OpenShift CLI |
| kubectl | v1.34.1 | Kubernetes CLI |
| helm | v3.21.0 | Helm package manager |
| podman | 4.9.3 | Container engine (Red Hat default) |
| yq | v4.53.2 | YAML processor |
| jq | 1.7 | JSON processor |
| kustomize | v5.x | Kubernetes manifest overlays |

Installation method varied by tool:
- `oc` / `kubectl` — Red Hat mirror tarball (version-matched, single download)
- `helm` — official get-helm-3 install script
- `yq` — direct binary download from GitHub releases (Mike Farah's Go-based yq)
- `podman`, `jq` — Ubuntu apt packages
- `kustomize` — official install_kustomize.sh script

All binaries placed in `/usr/local/bin/` to keep them on PATH and outside apt's reach.

## Shell Configuration

Aliases configured in `~/.bashrc`:
- `k` → kubectl, `o` → oc (the two main clients)
- Sub-aliases: `kgp` (get pods), `kgn` (get nodes), `ogco` (get clusteroperators), etc.

Bash completion enabled for both clients, including completion via aliases.
Custom PS1 prompt for visual context awareness.

## Verification

All client tools verified via `--version` (or `--client` for kubectl/oc).
Podman hello-world container ran successfully end-to-end.
Kustomize transform test confirmed namePrefix, replica, and image-tag overlays apply correctly.

## Issues Encountered

- WSL2 root filesystem reports as "not a shared mount" — cosmetic warning from Podman, no functional impact in lab use.
- Stale `minikube` context in kubeconfig caused connection-refused errors when running `k get pods` without an active cluster. Resolved by unsetting current-context; minikube context retained for later use.

## Next

Day 2 — Install CodeReady Containers (CRC), log into single-node OpenShift, explore the console and cluster.

