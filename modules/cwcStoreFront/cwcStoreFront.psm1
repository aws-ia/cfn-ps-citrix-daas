
<#
.SYNOPSIS
    This module file contains single-sourced SF functions.
.DESCRIPTION
    This module file contains single-sourced StoreFront functions
.NOTES
    Copyright (c) Citrix Systems, Inc. All rights reserved.
#> 
Set-StrictMode -Version Latest

function New-SFDeployment {
    <#
    .SYNOPSIS
        Imports modules to create single SF Server deployent and for site creation.
    .DESCRIPTION
        Imports modules located on StoreFront Server for server deployment and site creation.
    .PARAMETER XDServers
        Comma seperated string of XML Brokers (i.e. "CTX-XDC-001.2k3.local,CTX-XDC-002.2k3.local")
    .PARAMETER URL
        The Base URL which will be used for site creation. If none specified by user, hostname will be used in base URL.
    .PARAMETER FarmName
        Name for the Farm that will be created
    .PARAMETER FarmType
        Type of Farm that will be connected to "XenDesktop" or "XenApp"
    .PARAMETER Port
        Port for connecting to farm
    .PARAMETER TransportType
        Transport protocol used to connect to XML brokers in farm
    .PARAMETER HTTPPort
        Port to connect to XML brokers in farm when HTTP transport protocol is used
    .PARAMETER HTTPSPort
        Port to connect to XML brokers in farm when HTTPS transport protocol is used
    .PARAMETER LoadBalancing
        Bool specifing if loadbalancing will be used
    .PARAMETER SSLRelayPort
        Port to use when implementing SSL Relay
    .PARAMETER AuthenticationVirtualPath
        IIS Virtual Path for StoreFront Authentication
    .PARAMETER StoreVirtualPath
        IIS Virtual Path for StoreFront Receiver Store
    .PARAMETER WebReceiverVirtualPath
        IIS Virtual Path for StoreFront Web Receiver Store
    .PARAMETER RoamingVirtualPath
        IIS Virtual Path for StoreFront Roaming
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]  [array]$XDServers,
        [Parameter(Mandatory=$true)]  [string]$URL,
        [Parameter(Mandatory=$true)]  [string]$FarmName,
        [Parameter(Mandatory=$true)]  [string]$FarmType,
        [Parameter(Mandatory=$true)]  [string]$TransportType,
        [Parameter(Mandatory=$false)]  [int]$HTTPPort = 80,
        [Parameter(Mandatory=$false)]  [int]$HTTPSPort = 443,
        [Parameter(Mandatory=$true)]  [bool]$LoadBalancing,
        [Parameter(Mandatory=$false)]  [int]$SSLRelayPort = 443,
        [Parameter(Mandatory=$false)]  [string]$AuthenticationVirtualPath = '/Citrix/Authentication',
        [Parameter(Mandatory=$false)]  [string]$StoreVirtualPath = '/Citrix/Store',
        [Parameter(Mandatory=$false)]  [string]$WebReceiverVirtualPath = '/Citrix/StoreWeb',
        [Parameter(Mandatory=$false)]  [string]$RoamingVirtualPath = '/Citrix/Roaming'
    )
	
    if ($TransportType -eq "HTTP") {
	    $Port = $HTTPPort
    } ElseIf ($TransportType -eq "HTTPS") {
	    $Port = $HTTPSPort
    } Else {
	    Throw "Specified transport type is not supported. Configure 'StoreFront Transport Type' variable with value HTTP or HTTPS"
    }
    
	#ClusterConfigurationModule\Set-DSInitialConfiguration -hostBaseUrl $URL `
    Set-DSInitialConfiguration -hostBaseUrl $URL `
					   -farmName $FarmName `
					   -farmType $FarmType `
					   -servers $XDServers `
					   -port $Port `
					   -transportType $TransportType `
					   -sslRelayPort $SSLRelayPort `
					   -loadBalance $LoadBalancing `
					   -AuthenticationVirtualPath $AuthenticationVirtualPath `
					   -StoreVirtualPath $StoreVirtualPath `
					   -WebReceiverVirtualPath $WebReceiverVirtualPath `
					   -RoamingVirtualPath $RoamingVirtualPath
	

}

function Install-SF {
    <#
    .SYNOPSIS
        Silently install SF using path provided.         
    .DESCRIPTION
        Silently install StoreFront Server using path to CitrixStoreFront-x64.exe provided. 
    .PARAMETER InstallerPath
        Path to CitrixStoreFront-x64.exe (local path or network share)
    .PARAMETER ExpectedExitCode
        The expected exit code returned from installer. This is used to compare with actual return code to determine if installation PASSES.
    .EXAMPLE
        Install-SF -InstallerPath "\\eng.citrite.net\XenDesktop\xd\main\59\Image-Full\x64\StoreFront\CitrixStoreFront-x64.exe"

        Description
        -----------
        Install the DDC component Storefront using the CitrixStoreFront-x64.exe executable and location provided.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]  [string]$InstallerPath,
        [Parameter(Mandatory=$false)] [int] $ExpectedExitCode = 0
    )

    $installArgs = ('-silent')
    Install-MSIOrEXE -InstallerPath $InstallerPath -InstallerArgs $installArgs -ExpectedExitCode $ExpectedExitCode -Verbose
}

function Start-ClusterJoinService {
    <#
    .SYNOPSIS
        Start Citrix Cluster Join Service
    .PARAMETER Path
        Path to store SF passcode
    .PARAMETER FileName
        Filename to store SF passcode
    #>
    Write-Host "Import StoreFront modules"
    $dsInstallProp = Get-ItemProperty -Path HKLM:\SOFTWARE\Citrix\DeliveryServices -Name InstallDir
    $dsInstallDir = $dsInstallProp.InstallDir
    $scriptsParent = $dsInstallDir.TrimEnd("\")
    . "$dsInstallDir\Scripts\ImportModules.ps1"

    Write-Host "Start Cluster Join Service"
    ClusterConfigurationModule\Start-DSClusterJoinService

    Write-Host "Start service"
    $mServiceName = "CitrixClusterService"

    # Start Service
    $mService = Get-Service -Name $mServiceName

    If ($mService.Status -ne "Running") {
	    Set-Service -Name $mServiceName -StartupType Manual
	    Set-Service -Name $mServiceName -Status Running
    }
    Write-Host 	"Service is $(Get-Service -Name $mServiceName | Select -ExpandProperty Status)"
}

function Generate-SFPasscode {
    <#
    .SYNOPSIS
        Start Citrix Cluster Service and Generates a passcode
    .PARAMETER Path
        Path to store SF passcode
    .PARAMETER FileName
        Filename to store SF passcode
    #>
    [CmdletBinding()]
    Param (
	    [Parameter(Mandatory=$false)][string]$Path = "$env:temp\Citrix",
        [Parameter(Mandatory=$false)][string]$FileName = "STFPassCode.txt"
    )

    cwcStoreFront\Start-ClusterJoinService

    if (!(Test-Path $Path)) {
        Write-Host "$Path does not exist, creating ..." 
        mkdir $Path
    }

    Write-Host $(Get-DSClusterServiceLocalPasscode).Passcode
    $(Get-DSClusterServiceLocalPasscode).Passcode | Out-File -Force -FilePath $Path\$FileName
}

function Set-IISDefaultSite {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)][String]$SF_TransportType,
        [Parameter(Mandatory=$true)][String]$SF_URL,
        [Parameter(Mandatory=$false)][String]$SF_WebReceiverVirtualPath = '/Citrix/StoreWeb',
	    [Parameter(Mandatory=$false)][String]$DefaultIISLocation = "C:\inetpub\wwwroot",
        [Parameter(Mandatory=$false)][String]$DefaultHtmlFile = "StoreFrontWebSite.html"
    )
    
    If ($SF_TransportType -eq "HTTPS") {
	    [String]$Location = $SF_URL +  $SF_WebReceiverVirtualPath
    } Else {
	    [String]$Location = $SF_WebReceiverVirtualPath
    }

    [String]$HtmlContent = '<script type="text/javascript">
    <!--
    window.location="' + $($Location) + '";
    // -->
    </script>'

    Write-Host "Load IIS cmdlets"
    Import-Module WebAdministration
	
	Write-Host "Generate file $($DefaultIISLocation)"
	$HtmlContent > "$($DefaultIISLocation)\$($DefaultHtmlFile)"
	
	Write-Host "Configure new default document" 
	Add-WebConfigurationProperty //defaultDocument/files  "IIS:\sites\Default Web Site" -AtIndex 0 -Name collection -Value $($DefaultHtmlFile)
}

Export-ModuleMember New-SFDeployment, Install-SF, Generate-SFPasscode, Start-ClusterJoinService, Set-IISDefaultSite