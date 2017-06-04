<#
.SYNOPSIS
Installs Windows container role, Windows Server Core image, and Docker on an Azure Virtual Machine. Because the virtual machine requires a reboot, a scheduled task is created for post re-boot configuration.

.DESCRIPTION
Installs Windows container role, Windows Server Core image, and Docker on an Azure Virtual Machine. Because the virtual machine requires a reboot, a scheduled task is created for post re-boot configuration.

.PARAMETER adminUser
Administrative user name consumed from Azure Resource Manager template. This ensures that the post-reboot script runs under the context of the admin use, and thus is visible when this account is used to log into the virtual machine.

.EXAMPLE
azure-container.ps1 -admin azureuser
#>

param (
[string]$adminUser
)

# Script body for post reboot execution.

function Get-InstallScript {
    "   
    # TP5 Contianer Installation
    # Install Windows Server Core Image
    netsh advfirewall firewall add rule name='Docker daemon' dir=in action=allow protocol=TCP localport=2375
    new-item -Type File c:\ProgramData\docker\config\daemon.json
    Add-Content 'c:\programdata\docker\config\daemon.json' @'
    { 
        `"hosts`": [`"tcp://0.0.0.0:2375`", `"npipe://`"]
    }
    new-item -Type File c:\ProgramData\docker\config\daemon-template.json
    Add-Content 'c:\programdata\docker\config\daemon-template.json' @'
    { 
        `"hosts`": [`"tcp://0.0.0.0:2375`", `"npipe://`"],
        `"tlsverify`": true,
        `"tlscert`": `"C:\\cert.ext`",
        `"tlskey`": `"C:\\cert.ext`",
        `"tlscacert`": `"C:\\cert.ext`"
    }
'@
    "
}

Get-InstallScript > c:\windos-containers.ps1

# Create scheduled task.

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoExit c:\windos-containers.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "scriptcontianers" -Action $action -Trigger $trigger -RunLevel Highest -User $adminUser | Out-Null

# Install container role

Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider
Restart-Computer -Force      
