# OpenShift Lab Journal

A structured deep-dive into advanced OpenShift cluster administration.
Each folder documents a focused area of practice with hands-on scenarios,
failure injection exercises, and recovery runbooks — built progressively over
a 6-month plan.

## Lab Environment

- **Daily driver:** WSL2 (Ubuntu 24.04) on Windows 11 — 12 GB RAM allocated to WSL
- **Local OpenShift:** CodeReady Containers (CRC) — single-node OpenShift 4.x
- **Local multi-node Kubernetes:** minikube with 3 nodes
- **Production-scale practice:** OpenShift 4.x IPI on AWS (ap-south-1), spun up for focused sessions

## Client Tooling

| Tool | Version (at start) | Purpose |
|------|--------------------|---------|
| oc | 4.21.15 | OpenShift CLI |
| kubectl | v1.34.1 | Kubernetes CLI |
| helm | v3.21.0 | Helm package manager |
| podman | 4.9.3 | Container engine (Red Hat default) |
| yq | v4.53.2 | YAML processor |
| jq | 1.7 | JSON processor |
| kustomize | v5.x | Kubernetes manifest overlays |

## Structure

| Folder | Focus |
|--------|-------|
| 01-environment | Lab setup, tooling, configuration |
| 02-crc         | CodeReady Containers operations |
| 03-aws-install | OpenShift IPI install/destroy on AWS |
| 04-cluster-anatomy | etcd, ClusterOperators, MachineConfig, certificates |
| 05-failure-recovery | Deliberate failure injection and recovery |
| 06-networking | OVN-Kubernetes, NetworkPolicies, Routes, EgressIP |
| 07-storage | StorageClasses, PVs, StatefulSets, backup |
| 08-upgrades | Cluster lifecycle, version upgrades |
| 09-multi-cluster | ACM, ArgoCD ApplicationSets |
| 99-runbooks | Reusable incident response runbooks |

## Background

I'm Arup Das, a Container Platform Engineer with 5 years of infrastructure
experience (Linux Admin → OpenShift). This journal documents my structured
path toward deeper OpenShift expertise and the Red Hat OpenShift Administrator
(EX280) certification.

# webhook test Sat Jun 13 22:25:57 UTC 2026
