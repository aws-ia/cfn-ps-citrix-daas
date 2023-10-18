<#
.SYNOPSIS
    Prepares Cloud Connector for installation.

    Copyright (c) Citrix Systems, Inc. All Rights Reserved.
.DESCRIPTION
    
#>
[CmdletBinding()]
param(
    # [Parameter(Mandatory=$true)][string] $VDA_MediaName,
    # [Parameter(Mandatory=$true)][string] $VDA_MediaLocation,
    # [Parameter(Mandatory=$false)][string] $VDA_LocalMediaLocation = (Join-Path -Path $ENV:Temp -ChildPath "Citrix")
)

try {
	Start-Transcript -Path C:\cfn\log\Prep-CloudConnector.ps1.txt -Append    
	
    # Install Pre-req for Citrix Cloud Connector, required as of @4/15/2019
	Write-Host "Downloading Microsoft .NET Framework 4.7.2"
	Import-Module BitsTransfer
    Start-BitsTransfer -Source "https://cwsproduction.blob.core.windows.net/downloads/redist/NDP472-KB4054530-x86-x64-AllOS-ENU.exe"  -Destination "C:\cfn\scripts\NDP472-KB4054530-x86-x64-AllOS-ENU.exe"
	Write-Host "Installing Microsoft .NET Framework 4.7.2"
	#Install-MSIOrEXE -installerPath c:\cfn\scripts\NDP471-KB4033342-x86-x64-AllOS-ENU.exe -installerArgs @("/Q", "/norestart")
    Start-Process -FilePath "c:\cfn\scripts\NDP472-KB4054530-x86-x64-AllOS-ENU.exe" -ArgumentList "/q /norestart" -Wait

}
catch {
	$_ | Write-AWSQuickStartException
}