param (
    [Parameter(Mandatory=$true)][string]$projectName,
    [Parameter(Mandatory=$true)][string]$subsriptionId,
    [Parameter(Mandatory=$true)][string]$tenantId,
    [Parameter(Mandatory=$true)][string]$servicePrincipal,
    [Parameter(Mandatory=$true)][string]$password
)

$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

Write-Host  -ForegroundColor Yellow Creating AKS cluster for $projectName in $subsriptionId 

# Connect to client's subscription. 
Write-Host "Logging into account" -ForegroundColor Yellow
  $pscredential = New-Object -TypeName System.Management.Automation.PSCredential($servicePrincipal, (ConvertTo-SecureString $password -AsPlainText -Force))
  Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId -Subscription $subsriptionId

# Set terraform backend per project
Write-Host "Initializing terraform" -ForegroundColor Yellow
  Set-Location terraform
  $tfBackendKey = ("`"key=terraform-{0}.tfstate`"" -f $projectName)
  terraform init -backend-config $tfBackendKey
Write-Host "Terraform initialized" -ForegroundColor Yellow

# Normally, this would include terraform plana with an intervention and manual approval
Write-Host "Setting up infrastructure. This might take up to 4 minutes.." -ForegroundColor Yellow
  terraform apply -auto-approve --var projectName=$projectName

# Output kubeconfig per project
  terraform output kube_config > $home\.kube\$projectName
Write-Host "Infrastructure is setup" -ForegroundColor Yellow

  Set-Location .. # Back to root folder

  $env:KUBECONFIG="$home\.kube\$projectName"

# Verify kube nodes exist
  $nodes = kubectl get nodes
  if($nodes) {
    Write-Host "Cluster is up" -ForegroundColor Yellow 
  } else {
    Write-Host "Cluster did not start up"  -ForegroundColor Red
  }

# Add spinaker
# Have to modify the minion version due to misliagned code

kubectl proxy &
Write-Host "Proxy is running at http://127.0.0.1:8081"  -ForegroundColor Yellow

Write-Host "Getting spinnaker files"  -ForegroundColor Yellow
  git clone https://github.com/helm/charts.git
  Set-Location charts/stable/spinnaker/
  ((Get-Content -path requirements.yaml -Raw) -replace 'version: 5.0.9','version: 5.0.33') | Set-Content -Path requirements.yaml

  helm dependency update

Write-Host "Creating spinnaker namespace"  -ForegroundColor Yellow
  kubectl create namespace spinnaker
Write-Host "Created spinnaker namespace"  -ForegroundColor Yellow

Write-Host "Installing spinnaker. This might take up to 9 minutes.."  -ForegroundColor Yellow
  helm install spinnaker . --timeout 15m --namespace spinnaker --debug
  Set-Location ../../../
Write-Host "Installed spinnaker"  -ForegroundColor Yellow

# Port forward for spin-deck (UI) and spin-gate (API)

Write-Host "Setting up port forwarding for spinnaker" -ForegroundColor Yellow
  $gatePod=$(kubectl get pods --namespace spinnaker -l "cluster=spin-gate" -o jsonpath="{.items[0].metadata.name}")
  kubectl wait --for=condition=Ready pod/$gatePod --namespace spinnaker --timeout=300s
  kubectl port-forward --namespace spinnaker $gatePod $(((kubectl get service -n spinnaker "spin-gate" -o json) | ConvertFrom-Json).spec.ports[0].port) &
  $deckPod=$(kubectl get pods --namespace spinnaker -l "cluster=spin-deck" -o jsonpath="{.items[0].metadata.name}")
  kubectl wait --for=condition=Ready pod/$deckPod --namespace spinnaker --timeout=300s
  kubectl port-forward --namespace spinnaker $deckPod $(((kubectl get service -n spinnaker "spin-deck" -o json) | ConvertFrom-Json).spec.ports[0].port) &
Write-Host "Set up port forwarding for spinnaker" -ForegroundColor Yellow
Write-Host Access spinnaker UI at http://127.0.0.1:$(((kubectl get service -n spinnaker "spin-deck" -o json) | ConvertFrom-Json).spec.ports[0].port) -ForegroundColor Blue

# Download sample aspnet app
Write-Host "Setting sample app"  -ForegroundColor Yellow
  kubectl apply -f aspnetapp.yaml
Write-Host "Set sample app"  -ForegroundColor Yellow

Write-Host "Setting up port forwarding for aspnet app" -ForegroundColor Yellow
  kubectl wait --for=condition=Ready pod/aspnetapp
  kubectl port-forward aspnetapp 7000:$(((kubectl get service "aspnetapp" -o json) | ConvertFrom-Json).spec.ports[0].port) &
Write-Host "Set up port forwarding for aspnet app" -ForegroundColor Yellow

Write-Host "Access sample aspnet app at http://127.0.0.1:7000" -ForegroundColor Blue

Write-Host "Setting Green/blue deployment on two replicas" -ForegroundColor Blue
spin pipeline save -f pipeline.json

$stopwatch.Stop()
Write-Host ("The process took {0} minutes and {1}.{2} seconds" -f $stopwatch.Elapsed.Minutes,$stopwatch.Elapsed.Seconds,$stopwatch.Elapsed.Milliseconds) -ForegroundColor DarkGreen