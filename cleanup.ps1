param (
    [string]$projectName = $(throw "-projectName is required.")
)

if (Test-Path "terraform/.terraform") 
{
    Remove-Item -Path "terraform/.terraform" -Recurse -Force
}

if (Test-Path charts) 
{
    Remove-Item -Path charts -Recurse -Force
}

if (Test-Path chocolatey) 
{
    Remove-Item -Path chocolatey -Recurse -Force
}

if (Test-Path "kubectl.exe") 
{
    Remove-Item "kubectl.exe"
}

if (Test-Path "spin.exe") 
{
    Remove-Item "spin.exe"
}

if (Test-Path "terraform.exe") 
{
    Remove-Item "terraform.exe"
}