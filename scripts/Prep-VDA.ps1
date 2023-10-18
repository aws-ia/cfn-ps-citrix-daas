<#
.SYNOPSIS
    Prepares XD VDA for installation using CWC library

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
    # Copy XD media locally
    # Write-Host "Copying XD Media locally"
    # cwcOS-Tools\Download-File -FileName $VDA_MediaName -Path $VDA_MediaLocation -ToFolder $VDA_LocalMediaLocation -verbose
    Start-Transcript -Path C:\cfn\log\Prep-VDA.ps1.txt -Append    

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Import-Module ServerManager
    Write-Host "Enabling RDS Server Role"
    Add-WindowsFeature RDS-RD-Server

    # Write-Host "Enabling Desktop Experience"
    # Install-WindowsFeature -Name Desktop-Experience

    Write-Host "Enabling Remote Assistance"
    Install-WindowsFeature -Name Remote-Assistance 

    ### Install Visual C++ Redistributables
    Write-Host "Installing Nuget"
    Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.201" -Force
	Write-Host "Installing VcRedist Module"
	#Reference: https://github.com/aaronparker/Install-VisualCRedistributables, https://docs.stealthpuppy.com/docs/vcredist
	Install-Module -Name "VcRedist" -Force
	Write-Host "Creating VcRedist Temp Folder"
	$VcPath = "C:\Temp\VcRedist"
    New-Item -Path $VcPath -ItemType "Directory"
    Write-Host "Downloading VcRedist Redist to Temp Folder"
	$VcList = Get-VcList
	Save-VcRedist -VcList $VcList -Path $VcPath
    Write-Host "Installing VcRedist"
    $Installed = Install-VcRedist -VcList $VcList -Path $VcPath -Silent

    # Install Pre-req for v7.18 https://docs.citrix.com/en-us/session-recording/current-release/system-requirements.html
    Write-Host "Downloading Microsoft .NET Framework 4.7.1"
    Import-Module BitsTransfer
    Start-BitsTransfer -Source "https://download.visualstudio.microsoft.com/download/pr/4312fa21-59b0-4451-9482-a1376f7f3ba4/9947fce13c11105b48cba170494e787f/ndp471-kb4033342-x86-x64-allos-enu.exe"  -Destination "C:\cfn\scripts\NDP471-KB4033342-x86-x64-AllOS-ENU.exe"
    Write-Host "Installing Microsoft .NET Framework 4.7.1"
    #Install-MSIOrEXE -installerPath c:\cfn\scripts\NDP471-KB4033342-x86-x64-AllOS-ENU.exe -installerArgs @("/Q", "/norestart")
    Start-Process -FilePath "c:\cfn\scripts\NDP471-KB4033342-x86-x64-AllOS-ENU.exe" -ArgumentList "/q /norestart" -Wait

}
catch {
    $_ | Write-AWSQuickStartException
}