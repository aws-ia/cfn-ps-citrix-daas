<#
.SYNOPSIS
    Installs XD RDS VDA using CWC library

    Copyright (c) Citrix Systems, Inc. All Rights Reserved.
.DESCRIPTION
    
.Parameter VDA_MediaName
    Name of VDA Insatll Package
.Parameter VDA_MediaLocation
    Local path to VDA Insatll Package
.Parameter VDA_Controller1
    First XD Controller hostname to use for registration (i.e. "CTX-XDC-001")
.Parameter VDA_Controller2
    Second XD Controller hostname to use for registration (i.e. "CTX-XDC-001")
.Parameter VDA_DNSDomainName
    FQ DNS name of the VDA (i.e. 2k3.local)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string] $VDA_MediaName,
    [Parameter(Mandatory=$true)][string] $VDA_MediaLocation,
    [Parameter(Mandatory=$true)][string] $VDA_Controller1,
    [Parameter(Mandatory=$true)][string] $VDA_Controller2,
    [Parameter(Mandatory=$true)][string] $VDA_DNSDomainName
)

try {
    Start-Transcript -Path C:\cfn\log\Install-VDA.ps1.txt -Append    
    #$driveLetter = cwcOS-Tools\Mount-Iso -IsoPath $VDA_MediaLocation\$VDA_MediaName
	$setupPath = "$VDA_MediaLocation\$VDA_MediaName"

    $VDA_Controller1 = cwcTools\New-FQDN -ComputerName $VDA_Controller1 -DomainName $VDA_DNSDomainName
    $VDA_Controller2 = cwcTools\New-FQDN -ComputerName $VDA_Controller2 -DomainName $VDA_DNSDomainName
    $VDA_Controllers = "$VDA_Controller1,$VDA_Controller2"
    $IncludeAdditional = "Citrix Files for Windows"

    Invoke-Command -ComputerName localhost -ScriptBlock {
        Start-Process -FilePath attrib.exe -LoadUserProfile
        cwcXenDesktop\Install-VdaServer -InstallerPath $args[0]  -installPvd:$false -Controllers $args[1] -EnableRemoteAssistance -IncludeAdditional $args[2] -verbose
    } -argumentlist @($setupPath, $VDA_Controllers, $IncludeAdditional) 

    cwcOS-Tools\Dismount-Iso $driveLetter

    write-Host "XD RDS VDA installed successfully"
}
catch {
    $_ | Write-AWSQuickStartException
}