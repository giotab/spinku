param(
    $downloadLocation = '.'
)

$env:PATH += ';' + $downloadLocation

# Install Az Module if neccessary
if (! (Get-Module -ListAvailable -Name Az)) {
    Write-Host Installing Az Module
    Install-Module -Name Az -AllowClobber -Scope CurrentUser
    Write-Host Az Module installed successfully
}

# Install kubectl
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (!(Test-Path $downloadLocation))
{
    New-Item -ItemType Directory $downloadLocation -ErrorAction SilentlyContinue | out-null
} 
$uri = "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
Write-Host -ForegroundColor White "==>Getting download link from  $uri"   
$req = Invoke-WebRequest -UseBasicParsing -Uri $uri
try
{
    Write-Host -ForegroundColor White "==>analyzing Downloadlink"   
    $downloadlink = ($req.Links | Where-Object href -Match "kubectl.exe").href
}
catch
{
    Write-Warning "Error Parsing Link"
    Break
}
Write-Host -ForegroundColor White "==>starting Download from $downloadlink using Bitstransfer"   
Start-BitsTransfer $downloadlink -DisplayName "Getting KubeCTL from $downloadlink" -Destination $downloadLocation
$KubeCtlLocation = Join-Path $downloadLocation "kubectl.exe"
Unblock-File $KubeCtlLocation

# Install Terraform
$terraformUri = "https://releases.hashicorp.com/terraform/0.12.29/terraform_0.12.29_windows_amd64.zip"
Start-BitsTransfer $terraformUri
Expand-Archive -Path "terraform_0.12.29_windows_amd64.zip" -DestinationPath $downloadLocation
Remove-Item "terraform_0.12.29_windows_amd64.zip"

# Install chocolatey
$env:ChocolateyInstall="./chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iwr https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression

# Install helm
./chocolatey/choco.exe install kubernetes-helm --force -y

$req = Invoke-WebRequest -UseBasicParsing -Uri "https://storage.googleapis.com/spinnaker-artifacts/spin/latest"
$latestSpinCli = [System.Text.Encoding]::ASCII.GetString($req.Content)
Start-BitsTransfer ("https://storage.googleapis.com/spinnaker-artifacts/spin/{0}/windows/amd64/spin.exe" -f $latestSpinCli)