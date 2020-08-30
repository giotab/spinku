# Kubernetes, Helm and Spinnaker on AKS

# Overview

This solution deploys a Kubernetes (1.15.3) cluster on AKS, installs helm locally and spinnaker on the cluster.

It then deploys a sample asp.net app and setups a blue/green deployment on Spinnaker.

## Requirements

This solution was built on a Windows machine and hence it tries to download some of the tools as `.exe`. It can be changed to work on unix systems relatively easily, by changing the downloaded tools in `environment_installation.ps1`.

### Tools required:

- Powershell 6+ (prerequisite)
  - Using & for running portforwarding in the background
- Git
- Terraform (downloaded by scripts) - to deploy the infrastructure
- Kubectl (downloaded by scripts) - to manage the kubernetes cluster
- Chocolatey (downloaded by scripts) - to install helm
- Helm (downloaded by scripts) - to install Spinnaker
- Spin CLI (downloaded by scripts) - to manage Spinnaker pipelines

## Flows and scripts

### Cleanup

Optionally, we can clear the local folder by running `cleanup.ps1` which will delete all the files downloaded by a previour run. This would not be necessary if we use temporary folders per client, to which we copy the content of this solution.

### Warmup

As describe before, the solution requires a set of tools (powershell AzModule, terraform, kubectl, choco, helm and spin). We can run `environment_installation.ps1` file to install all the neccessary tools. At the moment, these are focused on Windows and hence download `.exe` files, but the file can be improved to detect the operating system and download the relevant binaries.

### Run

The ultimate script resides in `aks_spin_deploy.ps1`. This script requires multiple parameters parameters: 

- `-projectName` project specific
- `-susbcriptionId` project specific, where to deploy the cluster
- `tenantId` project specific, location of the subscription
- `servicePrincipal` to login to azure
- `password` of the service principal, to login to azure

e.g.: `.\aks_spin_deploy.ps1 spinku {sub} {tenant} {service principal} {service principal password}`


#### Terraform

We initialize the terraform backend with a project-specific state file called `terraform-{projectName}.tfstate`. 

Then, we will create the following resources in the subscription defined by `subscriptionId`:

- Resource group: `spinku-we-{projectName}-rg`
- App registration: `spinku-we-{projectName}-ar`
- Service Principal: random name
- AKS: `spinku-we-{projectName}-aks` (dns prefix: `spinku-we-{projectName}-k8s`)
  - Kubernetes version: 1.15.12 (limitation to support Spinnaker)
  - 2 nodes: Standard_D2_v2, 30GB

Eventually, we export the kubeconfig into a file in the home directory under `.kube\{projectName}`

#### Spinnaker

Assuming helm already exists (`environment_installation.ps1`), we install Spinnaker on the new cluster.

Since there are some differences between `stable/spinnaker` chart and its dependencies (specifically `minio`), we clone the latest version of `stable/spinnaker` and modify the `minio` requirement to be `5.0.33` instead of `5.0.9`.

Eventually, we install our updated spinnaker chart and perform port forwarding for the `spin-gate` ([API](http://127.0.0.1:8084)) and `spin-deck` ([UI](http://127.0.0.1:9000)).

#### App deployment

We retrieve a sample asp.net web application and deploy it to kubernetes using `kubectl`. The application will be available [here](http://127.0.0.1:7000).

### Notes

All the endpoints are hidden behind a proxy and in order to get to them you should run `kubectl proxy`. To make thme publicly available, a gateway should be installed or expose the cluster through a VNet and public IP address.
