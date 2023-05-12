# GitOps

## Introduction
This [GitOps](https://www.weave.works/technologies/gitops/) repository aims to automate and streamline the deployment and management of applications and infrastructure using Git as a single source of truth. By leveraging the [GitOps](https://www.weave.works/technologies/gitops/) methodology, we can reduce human error, increase the efficiency of the deployment process, and maintain a consistent and transparent history of changes.

This repository uses [Flux](https://fluxcd.io/), a [GitOps](https://www.weave.works/technologies/gitops/) [Kubernetes operator](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/), to manage deployments in a Kubernetes cluster.

This README will guide you through installation and local testing with Kind and Minikube and provide an overview of Flux and its common commands.

## Flux Workflow
[Flux](https://fluxcd.io/) takes instructions from Git, the single source of truth. Users create Git commits and push them to a repository Flux is monitoring. The Git repository Flux is monitoring is configured in Kubernetes using a [GitRepository](https://fluxcd.io/flux/components/source/gitrepositories/) Custom Resource, which is a [Source Controller](https://fluxcd.io/flux/components/source/).

The [Source Controller](https://fluxcd.io/flux/components/source/) pulls commit data into the cluster and deploys the Kubernetes manifests. Manifest can be generated using [Kustomize](https://kustomize.io/) or [Helm](https://helm.sh/) charts. Manifests that are no longer used are marked for Garbage collection and removed.

Flux will also decrypt secrets stored in the repository using [SOPS](https://github.com/mozilla/sops).

Flux will also post [notifications](https://fluxcd.io/flux/components/notification/) when changes are detected.

## Required Software

### For macOS

1. **Homebrew:** To install the required software, we first need to install Homebrew, the package manager for macOS. Open a terminal and run the following command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. **Kubectl:** Kubectl is a command-line tool for controlling Kubernetes clusters. Install it by running:

```bash
brew install kubectl
```

3. **Kind:** Kind is a tool for running Kubernetes clusters using Docker containers as nodes. Install it with the following command:

```bash
brew install kind
```

4. **Flux:** Flux is a GitOps Kubernetes operator. Install it with this command:

```bash
brew install fluxcd/tap/flux
```

5. (Optionally/WIP) **Minikube:** Minikube is a tool that allows you to run a single-node Kubernetes cluster locally. Install it using:

```bash
brew install minikube
```

### For Arch GNU/Linux

1. **Kubectl:** Kubectl is a command-line tool for controlling Kubernetes clusters. Install it by running:

```bash
pacman -S kubectl
```

2. **Kind:** Kind is a tool for running Kubernetes clusters using Docker containers as nodes. Install it with the following command:

```bash
yay -S kind
```

3. **Flux:** Flux is a GitOps Kubernetes operator. Install it with this command:

```bash
yay -S flux-bin
```

4. (Optionally/WIP) **Minikube:** To install Minikube on Linux, follow the instructions in the [official Minikube documentation](https://minikube.sigs.k8s.io/docs/start/).

```bash
yay -S minikube
```

## Install BATS submodules

### Init and Update
```bash
git submodule update --init
```

## Run Locally with Kind and Minikube

### Testing with Kind

1. Create a new Kind cluster by running the following command:

```bash
./test/run
```

2. Deploy your application to the Kind cluster:

```
kubectl apply -f /path/to/your/k8s/manifests
```

3. Verify the deployment by running:

```
kubectl get pods
```

4. When you're done testing, delete the Kind cluster:

```
kind delete cluster
```

### Testing with Minikube Testing
You'll need a Kubernetes cluster v1.20 or newer with LoadBalacner support. You will need 2 CPUs and 8GB of memory.

1. Set the hypervisor driver. Linux you can use KVM.

```bash
minikube config set driver kvm2
```

2. Create a VM and install Kubernetes
```bash
minikube start --memory=8192 --cpus=2 --kubernetes-version=v1.23.17
```

3. Run tests against a new install Git server and Flux configuration
```bash
./test/bats/bin/bats test/gitsrv.bats test/flux.bats
```

## Flux Overview and Common Commands

Flux is a GitOps Kubernetes operator that watches your Git repository and automatically synchronizes the desired state of your Kubernetes resources with the actual state in your cluster.

Reconcile changes in the Git repository and apply them to the cluster
```bash
flux reconcile source git flux-system
```

Watch Flux status as it reconciles the cluster

```bash
watch flux get kustomizations
```

Tail the Flux reconciliation logs
```bash
flux logs --all-namespaces --follow --tail=10
```

List all the Kubernetes resources managed by Flux
```bash
flux tree kustomization flux-system
```
