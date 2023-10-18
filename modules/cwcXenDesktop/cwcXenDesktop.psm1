
<#
.SYNOPSIS
    This module file contains single-sourced XenDesktop DDC functions.

    Copyright (c) Citrix Systems, Inc. All Rights Reserved.
.DESCRIPTION
    This module file contains single-sourced XenDesktop Desktop Delivery Controller (DDC) Install functions.
#> 
Set-StrictMode -Version Latest

function Install-DDC {
    <#
    .SYNOPSIS
        Call XenDesktopServerSetup.exe to silently install XenDesktop DDC. 

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Call XenDesktopServerSetup.exe to silently install XenDesktop Desktop Delivery Controller. 
    .Parameter InstallerPath
        Path to XenDesktopServerSetup.exe (local path or network share)
    .Parameter InstallSQL
        Switch parameter indicating whether or not to install sql express, defaults to true, use "-InstallSQL:$false" to turn off 
    .Parameter InstallController
        Switch parameter indicating whether or not to install the "DesktopController" component, defaults to true, use "-InstallController:$false" to turn off 
    .Parameter InstallDesktopStudio
        Switch parameter indicating whether or not to install the "DesktopStudio" component, defaults to true, use "-InstallDesktopStudio:$false" to turn off  
    .Parameter InstallDesktopDirector
        Switch parameter indicating whether or not to install the "DesktopDirector" component, defaults to true, use "-InstallDesktopDirector:$false" to turn off 
    .Parameter InstallLS
        Switch parameter indicating whether or not to enable "LicenseServer" component, defaults to true, use "-InstallLS:$false" to turn off 
    .Parameter InstallStoreFront
        Switch , Add storefront component, default = $false
    .Parameter ConfigureFireWall
        Switch parameter indicating whether or not to configure firewall, defaults to true, use "-ConfigureFireWall:$false" to turn off
    .Parameter Reboot
        Switch parameter indicating whether or not to reboot the machine after installation, defaults to true, use "-Reboot:$false" to turn off 
    .Parameter LogPath
        Path for the installer to put the log files
    .Parameter ExpectedExitCode
        The expected exit code returned from installer. This is used to compare with actual return code to determine if installation PASSES.
    .Parameter UseXenAppBranding
        Switch parameter indicating whether or not to use the XenAppBranding.
    .Parameter InstallDir
        Installation path of DDC
    .EXAMPLE
        Install all DDC Server side components except for license server from already mapped build share:
        Install-DDC -InstallerPath \\eng.citrite.net\ftl\Downloads\xd\main\29\Image-Full\x64\XenDesktop Setup\XenDesktopServerSetup.exe -InstallLS:$false
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]  [string]$InstallerPath,
        [Parameter(Mandatory=$false)] [switch]$InstallSQL=$true,
        [Parameter(Mandatory=$false)] [switch]$InstallController=$true,
        [Parameter(Mandatory=$false)] [switch]$InstallDesktopStudio=$true,
        [Parameter(Mandatory=$false)] [switch]$InstallDesktopDirector=$true,
        [Parameter(Mandatory=$false)] [switch]$InstallLS=$true,
        [Parameter(Mandatory=$false)] [switch]$InstallStoreFront=$false,
        [Parameter(Mandatory=$false)] [switch]$ConfigureFireWall=$true,
        [Parameter(Mandatory=$false)] [switch]$Reboot=$true,
        [Parameter(Mandatory=$false)] [string]$LogPath = (Join-Path -Path $ENV:Temp -ChildPath "Citrix"),
        [Parameter(Mandatory=$false)] [int] $ExpectedExitCode = 0,
        [Parameter(Mandatory=$false)] [switch]$UseXenAppBranding = $false,
        [Parameter(Mandatory=$false)] [string]$InstallDir
    )
    $installargs = cwcXenDesktop\Get-DDCInstallArgs -InstallSQL:$InstallSQL -InstallController:$InstallController -InstallDesktopStudio:$InstallDesktopStudio `
                                      -InstallDesktopDirector:$InstallDesktopDirector -InstallLS:$InstallLS -InstallStoreFront:$InstallStoreFront `
                                      -ConfigureFireWall:$ConfigureFireWall -Reboot:$Reboot -LogPath $LogPath -UseXenAppBranding:$UseXenAppBranding `
                                      -InstallDir $InstallDir -verbose

    cwcInstall\Install-MSIOrEXE -InstallerPath $InstallerPath -installerArgs $installargs -ExpectedExitCode $ExpectedExitCode | Out-Null
}

function Get-DDCInstallArgs {
    <#
    .SYNOPSIS
        Construct XenDesktopServerSetup.exe commandline arguments
        
        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Construct XenDesktopServerSetup.exe commandline arguments 
    .Parameter InstallSQL
        Install sql express
    .Parameter InstallController
        Install the "DesktopController" component 
    .Parameter InstallDesktopStudio
        Install the "DesktopStudio" component  
    .Parameter InstallDesktopDirector
        Install the "DesktopDirector" component 
    .Parameter InstallLS
        Install "LicenseServer" component 
    .Parameter ConfigureFireWall
        Configure firewall 
    .Parameter Reboot
        Reboot the machine after installation 
    .Parameter LogPath
        Path for the installer to put the log files
    .Parameter UseXenAppBranding
        Switch to use the XenApp Branding.
    .Parameter InstallDir
        Installation path of DDC
    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)] [switch]$InstallSQL,
        [Parameter(Mandatory=$true)] [switch]$InstallController,
        [Parameter(Mandatory=$true)] [switch]$InstallDesktopStudio,
        [Parameter(Mandatory=$true)] [switch]$InstallDesktopDirector,
        [Parameter(Mandatory=$true)] [switch]$InstallLS,
		[Parameter(Mandatory=$true)] [switch]$InstallStoreFront,
        [Parameter(Mandatory=$true)] [switch]$ConfigureFireWall,
        [Parameter(Mandatory=$true)] [switch]$Reboot,
        [Parameter(Mandatory=$true)] [string]$LogPath,
        [Parameter(Mandatory=$true)] [switch]$UseXenAppBranding,
        [Parameter(Mandatory=$false)] [string]$InstallDir 
    )

    Write-Verbose "Installer logs located at:'$LogPath'"

    #If user does not specifies the installation path of VDA, it will be installed in default path
    if ([string]::IsNullOrEmpty($InstallDir))
    {
         [System.Collections.ArrayList]$installargs = ("/quiet","/verboselog")
    }
    else
    {
        if (-not (Test-Path $InstallDir))
        {
            Write-Verbose "Create install directory:$InstallDir"
            New-Item $InstallDir -type 'directory' | Out-Null
        }

        [System.Collections.ArrayList]$installargs = ("/quiet", "/installdir '$InstallDir'","/verboselog")
    }
     
    if ($UseXenAppBranding) 
    {
        $installargs.Insert(0,"/xenapp")
    }

    # Looks like there is a bug in powershell where it forces a Count() to the pipeline when the Add method is invoked.
    $installargs.Add("/logpath '$LogPath'") | Out-Null

    # Start components - maybe this should be a function?
    # Turns out that the MetaInstaller required double quotes for the components arg
    $components = '/components "'
	$componentList = @()
    if ($InstallController)
    {
        $componentList += "CONTROLLER"
    }
    if ($InstallDesktopStudio)
    {
        $componentList += "DESKTOPSTUDIO"
    }
    if ($InstallDesktopDirector)
    {
        $componentList += "DESKTOPDIRECTOR"
    }
    if ($InstallLS)
    {
        $componentList += "LICENSESERVER"
    }
    if ($InstallStoreFront)
    {
        $componentList += "STOREFRONT"
    }
	
    $components += ($componentList -join ',')
    $components +=  '"'
    $installargs.Add($components) | Out-Null
    # END components    

    if ($ConfigureFireWall)
    {
        $installargs.Add("/CONFIGURE_FIREWALL") | Out-Null
    }
    if ($Reboot -eq $false) {
        $installargs.Add("/NOREBOOT") | Out-Null
    }
    if ($InstallSQL -eq $false) {
        $installargs.Add("/NOSQL") | Out-Null     
    }
    
    Write-Verbose "DDC Install Arguments: $($installargs)"
    return $installargs.ToArray()
}

function New-DBSchema {
    <# 
    .SYNOPSIS
        Executes XenDesktop database schema SQL scripts.
       
        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
       
    .DESCRIPTION
        Executes XenDesktop database schemas SQL scripts.  Assumes endpoints have been configured.
        Only supports running either of principal or mirror scripts as each script i
        designed to be run on a different SQL server.
        Executes scripts named:
      
        - Principal<SiteDbServer><Datastore>.sql, or
        - Mirror<SiteDbServer><Datastore>.sql
      
        where SiteDbServer is name of database service provider and Datastore is site, log or monitor.
    .PARAMETER SiteDbServer
        Database service provider name default is .\SQLEXPRESS
    .PARAMETER SiteDbName
        Database for Site Stores default is BVT_DB
    .PARAMETER MirrorDbServer
        Database service provider name on mirror db server
    .PARAMETER RunPrincipalScripts
        Execute scripts on principal DB Server.  If not provided, takes value $false
    .PARAMETER RunMirrorScripts
        Execute scripts on mirror DB server.  If not provided, takes value $false  
    #>
    [CmdletBinding()]
    param(
      [parameter(mandatory=$false)][string]$SiteDbServer = '.\SQLEXPRESS',
      [parameter(mandatory=$false)][string]$SiteDbName = 'BVT_DB',
      [parameter(mandatory=$false)][string]$MirrorDbServer = "",
      [parameter(mandatory=$false)][switch]$RunPrincipalScripts,
      [parameter(mandatory=$false)][switch]$RunMirrorScripts
    )

    # Need to get script for all three datastores
    $datastores = ('Site','Logging','Monitor')

    # Run scripts that will configure principal DB server.  Equates to $false if
    # running mirror scripts selected
    if ($RunPrincipalScripts)
    {
        Write-Verbose ("Executing scripts on Principal database server ${SiteDbServer}" | Out-String)
        foreach ($datastore in $datastores)
        {
            # Principal datastore script name
            $databaseScript = "Principal$SiteDbName-$datastore.sql"

            Write-Verbose ("Executing script ${databaseScript}" | Out-String)

            # Run script on given DB server
            Invoke-SqlScript -DBServer $SiteDbServer -SqlScriptPath $databaseScript
        }
    }   
    
    # Run scripts that will configure principal DB server. Equates to $false if
    # running principal scripts selected
    if ($RunMirrorScripts)
    {
        Write-Verbose ("Executing scripts on Mirror database server ${MirrorDbServer}" | Out-String)
        foreach ($datastore in $datastores)
        {
            # Mirror database script name
            $databaseScript = "Mirror$SiteDbName-$datastore.sql"

            Write-Verbose ("Executing script ${databaseScript}" | Out-String)

            # Run script on given DB server
            Invoke-SqlScript -DBServer $MirrorDbServer -SqlScriptPath $databaseScript
        }
    }
}

function Install-Vda {
    <#
    .SYNOPSIS
        Call XenDesktopVdaSetup.exe to silently install VDA and plug-ins. 

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Call XenDesktopVdaSetup.exe to silently install VDA and plug-ins.
    .Parameter InstallerPath
        Path to XenDesktopVDASetup.exe (local path or network share)
    .Parameter InstallVDA
        Switch parameter indicating whether or not to install the "VDA" component, defaults to true, use "-installVDA:$false" to turn off 
    .Parameter InstallPvd
        Switch parameter indicating whether or not to enable PVD, defaults to false, use "-installPvd:$false" to turn off 
    .Parameter InstallPlugin
        Switch parameter indicating whether or not to install the "PLUGINS" component, defaults to true, use "-InstallPlugin:$false" to turn off 
    .Parameter EnableHDXPorts
        Switch parameter indicating whether or not to Enable HDX ports, defaults to true, use "-EnableHDXPorts:$false" to turn off  
    .Parameter Reboot
        Switch parameter indicating whether or not to reboot the machine after installation, defaults to false
    .Parameter LogPath
        Path for the installer to put the log files.
        Logpaths can contain spaces when the path is quoted.
    .Parameter Controllers
       FQDN of the Desktop Delivery Contollers (separated by ,) that VDA will register with.
    .Parameter UseIbizaVdaArgs
       Override the args supplied to the metainstaller with those from the Ibiza VDA.
    .Parameter EnableRemoteAssistance
       Switch parameter indicating whether or not to enable remote assistance(shadowing) or not. Defaults to false.
    .Parameter EnableRemoteManagement
       Switch parameter indicating whether or not to include WinRM - remote management feature in the installation, defaults to false.
	.PARAMETER ExpectedRebootcode
	   Optionally change the expected reboot-required exit-code from the default value of 3. Note this setting is 
	   not needed in Excalibur.
    .Parameter UseXenAppBranding
        Switch parameter indicating whether or not to use the XenAppBranding.    
    .Parameter InstallDir
       Installation path of VDA
    .EXAMPLE
        Install VDA without plugins from already mapped build share, reboot after installation
        Install-VDA -installerPath \\eng.citrite.net\ftl\Downloads\xd\main\29\Image-Full\x64\XenDesktop Setup\XenDesktopVdaSetup.exe -installPlugin:$false -Reboot
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]  [string]$InstallerPath,
        [Parameter(Position=1,Mandatory=$false)] [switch]$InstallVDA=$true,
        [Parameter(Position=2,Mandatory=$false)] [switch]$InstallPvd=$false,
        [Parameter(Position=3,Mandatory=$false)] [switch]$InstallPlugin=$true,
        [Parameter(Position=4,Mandatory=$false)] [switch]$EnableHDXPorts=$true,
        [Parameter(Position=5,Mandatory=$false)] [switch]$Reboot=$true,
        [Parameter(Position=6,Mandatory=$false)] [string]$LogPath = (Join-Path -Path $ENV:Temp -ChildPath "Citrix"),
        [Parameter(Position=7,Mandatory=$false)] [string]$Controllers,
        [Parameter(Position=8,Mandatory=$false)] [switch]$UseIbizaVdaArgs=$false,
        [Parameter(Position=9,Mandatory=$false)] [switch]$EnableRemoteAssistance=$false,
        [Parameter(Position=10,Mandatory=$false)] [string]$XAServerLocation,
        [Parameter(Position=11,Mandatory=$false)] [switch]$EnableRemoteManagement=$false,
        [Parameter(Position=12,Mandatory=$false)][int]$ExpectedRebootcode=3,
        [Parameter(Position=13,Mandatory=$false)] [string]$ExcludedPackages = $null,
        [Parameter(Position=14,Mandatory=$false)] [switch]$UseXenAppBranding = $false,
        [Parameter(Position=15,Mandatory=$false)] [string]$InstallDir        
    )            
    # Get args for installing the VDA Workstation (WSVDA).
    $installargs = cwcXenDesktop\Get-VDAInstallArgs -InstallVDAWorkstation:$InstallVDA -InstallPvd:$InstallPvd `
                                      -InstallPlugin:$InstallPlugin -EnableHDXPorts:$EnableHDXPorts `
                                      -Reboot:$Reboot -LogPath $LogPath `
                                      -Controllers $Controllers -UseIbizaVdaArgs:$UseIbizaVdaArgs -EnableRemoteAssistance:$EnableRemoteAssistance `
                                      -MasterImage:$false -InstallVDAServer:$false -XAServerLocation $XAServerLocation `
                                      -EnableRemoteManagement:$EnableRemoteManagement -ExcludedPackages:$ExcludedPackages -UseXenAppBranding:$UseXenAppBranding `
                                      -InstallDir $InstallDir -verbose
    If ($Reboot){
        $expectedExitCode = 0 # reboot expected to be handled by the installer, in this case windows is shutting down 
                              # the process -Wait flag is set to not wait and return 0 immediately for test driven reboot
                              # validation to occur: this usually involves three reboots for VdaServer.
        cwcInstall\Install-MSIOrEXE -installerPath $installerPath -installerArgs $installargs -ExpectedExitCode $expectedExitCode -Wait:$false | Out-Null
    } else {
        $expectedExitCode = $ExpectedRebootcode # reboot handed off to automation, this changes for 3 to 4 in Excalibur build 3006
        cwcInstall\Install-MSIOrEXE -installerPath $installerPath -installerArgs $installargs -ExpectedExitCode $expectedExitCode | Out-Null
    }
}

function Install-VdaServer {
    <#
    .SYNOPSIS
        Call XenDesktopVdaSetup.exe to silently install the VDA Server (Terminal Services VDA, a.k.a RDS desktops) and plug-ins. 

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Call XenDesktopVdaSetup.exe to silently install terminal services VDA Server and plug-ins.
            .Parameter InstallerPath
        Path to XenDesktopVDASetup.exe (local path or network share)
    .Parameter InstallVDAServer
        Switch parameter indicating whether or not to install the "VDASERVER" component, defaults to true, use "-InstallVDAServer:$false" to turn off 
    .Parameter InstallPvd
        Switch parameter indicating whether or not to enable PVD, defaults to false, use "-installPvd:$false" to turn off 
    .Parameter InstallPlugin
        Switch parameter indicating whether or not to install the "PLUGINS" component, defaults to true, use "-InstallPlugin:$false" to turn off 
    .Parameter EnableHDXPorts
        Switch parameter indicating whether or not to Enable HDX ports, defaults to true, use "-EnableHDXPorts:$false" to turn off  
    .Parameter Reboot
        Switch parameter indicating whether or not to reboot the machine after installation, defaults to false
    .Parameter LogPath
        Path for the installer to put the log files.
        Logpaths can contain spaces when the path is quoted.
    .Parameter Controllers
       FQDN of the Desktop Delivery Contollers (separated by ,) that VDA will register with.
    .Parameter XAServerLocation
       Address of the XenApp server for Citrix Reciever
    .Parameter EnableRemoteAssistance
       Switch parameter indicating whether or not to enable remote assistance(shadowing) or not. Defaults to false. 
    .Parameter MasterImage
       Configure VDA as a master image (currently only available on TSVDA type installs). Defaults to false. 
    .Parameter EnableRemoteManagement
       Switch parameter indicating whether or not to to include WinRM - remote management feature in the installation, defaults to false.
    .PARAMETER ExcludedPackages
	   A list of packages (comma-separated) for the meta-installer to exclude. MSI Packages are NOT the same as components.
    .EXAMPLE
        Install TSVDA without plugins from already mapped build share, reboot after installation
        Install-TSVDA -installerPath \\eng.citrite.net\ftl\Downloads\xd\main\29\Image-Full\x64\XenDesktop Setup\XenDesktopVdaSetup.exe -installPlugin:$false -Reboot 
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)]  [string]$InstallerPath,
        [Parameter(Position=1,Mandatory=$false)] [switch]$InstallVDAServer=$true,
        [Parameter(Position=2,Mandatory=$false)] [switch]$InstallPvd=$false,
        [Parameter(Position=3,Mandatory=$false)] [switch]$InstallPlugin=$true,
        [Parameter(Position=4,Mandatory=$false)] [switch]$EnableHDXPorts=$true,
        [Parameter(Position=5,Mandatory=$false)] [switch]$Reboot=$false,
        [Parameter(Position=6,Mandatory=$false)] [string]$LogPath = (Join-Path -Path $ENV:Temp -ChildPath "Citrix"),
        [Parameter(Position=7,Mandatory=$false)] [string]$Controllers,
        [Parameter(Position=8,Mandatory=$false)] [string]$XAServerLocation,
        [Parameter(Position=9,Mandatory=$false)] [switch]$EnableRemoteAssistance=$false,
        [Parameter(Position=10,Mandatory=$false)] [switch]$MasterImage=$false,
        [Parameter(Position=11,Mandatory=$false)] [switch]$EnableRemoteManagement=$false,
        [Parameter(Position=12,Mandatory=$false)] [string]$ExcludedPackages = $null,
        # [Parameter(Position=12,Mandatory=$false)] [string]$InstallCitrixFilesForWindows=$true
        [Parameter(Position=12,Mandatory=$false)] [string]$IncludeAdditional = $null
    )            
    # Get args for installing the VDA Server.
    $installargs = cwcXenDesktop\Get-VDAInstallArgs -InstallVDAWorkstation:$false -InstallPvd:$InstallPvd `
                                      -InstallPlugin:$InstallPlugin -EnableHDXPorts:$EnableHDXPorts `
                                      -Reboot:$Reboot -LogPath $LogPath `
                                      -Controllers $Controllers -UseIbizaVdaArgs:$false -EnableRemoteAssistance:$EnableRemoteAssistance `
                                      -MasterImage:$MasterImage -InstallVDAServer:$InstallVDAServer -XAServerLocation $XAServerLocation `
                                      -EnableRemoteManagement:$EnableRemoteManagement -ExcludedPackages:$ExcludedPackages -IncludeAdditional:$IncludeAdditional
                                    #   -InstallCitrixFilesForWindows:$InstallCitrixFilesForWindows
    If ($Reboot){
        $expectedExitCode = 0 # reboot expected to be handled by the installer, in this case windows is shutting down 
                              # the process -Wait flag is set to not wait and return 0 immediately for test driven reboot
                              # validation to occur: this usually involves three reboots for VdaServer.
        cwcInstall\Install-MSIOrEXE -installerPath $installerPath -installerArgs $installargs -ExpectedExitCode $expectedExitCode -Wait:$false | Out-Null
    } else {
        $expectedExitCode = 3 # reboot handed off to automation
        cwcInstall\Install-MSIOrEXE -installerPath $installerPath -installerArgs $installargs -ExpectedExitCode $expectedExitCode | Out-Null
    }
}

function Get-VDAInstallArgs {
    <#
    .SYNOPSIS
        Construct the XenDesktopVDASetup.exe commandline Arguments.

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Construct the VDA installation Arguments.
    .Parameter InstallVDAWorkstation
        Install the workstation (VDAWorkstation) component.
    .Parameter InstallPvd
        Install the Pvd component.
    .Parameter InstallPlugin
        Install the "PLUGINS" component.
    .Parameter EnableHDXPorts
        Enable HDX ports.
    .Parameter Reboot
        Reboot the machine after installation.
    .Parameter LogPath
        Path for the installer to put the log files.
        Logpaths can contain spaces when the path is quoted.
    .Parameter Controllers
       FQDN of the Desktop Contollers (separated by ,) for which the VDA will attempt registration.  
       Not enabled by default.
    .Parameter UseIbizaVdaArgs
       Override the args supplied to the metainstaller with those from the Ibiza VDA.
    .Parameter EnableRemoteAssistance
       Enable remote assistance(shadowing) or not. 
    .Parameter MasterImage
       Configure VDA as a master image (currently only available on TSVDA type installs).
    .Parameter InstallVDAServer
        Install the VDA SERVER (Terminal Services) component.
    .Parameter XAServerLocation
       Address of the XenApp server for Citrix Reciever. 
       Not enabled by default.
    .Parameter EnableRemoteManagement
       Tells the Metainstaller to enable WinRM - remote management.
       This is a requirement for Desktop Director.
       Not enabled by default.
    .Parameter ExcludedPackages
       A list of packages (comma-separated) for the meta-installer to not install.
    .Parameter UseXenAppBrandingVDA
       Switch to use the XenApp Branding.
    .Parameter InstallDir
       Installation path of VDA
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)] [switch]$InstallVDAWorkstation,
        [Parameter(Position=1,Mandatory=$true)] [switch]$InstallPvd,
        [Parameter(Position=2,Mandatory=$true)] [switch]$InstallPlugin,
        [Parameter(Position=3,Mandatory=$true)] [switch]$EnableHDXPorts,
        [Parameter(Position=4,Mandatory=$true)] [switch]$Reboot,
        [Parameter(Position=5,Mandatory=$true)] [string]$LogPath,
        [Parameter(Position=6,Mandatory=$false)] [string]$Controllers,
        [Parameter(Position=7,Mandatory=$true)] [switch]$UseIbizaVdaArgs,
        [Parameter(Position=8,Mandatory=$true)] [switch]$EnableRemoteAssistance,
        [Parameter(Position=9,Mandatory=$true)] [switch]$MasterImage,
        [Parameter(Position=10,Mandatory=$true)] [switch]$InstallVDAServer,
        [Parameter(Position=11,Mandatory=$false)] [string]$XAServerLocation,
        [Parameter(Position=12,Mandatory=$false)] [switch]$EnableRemoteManagement,
        [Parameter(Position=13,Mandatory=$false)] [string]$ExcludedPackages = $null,
        [Parameter(Position=14,Mandatory=$false)] [switch]$UseXenAppBranding = $false,
        [Parameter(Position=15,Mandatory=$false)] [string]$InstallDir,        
        # [Parameter(Position=16,Mandatory=$false)] [string]$InstallCitrixFilesForWindows   
        [Parameter(Position=16,Mandatory=$false)] [string]$IncludeAdditional = $null   
    )    

    Write-Verbose "Installer logs located in:$LogPath"

    #If user does not specifies the installation path of VDA, it will be installed in default path
    if ([string]::IsNullOrEmpty($InstallDir))
    {
         [System.Collections.ArrayList]$installargs = ("/quiet",  "/verboselog")
        #  [System.Collections.ArrayList]$installargs = ("/quiet", "/optimize", "/verboselog")
    }
    else
    {   
        $InstallDir = $InstallDir.trim()
        if (-not(Test-Path $InstallDir))
        {
            Write-Verbose "Create install directory:$InstallDir"
            New-Item $InstallDir -type 'directory' | Out-Null
        }

        [System.Collections.ArrayList]$installargs = ("/quiet", "/installdir '$InstallDir'", "/verboselog")
        # [System.Collections.ArrayList]$installargs = ("/quiet","/optimize", "/installdir '$InstallDir'", "/verboselog")
    }
    
    if ($UseXenAppBranding) 
    {
        $installargs.Insert(0,"/xenapp")
    }
     
    # Looks like there is a bug in powershell where it forces a Count() to the pipeline when the Add method is invoked.
    if ($UseIbizaVdaArgs) {
        Write-Verbose "Using Ibiza args"
        $installargs.Add("/logpath $LogPath") | Out-Null
    } else {
        $installargs.Add("/logpath '$LogPath'") | Out-Null
    }

    # Start components - maybe this should be a function?
    # Turns out that the MetaInstaller required double quotes for the components arg
    # log what is being installed
    if ($InstallVDAWorkstation) {
        Write-Verbose "Installing Workstation VDA"
    } else {
        Write-Verbose "Installing VDA Server (Terminal Services VDA a.k.a TSVDA / RDS)"
    }
    $components = '/components "'
    $components += "VDA,"

    if ($InstallPlugin) {
        $components += "PLUGINS,"
    }
    $components = $components.TrimEnd(',')
    $components += '"'
    $installargs.Add($components) | Out-Null
    # END components    

    if ($InstallPvd) {
        $installargs.Add("/BASEIMAGE") | Out-Null
    }    

    if (![String]::IsNullOrEmpty($Controllers)) {    
        if ($UseIbizaVdaArgs) { # legacy VDA install crashes the ICA service if there are quotes around the controller list
            $installargs.Add("/CONTROLLERS $Controllers") | Out-Null
         } else {
            $installargs.Add("/CONTROLLERS '$Controllers'") | Out-Null
         }
    }

    if (![String]::IsNullOrEmpty($XAServerLocation)) {    
         $installargs.Add("/XA_SERVER_LOCATION $XAServerLocation") | Out-Null
    }

    if ($EnableHDXPorts) {
        Write-Verbose "Enabling HDX Ports and Realtime Transport"
        $installargs.Add("/ENABLE_HDX_PORTS") | Out-Null
        $installargs.Add("/ENABLE_REAL_TIME_TRANSPORT") | Out-Null
    }
    
    if($EnableRemoteAssistance) {
        Write-Verbose "Enable Remote Assistance (Shadowing)"
        $installargs.Add("/ENABLE_REMOTE_ASSISTANCE") | Out-Null
    }
    
    if($EnableRemoteManagement) {
        Write-Verbose "Enable Remote Management (WinRM used by DesktopDirector)"
        $installargs.Add("/ENABLE_REMOTE_MANAGEMENT") | Out-Null
    }

    if ($Reboot -eq $false) {
        $installargs.Add("/NOREBOOT") | Out-Null
    }

    if ($MasterImage) {
        $installargs.Add("/MASTERIMAGE") | Out-Null
    }
    
	if (-not([string]::isNullOrempty($ExcludedPackages))) {
		write-verbose "Requested to exclude these packages: '$ExcludedPackages'"
			# always enclose the string in double-quotes
			if ($ExcludedPackages[0] -ne '"') {
				$ExcludedPackages = """$ExcludedPackages"""
			}
			write-Host "Excluding packages: $ExcludedPackages"
			$installargs.Add("/EXCLUDE $ExcludedPackages") | Out-Null
    }
    
	if (-not([string]::isNullOrempty($IncludeAdditional))) {
		write-verbose "Requested to include these additional packages: '$IncludeAdditional'"
			# always enclose the string in double-quotes
			if ($IncludeAdditional[0] -ne '"') {
				$IncludeAdditional = """$IncludeAdditional"""
			}
			write-Host "Include Additional: $IncludeAdditional"
			$installargs.Add("/includeadditional $IncludeAdditional") | Out-Null
	}
    Write-Verbose "Install Arguments: $($installargs)"
    return $installargs.ToArray()
}

function Add-BrokerConfigurationPowershellSnapins {
    <#
    .Synopsis
        Load all XD Powershell Snapins
    #>
    $snapins = @("Citrix.ADIdentity.Admin.V2", "Citrix.Broker.Admin.V2", "Citrix.Configuration.Admin.V2", "Citrix.MachineCreation.Admin.V2", "Citrix.Host.Admin.V2", "Citrix.ConfigurationLogging.Admin.V1", `
    "Citrix.DelegatedAdmin.Admin.V1", "Citrix.Monitor.Admin.V1", "Citrix.UserProfileManager.Admin.V1", "Citrix.EnvTest.Admin.V1", "Citrix.StoreFront.Admin.V1", "Citrix.Common.Commands") 
   
    $snapins | % { if ( (Get-PSSnapin -Name $_ -ErrorAction SilentlyContinue) -eq $null ){ add-pssnapin $_ } }
}

function Add-BrokerPowershellSnapins {
    <#
    .SYNOPSIS
        Load XD Powershell Snapins
    .PARAMETER Snapins
        The required snapins
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $Snapins = "Citrix.Broker.Admin.V2"
    )
   
    $Snapins | % { if ( (Get-PSSnapin -Name $_ -ErrorAction SilentlyContinue) -eq $null ){ add-pssnapin $_ } }
}

function New-DeliveryGroup {
    <#
    .SYNOPSIS
        Creates a Delivery Group on Broker and sets access, assignment, and entitlement policy rules, power time scheme, and local time zone. All based on Studio defaults.
    .PARAMETER DeliveryGroupName
        The name of the delivery group to be created, max 57 chars, extra characters will be removed
    .PARAMETER DesktopKind
        The kind of desktops this group will hold. Valid values are Private and Shared 
    .PARAMETER DeliveryType
        Specifies whether desktops, applications, or both, can be delivered from machines contained within the new desktop group. 
        Desktop groups with a DesktopKind of Private cannot be used to deliver both desktops and applications. Defaults to DesktopsOnly if not specified.
        Valid values are DesktopsOnly, AppsOnly, and DesktopsAndApps 
    .PARAMETER SessionSupport
        Specifies whether machines in the desktop group are single or multi-session capable. Values can be SingleSession and MultiSession. Default is SingleSession
    .PARAMETER IsRemotePC
        Specifies whether this is to be a Remote PC desktop group. IsRemotePC can only be enabled when SessionSupport is SingleSession, DeliveryType is DesktopsOnly, DesktopKind is Private.
        Default is $false
    .PARAMETER MinimumFunctionalLevel
        The minimum FunctionalLevel required for machines to work successfully in the desktop group. Valid values are L5, L7. Default is L7
    .PARAMETER ShutdownDesktopAfterUse
        Specify whether shut down the desktop or not when it is idle.
    .PARAMETER OffPeakBufferSizePercent
        Specify the buffer size percent when it is off peak time, this will control whether shut down the idle desktops or not.
    .PARAMETER PeakBufferSizePercent
        Specify the buffer size percent when it is peak time, this will control whether shut down the idle desktops or not.
    .PARAMETER IncludedUsers
        Specifies users and groups who are granted access to the new rule's delivery group. Default is the local domain's Domain Users group.
    .PARAMETER AdminAddress
        Specifies the address of a XenDesktop controller that the PowerShell snapin will connect to. This can be provided as a host name or an IP address. Default is Localhost
    .OUTPUTS
        Citrix.Broker.Admin.SDK.DesktopGroup.Uid
        New-DeliveryGroup returns the created delivery group's Uid
    .EXAMPLE
        New-DeliveryGroup -DeliveryGroupName "MyDeliveryGroup" -DesktopKind "Private"

        Description
        -----------
        Create a private delivery group with name MyDeliveryGroup, machines in the desktop groups will be SingleSession compatible (default).
    #>
    [cmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)] [string]$DeliveryGroupName,
        [Parameter(Mandatory=$true)] [ValidateSet("Private","Shared")][string]$DesktopKind,
        [Parameter(Mandatory=$false)] [ValidateSet("DesktopsOnly","AppsOnly","DesktopsAndApps")][string]$DeliveryType="DesktopsOnly",
        [Parameter(Mandatory=$false)] [ValidateSet("SingleSession", "MultiSession")][string]$SessionSupport="SingleSession",
        [Parameter(Mandatory=$false)] [bool]$IsRemotePC=$false,
        [Parameter(Mandatory=$false)] [ValidateSet("L5", "L7","L7_6")][string]$MinimumFunctionalLevel="L7_6",
        [Parameter(Mandatory=$false)] [bool]$ShutdownDesktopsAfterUse=$false,
        [Parameter(Mandatory=$false)] [int]$OffPeakBufferSizePercent=100,
        [Parameter(Mandatory=$false)] [int]$PeakBufferSizePercent=100,
        [Parameter(Mandatory=$false)] [string[]]$IncludedUsers="$((gwmi Win32_ComputerSystem).Domain)\Domain Users",
        [Parameter(Mandatory=$false)] [string]$AdminAddress="Localhost"
    )

    Write-Verbose "Invoking function New-DeliveryGroup"
    Add-BrokerConfigurationPowershellSnapins

    if ($IsRemotePC -eq $true -and $SessionSupport -ne "SingleSession" -and $DeliveryType -ne "DesktopsOnly" -and $DesktopKind -ne "Private") {
        throw "RemotePC can only be enabled when SessionSupport is SingleSession, DeliveryType is DesktopsOnly, and DesktopKind is Private"
    }

    if ($DesktopKind -eq "Private" -and $DeliveryType -eq "DesktopsAndApps") {
        throw "When DesktopKind is Private DeliveryType cannot be DesktopsAndApps"
    }
    
    # Fix for disallowed characters. There are more, but we only fixing the "."
    $DeliveryGroupName = $DeliveryGroupName.Replace(".","_")

    if ($DeliveryGroupName.Length -gt 57) {
        $DeliveryGroupName = $DeliveryGroupName.Substring(0,57)
    }
    
    #The hardcoded values are mimicking non-defaults that the wizard in Studio does
    Write-Verbose "Creating delivery group $DeliveryGroupName"
    if ($SessionSupport -eq "SingleSession") {
        Write-Verbose "SingleSession delivery group"
        $bdg = New-BrokerDesktopGroup -Name $DeliveryGroupName `
                                      -DesktopKind $DesktopKind `
                                      -DeliveryType $DeliveryType `
                                      -SessionSupport $SessionSupport `
                                      -IsRemotePC $IsRemotePC `
                                      -MinimumFunctionalLevel $MinimumFunctionalLevel `
                                      -TimeZone ([TimeZoneInfo]::Local.Id) `
                                      -OffPeakBufferSizePercent $OffPeakBufferSizePercent `
                                      -PeakBufferSizePercent $PeakBufferSizePercent `
                                      -ShutdownDesktopsAfterUse $ShutdownDesktopsAfterUse `
                                      -AdminAddress $AdminAddress
    } elseif ($SessionSupport -eq "MultiSession") {
        Write-Verbose "MultiSession delivery group"
        $bdg = New-BrokerDesktopGroup -Name $DeliveryGroupName `
                                      -DesktopKind $DesktopKind `
                                      -DeliveryType $DeliveryType `
                                      -SessionSupport $SessionSupport `
                                      -IsRemotePC $IsRemotePC `
                                      -MinimumFunctionalLevel $MinimumFunctionalLevel `
                                      -TimeZone ([TimeZoneInfo]::Local.Id) `
                                      -OffPeakBufferSizePercent $OffPeakBufferSizePercent `
                                      -PeakBufferSizePercent $PeakBufferSizePercent `
                                      -AdminAddress $AdminAddress
    }

    foreach ($user in $IncludedUsers) {
        if ((Get-BrokerUser -Name $user -AdminAddress $AdminAddress -ErrorAction SilentlyContinue) -eq $null) {
            Write-Verbose "Creating user $user"
            New-BrokerUser -Name $user -AdminAddress $AdminAddress | Out-Null
        }
    }
    
    #The hardcoded values are mimicking non-defaults that the wizard in Studio does
    if ($DesktopKind -eq "Private") {
        if ($DeliveryType -eq "AppsOnly") {
            Write-Verbose "Creating app assignment policy for private delivery group $DeliveryGroupName"
            $assignmentPol = New-BrokerAppAssignmentPolicyRule -Name $DeliveryGroupName -DesktopGroupUid $bdg.Uid -IncludedUserFilterEnabled $false -AdminAddress $AdminAddress
        } elseif ($DeliveryType -eq "DesktopsOnly") {
            Write-Verbose "Creating desktop assignment policy for private delivery group $DeliveryGroupName"
            $assignmentPol = New-BrokerAssignmentPolicyRule -Name $DeliveryGroupName -DesktopGroupUid $bdg.Uid -IncludedUserFilterEnabled $false -AdminAddress $AdminAddress
        }
    } elseif ($DesktopKind -eq "Shared") {
        if ($DeliveryType -like "*Apps*") {
            Write-Verbose "Creating app entitlement policy for shared delivery group $DeliveryGroupName"
            $entPol = New-BrokerAppEntitlementPolicyRule -Name $DeliveryGroupName -DesktopGroupUid $bdg.Uid -IncludedUserFilterEnabled $false -AdminAddress $AdminAddress
        }
        if ($DeliveryType -like "*Desktops*") {
            Write-Verbose "Creating desktop entitlement policy for shared delivery group $DeliveryGroupName"
            $entPol = New-BrokerEntitlementPolicyRule -Name "$($DeliveryGroupName)_1" -DesktopGroupUid $bdg.Uid -IncludedUserFilterEnabled $false -AdminAddress $AdminAddress
        }
    }

    #The hardcoded values are mimicking non-defaults that the wizard in Studio does
    Write-Verbose "Creating access policy rules for delivery group $DeliveryGroupName"
    New-BrokerAccessPolicyRule -DesktopGroupUid $bdg.Uid `
                                -AllowedConnections "NotViaAG" `
                                -Name "$($DeliveryGroupName)_Direct" `
                                -IncludedUserFilterEnabled $true `
                                -AllowedProtocols @("HDX","RDP") `
                                -AllowRestart $true `
                                -IncludedSmartAccessFilterEnabled $true `
                                -IncludedUsers $IncludedUsers `
                                -AdminAddress $AdminAddress | Out-Null

    New-BrokerAccessPolicyRule -DesktopGroupUid $bdg.Uid `
                                -AllowedConnections "ViaAG" `
                                -Name "$($DeliveryGroupName)_AG" `
                                -IncludedUserFilterEnabled $true `
                                -AllowedProtocols @("HDX","RDP") `
                                -AllowRestart $true `
                                -IncludedSmartAccessFilterEnabled $true `
                                -IncludedSmartAccessTags @() `
                                -IncludedUsers $IncludedUsers `
                                -AdminAddress $AdminAddress | Out-Null
    
    if ($SessionSupport -eq "SingleSession") {
        #The hardcoded values are mimicking non-defaults that the wizard in Studio does
        Write-Verbose "Creating power management time schemes for delivery group $DeliveryGroupName"
        if ($DesktopKind -eq "Private") {
            $weekdaysPoolSize = @(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        } else {
            $weekdaysPoolSize = @(0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0)
        }
        New-BrokerPowerTimeScheme -DaysOfWeek "Weekdays" `
                                  -DesktopGroupUid $bdg.Uid `
                                  -DisplayName "Weekdays" `
                                  -Name "$($DeliveryGroupName)_Weekdays" `
                                  -PeakHours @($false,$false,$false,$false,$false,$false,$false,$true,$true,$true,$true,$true,$true,$true,$true,$true,$true,$true,$true,$false,$false,$false,$false,$false) `
                                  -PoolSize $weekdaysPoolSize `
                                  -AdminAddress $AdminAddress | Out-Null
    
        New-BrokerPowerTimeScheme -DaysOfWeek "Weekend" `
                                  -DesktopGroupUid $bdg.Uid `
                                  -DisplayName "Weekend" `
                                  -Name "$($DeliveryGroupName)_Weekend" `
                                  -PeakHours @($false,$false,$false,$false,$false,$false,$false,$true,$true,$true,$true,$true,$true,$true,$true,$true,$true,$true,$true,$false,$false,$false,$false,$false) `
                                  -PoolSize @(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) `
                                  -AdminAddress $AdminAddress | Out-Null
    }

    Write-Verbose "Leaving function New-DeliveryGroup"

    return $bdg.Uid
}

function Add-MachinesToDeliveryGroup {
    <#
    .SYNOPSIS
        Adds machines from a catalog to a delivery group
    .PARAMETER DeliveryGroup
        The delivery group to which the machines are added. This can be an Instance, Name, or Uid
    .PARAMETER Catalog
        The catalog from which the machines are taken. This can be an Instance, Name, or Uid
    .PARAMETER Count
        The number of machines to add to the delivery group
    .PARAMETER MachineName
        The name of the single machine to add (must match the MachineName property of the machine)
    .PARAMETER AdminAddress
        Specifies the address of a XenDesktop controller that the PowerShell snapin will connect to. This can be provided as a host name or an IP address. Default is Localhost 
    .EXAMPLE 
        Add-MachinesToDeliveryGroup -DeliveryGroup "MyDeliveryGroup" -Catalog "MyCatalog" -Count 10

        Description
        -----------
        Adds 10 machines to MyDeliveryGroup from MyCatalog
    .EXAMPLE 
        Add-MachinesToDeliveryGroup -DeliveryGroup 12 -Catalog 15 -Count 10

        Description
        -----------
        Adds 10 machines to delivery group Uid 12 from catalog Uid 15
    .EXAMPLE 
        Add-MachinesToDeliveryGroup -DeliveryGroup "MyDeliveryGroup" -MachineName "MYDOMAIN\MYMACHINE"

        Description
        -----------
        Adds a single machine to MyDeliveryGroup from MCatalog
    .EXAMPLE 
        $machines | Add-MachinesToDeliveryGroup -DeliveryGroup "MyDeliveryGroup"

        Description
        -----------
        Adds machines to MyDeliveryGroup by piping an array of strings containing the names of machines
    #>
    [cmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)] [object]$DeliveryGroup,
        [Parameter(Mandatory=$true,ParameterSetName='Multiple Machines')] [object]$Catalog,
        [Parameter(Mandatory=$true,ParameterSetName='Multiple Machines')] [int]$Count,
        [Parameter(Mandatory=$true,ParameterSetName='Single Machine',ValueFromPipeline=$true)] [string]$MachineName,
        [Parameter(Mandatory=$false)] [string]$AdminAddress="Localhost"
    )
    
    Begin {
        Write-Verbose "Invoking function Add-MachinesToDeliveryGroup"
        Add-BrokerConfigurationPowershellSnapins
    }

    Process {
        if($PSCmdlet.ParameterSetName -eq "Single Machine") {
            Write-Verbose "Adding machine $MachineName"
            Add-BrokerMachine -MachineName $MachineName -DesktopGroup $DeliveryGroup -AdminAddress $AdminAddress
        } else {
            Write-Verbose "Adding $Count machines"
            Add-BrokerMachinesToDesktopGroup -DesktopGroup $DeliveryGroup -Catalog $Catalog -Count $Count -AdminAddress $AdminAddress | Out-Null
        }
    }
    
    End {       
        Write-Verbose "Leaving function Add-MachinesToDeliveryGroup"
    }
}

function New-BrokerApplicationForDeliveryGroup {
    <# 
    .SYNOPSIS
       Create a broker application for a delivery group.
    .DESCRIPTION
       Create a broker application for a delivery group, set the application properties.
    .PARAMETER Name
        Name of the application
    .PARAMETER BrowserName
        Browser name of the application
    .PARAMETER PublishedName
        The name seen by end users who have access to this application.
    .PARAMETER ApplicationType
        Type of the application, HostedOnDesktop or InstalledOnClient
    .PARAMETER CommandLineExecutable
        Specifies the name of the executable file to launch. 
        The full path need not be provided if it's already in the Environment variables path, 
        local path and web net path can also be used.
    .PARAMETER CommandLineArguments
        Specifies the command-line arguments to use when launching the executable. 
        Environment variables can be used.
    .PARAMETER Description
        Specifies the description of the application. 
        This is only seen by Citrix administrators and is not visible to users.
    .PARAMETER WorkingDirectory
        Specifies which working directory the executable is launched from. 
        Environment variables can be used.
    .PARAMETER Enabled
        Specifies whether or not this application can be launched.    
    .PARAMETER DesktopGroupName
        Name of the application group
    .PARAMETER Priority
        Specifies the priority of mapping between the application and desktop group, 
        smaller number means higher priority
        .PARAMETER Priority
        Specifies the priority of the mapping between the application and desktop group. 
        A value of zero has the highest priority, with increasing values indicating lower priorities. 
    .PARAMETER StartMenuFolder
        Specifies the start menu folder
    .PARAMETER IconUid
        Specifies which icon to use for this application. 
        This icon is visible both to the administrator (in the consoles) and to the user. 
        If no icon is specified, then a generic built-in application icon is used.
    .PARAMETER ClientFolder
        Specifies the folder that the application belongs to as the user sees it. 
    .Example
        1. New-BrokerApplicationForDeliveryGroup -Name $application -BrowserName $browserName -PublishedName $publishName -DesktopGroupName $desktopGroup -Priority 0
        2. New-BrokerApplicationForDeliveryGroup -Name "Notepad" -BrowserName "Notepad" -PublishedName "Notepad" -CommandLineExecutable "%SystemRoot%\System32\notepad.exe" -DesktopGroupName $desktopGroup -Priority 0
    
    #>
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $BrowserName,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $PublishedName,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $ApplicationType = "HostedOnDesktop",

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $CommandLineExecutable,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $CommandLineArguments = "",

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $Description ="",

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $WorkingDirectory,

        [Parameter(Mandatory=$false)]
        [bool] $Enabled = $True,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $DesktopGroupName,

        [Parameter(Mandatory=$false)]
        [int] $Priority = 0,

        [Parameter(Mandatory=$false)]
        [int] $IconUid = 1,

        [Parameter(Mandatory=$false)]
        [string] $ClientFolder,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $StartMenuFolder = ""
    )

    # Add Citrix Broker snapin
    Add-BrokerPowershellSnapins "Citrix.Broker.Admin.V2"

    if ((Get-BrokerDesktopGroup -Name $DesktopGroupName -ErrorAction SilentlyContinue) -eq $null)
    {
        Write-Verbose "The desktop group: $DesktopGroupName does not exist"
        exit 1
    }

    $dg = Get-BrokerDesktopGroup -name $DesktopGroupName
    Write-Verbose "$(Get-Date -format 'T') ** Delivery Group: $($dg.Name)"
    
    # Use application name as browse name if it is not specified
    if (-not $BrowserName)
    {
        $BrowserName = $Name
    }

    # Use application name as publish name if it is not specified
    if (-not $PublishedName)
    {
        $PublishedName = $Name
    }

    # Use target path as working directory if it is not specified
    if (-not $WorkingDirectory)
    {
        $WorkingDirectory = Split-Path $CommandLineExecutable -Parent
    }

    $app = New-BrokerApplication -ApplicationType $ApplicationType `
                                 -CommandLineArguments $CommandLineArguments `
                                 -CommandLineExecutable $CommandLineExecutable `
                                 -DesktopGroup $dg `
                                 -Enabled $Enabled `
                                 -Name $Name `
                                 -BrowserName $BrowserName `
                                 -PublishedName $PublishedName `
                                 -StartMenuFolder $StartMenuFolder `
                                 -WorkingDirectory $WorkingDirectory `
                                 -Description $Description `
                                 -IconUid $IconUid `
                                 -ClientFolder $ClientFolder
   
    Write-Verbose "$(Get-Date -format 'T') ** Added hosted application: $($app.Name)"    
}

function New-BrokerIconFromFile {

    <# 
    .SYNOPSIS
       New a broker Icon 
    .DESCRIPTION  
       Get the Icon from exisitng file and make the icon available in broker.
       Icon will be identified by a Incon Uid.
    .PARAMETER File
       It contains the location and name of the file.
    #>
    param
    (
        [Parameter(Mandatory=$true)][string] $File
    )
    cwcXenDesktop\Add-BrokerConfigurationPowershellSnapins
    $ctxIcon = Get-CtxIcon -FileName $File -index 0
    if ($? -ne $true)
    {
        throw "Failed to get Icon from file $file"
    }
    $brokerIcon = New-BrokerIcon -EncodedIconData $ctxIcon.EncodedIconData
    if ($? -ne $true)
    {
        throw "Failed to new Broker Icon"
    }
    Write-Verbose "The IconUid of this Icon is: $brokerIcon.Uid"
    return $brokerIcon.Uid
}

function Set-ApplicationProperties {
    <#.SYNOPSIS
       Set the properties for a broker application.
    .DESCRIPTION
       Set the properties for a existing application.
    .PARAMETER Name
        Name of the application
    .PARAMETER CommandLineExecutable
        Specifies the name of the executable file to launch. 
        The full path need not be provided if it's already in the Environment variables path, 
        local path and web net path can also be used.
    .PARAMETER CommandLineArguments
        Specifies the command-line arguments to use when launching the executable. 
        Environment variables can be used.
    .PARAMETER WorkingDirectory
        Specifies which working directory the executable is launched from. 
        Environment variables can be used.
    .PARAMETER IconUid
        Specifies which icon to use for this application. 
        This icon is visible both to the administrator (in the consoles) and to the user. 
        If no icon is specified, then a generic built-in application icon is used.
    .PARAMETER ClientFolder
        Specifies the folder that the application belongs to as the user sees it. 
    .PARAMETER FileTypeExtensionName
        Specifies the name of the handler for the file type association (as seen in the Registry). For example, "TXTFILE" or "Word.Document.8"
    .PARAMETER HandlerName
        Specifies the extension name for the file type association. For example, ".txt" or ".doc".
    .Example
        1. Set-ApplicationProperties -Name "Notepad" -CommandLineExecutable "%SystemRoot%\System32\notepad.exe"
    #>
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $CommandLineExecutable,

        [Parameter(Mandatory=$false)]
        [string] $CommandLineArguments,

        [Parameter(Mandatory=$false)]
        [string] $WorkingDirectory,

        [Parameter(Mandatory=$false)]
        [int] $IconUid,

        [Parameter(Mandatory=$false)]
        [string] $ClientFolder,

        [Parameter(Mandatory=$false)]
        [string] $FileTypeExtensionName,

        [Parameter(Mandatory=$false)]
        [string] $HandlerName
    )

    # Add Citrix Broker snapin
    Add-BrokerPowershellSnapins "Citrix.Broker.Admin.V2"

    if ((Get-BrokerApplication -Name $Name -ErrorAction SilentlyContinue) -eq $null)
    {
        Write-Verbose "The specified application: $Name does not exist"
        exit 1
    }
    $app = Get-BrokerApplication -Name $Name

    Write-Verbose "$(Get-Date -format 'T') ** Setting properties for application: $($app.Name)"
    if ($CommandLineArguments)
    {
        Set-BrokerApplication -InputObject $app -CommandLineArguments $CommandLineArguments
    }
    if ($CommandLineExecutable)
    {
        Set-BrokerApplication -InputObject $app -CommandLineExecutable $CommandLineExecutable

    }
    if ($WorkingDirectory)
    {
        Set-BrokerApplication -InputObject $app -WorkingDirectory $WorkingDirectory

    }
    if ($IconUid)
    {
        Set-BrokerApplication -InputObject $app -IconUid $IconUid
    }
    if ($ClientFolder)
    {
        Set-BrokerApplication -InputObject $app -ClientFolder $ClientFolder
    }

    if ($FileTypeExtensionName)
    {
        New-BrokerConfiguredFTA -ApplicationUid $app.Uid `
                                -ExtensionName $FileTypeExtensionName `
                                -HandlerName $HandlerName
        if ($? -eq $false)
        {
            Write-Verbose "Failed to new configuredFTA."
            exit 1
        }
    }
    $app = Get-BrokerApplication -Name $Name                     

    Write-Verbose "$(Get-Date -format 'T') ** Properties of application `"$($app.Name)`" set successfully"    
}

function New-Admin {
    <#
    .SYNOPSIS
        Create a new admin and assigns it a role and scope
    .DESCRIPTION
        Creates a new XenDesktop site administrator with the given role and scope.

        By default, if only the name is passed it will use the role "Full Administrator" and scope "All"
    .PARAMETER Name
        The active directory name of the new admin or group (e.g. "MYDOMAIN\User1" or "MYDOMAIN\Domain Admins")
    .PARAMETER Role
        The role to be assigned to the new admin. Default is "Full Administrator"
    .PARAMETER Scope
        The scope to be assigned to the new admin. Default is "All"
    .PARAMETER AdminAddress
        Specifies the address of a XenDesktop controller that the PowerShell snapin will connect to. This can be provided as a host name or an IP address. Default is Localhost.
    .EXAMPLE
        New-Admin -Name "MYDOMAIN\Domain Admins"
        
        Description
        -----------
        Creates a new XenDesktop site administrator with Full permissions to all the objects
    .EXAMPLE
        New-Admin -Name "MYDOMAIN\User1" -Role "Readonly" -Scope "All"
  
        Description
        -----------
        Creates a new XenDesktop site administrator with Readonly permissions to all objects
    .EXAMPLE
        $arrayOfAdminNames | New-Admin

        Description
        -----------
        Creates XenDesktop administrators using each name contained in the string array that was passed with Full Administrator permissions to all of the objects
    #>
    [cmdletBinding()]
    Param (
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)] [string]$Name,
        [Parameter(Position=1,Mandatory=$false)] [string]$Role="Full Administrator",
        [Parameter(Position=2,Mandatory=$false)] [string]$Scope="All",
        [Parameter(Mandatory=$false)] [string] $AdminAddress="Localhost",
        [Parameter(Mandatory=$false)] [bool] $IsSetAdminRight = $true
    )

    Begin {
        Write-Verbose "Invoking function New-Admin"

        Add-BrokerConfigurationPowershellSnapins

        $availableRoles = Get-AdminRole | ? { $_.Name -eq $Role }
        $availableScopes = Get-AdminScope | ? { $_.Name -eq $Scope }
    }
    
    Process {
        $availableAdmins = Get-AdminAdministrator | ? { $_.Name -eq $Name }

        if ($availableAdmins -eq $null) {
            if ($availableRoles -ne $null) {
                if ($availableScopes -ne $null) {
                    Write-Verbose "Creating administrator $Name with role $Role and scope $Scope"
                    New-AdminAdministrator -AdminAddress $AdminAddress -Name $Name -Enabled $true
                    if ($IsSetAdminRight -eq $true)
                    {
                        Add-AdminRight -AdminAddress $AdminAddress -Administrator $Name -Role $Role -Scope $Scope
                    }
                } else {
                    throw "Scope $Scope does not exist"
                }
            } else {
                throw "Role $Role does not exist"
            }
        } else {
            Write-Verbose "Skipping $Name as it already exists"
        }
    }

    End {
        Write-Verbose "Leaving function New-Admin"
    }
}

function Remove-Admin
{
    <#
    .SYNOPSIS
        Remove a specified admin
    .DESCRIPTION
        Remove a specified admin
    .PARAMETER Name
        The active directory name of the new admin or group (e.g. "MYDOMAIN\User1" or "MYDOMAIN\Domain Admins")
    #>
    [cmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)] [string]$Name
    )
    
    # add Citrix DelegatedAdmin snapin
    Add-BrokerPowershellSnapins "Citrix.DelegatedAdmin.Admin.V1"
    
    $admin = Get-AdminAdministrator -Name $Name
    if ($admin -eq $null)
    {
        Write-Verbose ("Administrator ${Name} does not exist." | Out-String)
        Exit 1
    }
    
    Remove-AdminAdministrator -Name $Name
    if ($? -ne $true)
    {
        Write-Verbose ("Failed to remove Administrator ${Name}." | Out-String)
        Exit 1
    }
}

function Install-Receiver {
	<#
    .SYNOPSIS
        Silently install Citrix Reciever Client. 
        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
	
    .DESCRIPTION
		Runs the executable at the path provided to silenty install the Citrix client
		This function can install ReceiverEnterprise if the Enterprise switch is $true.

		For any switches, omitting them implies defaults, which currently install the maximum set of components.
		[TODO] Future will use parameter sets to satisy Enterprise-Receiver/Full-Receiver or other variations 
		for basic install and other roles.
	.PARAMETER InstallerPath
		Full path to the binary including extension
	.PARAMETER Enterprise
		True if Enterprise receiver commandline used, false if new Receiver wanted
		All flags
	.PARAMETER ControllerFQDN
		Omit if no controller setup is desired at this point
    .PARAMETER Stores
        Array of up to 10 stores to use with Receiver.
        STOREx="storename;http[s]://servername.domain/IISLocation/discovery;[On | Off];[storedescription]"
	.PARAMETER IncludeReceiverInside
		(ENT) Enterprise default and (RECV) Receiver default values:
		Defaults to ENT: $true  RECV: $true
	.PARAMETER IncludeICAClient
		Defaults to ENT: $true  RECV: $true
	.PARAMETER IncludeSSON
		Defaults to ENT: $true  RECV: $true
	.PARAMETER IncludeUSB
		Defaults to ENT: $true  RECV: $true
	.PARAMETER IncludeDesktopViewer
		Defaults to ENT: $true  RECV: $true		
	.PARAMETER IncludeFlash
		Defaults to ENT: $true  RECV: $true		
	.PARAMETER IncludePNAgent
		Defaults to ENT: $true  RECV: $false (not applicable)
	.PARAMETER IncludeVd3d
		Defaults to ENT: $true  RECV: $true		
	.PARAMETER IncludeAM
		Defaults to ENT: $false(not applicable)  RECV: $true				
	.PARAMETER IncludeSelfService
		Defaults to ENT: $false(not applicable)  RECV: $true				
	.PARAMETER IncludeReceiverUpdater
		Defaults to ENT: $false(not applicable)  RECV: $true				
	.PARAMETER Reboot
		Allow reboots during install
	.PARAMETER LogPath
		Optional, does nothing at this time.
	.PARAMETER ExpectedExitCode
		ExitCodes to indicate successful install. Defaults: @(0, 3010) (0:success and 3010:reboot required)
	#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$InstallerPath,
		[Parameter(Mandatory=$true)] [switch]$Enterprise,
        [Parameter(Mandatory=$false)] [string]$ControllerFQDN="",
        [Parameter(Mandatory=$false)] [array]$Stores,
        [Parameter(Mandatory=$false)] [switch]$IncludeReceiverInside,
        [Parameter(Mandatory=$false)] [switch]$IncludeICA_Client,
        [Parameter(Mandatory=$false)] [switch]$IncludeSSON,
        [Parameter(Mandatory=$false)] [switch]$IncludeAM,
        [Parameter(Mandatory=$false)] [switch]$IncludeSELFSERVICE,
        [Parameter(Mandatory=$false)] [switch]$IncludeUSB,
        [Parameter(Mandatory=$false)] [switch]$IncludeDesktopViewer,
        [Parameter(Mandatory=$false)] [switch]$IncludeFlash,
        [Parameter(Mandatory=$false)] [switch]$IncludeVd3d,
        [Parameter(Mandatory=$false)] [switch]$Reboot,
        [Parameter(Mandatory=$false)] [string]$LogPath,
        [Parameter(Mandatory=$false)] [int[]] $ExpectedExitCode = @(0, 3010))
	
	# Build a collection of all the installer switches so we can use powershell splatting
	$splatted = @{}
	get-variable -scope Local | ?{($_.name -like 'include*' ) -and ($_.value.gettype() -eq [System.Management.Automation.SwitchParameter]) -and (($_.Value.ispresent) -or ($Enterprise))} | % {
		if ($Enterprise -and ($_.name -eq 'IncludeICA_Client')) {
			Write-Verbose " Adding splattable ICA_Client flag ICAClient, $($_.value) "
			$splatted.Add('IncludeICAClient', $_.value) | out-null
		} else {
			Write-Verbose " Adding splattable flag $($_.name), $($_.value) "
			$splatted.Add($_.name, $_.value) | out-null
		}
	}
	if ($Enterprise) 
	{ # enterprise version
		$installargs = cwcXenDesktop\Get-CitrixRecieverEnterpriseInstallArgs -ControllerFQDN $ControllerFQDN `
															   @splatted `
															   -Reboot:$Reboot -LogPath $LogPath -verbose
	} 
	else
	{ # build a commandline for receiver (non-enterprise)
		$installargs = cwcXenDesktop\Get-ReceiverInstallArgs -ControllerFQDN $ControllerFQDN `
													 @splatted `
													 -Reboot:$Reboot -LogPath $LogPath -verbose `
                                                    -Stores $Stores
	}
	Write-Verbose "$(get-date -format 'T') About to install : '$InstallerPath'"
	cwcInstall\Install-MSIOrEXE -InstallerPath $InstallerPath -installerArgs $installargs -ExpectedExitCode $ExpectedExitCode | Out-String | Write-Verbose
}

function Get-ReceiverInstallArgs {
    <#
    .SYNOPSIS
        Construct CitrixReciever.exe (Jasper not Enterprise/LCM) commandline arguments
        
        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Construct CitrixReciever.exe (ala Jasper) commandline arguments 
    .Parameter ControllerFQDN
        Fully qualified Desktop Delivery Controller DNS name
    .Parameter Reboot
        Reboot the machine after installation?
    .Parameter LogPath
        Path for the installer to put the log files
        Not supported by the client yet - this will throw if set.
	.NOTES
		From the ReceiverMetadata.xml file we can see that the auto install options are:
		ADDLOCAL=ReceiverInside,ReceiverUpdater,ICA_Client,PN_Agent,Flash,USB,DesktopViewer,Vd3d,AM,SELFSERVICE 
		ENABLE_SSON=Yes ALLOWSAVEPWD="$AllowSavePwd" ALLOWADDSTORE="$AllowAddStore" USINGMS="True" 
		NOAUTORUN="y" STARTMENUDIR="$StartMenuDir" LEGACYFTAICONS="$LegacyFtaIcons" ARLOGERROR="y" 
		WSCRECONNECTLOGIN="$WSCReconnectLogin" WSCRECONNECTREFRESHLAUNCH="$WSCReconnectRefreshLaunch" 
		/IncludeSSON="$InstallSSON" WSCALLOWUSERSETTINGSCHANGE="$WSCAllowSettingsChanges"

    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$false)] [string]$ControllerFQDN,
        [Parameter(Mandatory=$false)] [array]$Stores,
        [Parameter(Mandatory=$false)] [string]$ALLOWADDSTORE="A",
        [Parameter(Mandatory=$false)] [switch]$IncludeReceiverInside=$true,
        [Parameter(Mandatory=$false)] [switch]$IncludeICA_Client=$true,
        [Parameter(Mandatory=$false)] [switch]$IncludeSSON=$true,
        [Parameter(Mandatory=$false)] [switch]$IncludeAM=$true,
        [Parameter(Mandatory=$false)] [switch]$IncludeSELFSERVICE=$true,
        [Parameter(Mandatory=$false)] [switch]$IncludeUSB=$true,
        [Parameter(Mandatory=$false)] [switch]$IncludeDesktopViewer=$true,
        [Parameter(Mandatory=$false)] [switch]$IncludeFlash=$true,
        [Parameter(Mandatory=$false)] [switch]$IncludeVd3d=$false,
        [Parameter(Mandatory=$false)] [switch]$Reboot = $false,
        [Parameter(Mandatory=$false)][string]$logpath
    )

    #Client doesn't support logs: Write-Verbose "Installer logs located at:'$LogPath'"
        
    [System.Collections.ArrayList]$installargs = @("/silent")
	if (-not ([string]::IsNullOrEmpty($ControllerFQDN)))
	{
		$installargs.Add( "SERVER_LOCATION='$ControllerFQDN'") | out-null
	}
    # Client doesn't support logs: $installargs.Add("/logpath '$LogPath'") | Out-Null

    
	$addPart = @()
	$mySwitches = get-variable -scope Local | ?{($_.name -like 'Include*' ) -and ($_.value.gettype() -eq [System.Management.Automation.SwitchParameter])}| ?{
			$_.Value.ispresent
		} | %{ 
			$addPart += $_.name.SubString(("Include").length)
		}
	if ($addPart.count -gt 0) {
		$plugins = "ADDLOCAL=""$($addPart  -join ',')"""
		Write-Verbose "Adding msi option : $plugins"
		$installargs.Add($plugins) | Out-Null
	}
    # END plugins    

    if ($Reboot -eq $false) {
        $installargs.Add("/NOREBOOT") | Out-Null
    }
    
    if ($IncludeSSON) {
        Write-Verbose "adding ENABLE_SSON flag"
        $installargs.Add('ENABLE_SSON="Yes"') | Out-Null   
        Write-Verbose "adding /IncludeSSON flag"
        $installargs.Add("/IncludeSSON") | Out-Null
    }

    if ($stores) {
        Write-Verbose "adding stores"
        foreach ($store in $Stores) {
            Write-Verbose "Adding Store$($Stores.IndexOf($store))=$store"
            $installargs.Add("/STORE$($Stores.IndexOf($store))=`"$store`"") | Out-Null   
        }
    }
    
     Write-Verbose "Adding ALLOWADDSTORE flag"
     $installargs.Add("ALLOWADDSTORE=`"$ALLOWADDSTORE`"") | Out-Null   

    Write-Verbose "$(get-date -format 'T') Citrix Reciever Client Install Arguments: $($installargs)"
    return $installargs.ToArray()
}

function Get-CitrixRecieverEnterpriseInstallArgs {
    <#
    .SYNOPSIS
        Construct CitrixRecieverEnterprise.exe commandline arguments
        
        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Construct CitrixRecieverEnterprise.exe commandline arguments 
    .Parameter ControllerFQDN
        Fully qualified Desktop Delivery Controller DNS name
    .Parameter IncludeReceiverInside
        Install the "ReceiverInside" component 
    .Parameter IncludeICAClient
        Install the "ICAClient" component  
    .Parameter IncludeSSON
        Install the "SSON" components for domain pass-through logon
    .Parameter IncludeUSB
        Install "USB" component 
    .Parameter IncludeDesktopViewer
        Install "DesktopViewer" component 
    .Parameter IncludeFlash
        Install "Flash" component 
    .Parameter IncludePNAgent
        Install "PNAgent" component 
    .Parameter IncludeVd3d
        Install "Vd3d" component 
    .Parameter Reboot
        Reboot the machine after installation 
    .Parameter LogPath
        Path for the installer to put the log files
        Not supported by the client yet - this will throw if set.
    #>
    [cmdletbinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)] [string]$ControllerFQDN,
        [Parameter(Position=1,Mandatory=$true)] [switch]$IncludeReceiverInside,
        [Parameter(Position=2,Mandatory=$true)] [switch]$IncludeICAClient,
        [Parameter(Position=3,Mandatory=$true)] [switch]$IncludeSSON,
        [Parameter(Position=4,Mandatory=$true)] [switch]$IncludeUSB,
        [Parameter(Position=5,Mandatory=$true)] [switch]$IncludeDesktopViewer,
        [Parameter(Position=6,Mandatory=$true)] [switch]$IncludeFlash,
        [Parameter(Position=7,Mandatory=$true)] [switch]$IncludePNAgent,
        [Parameter(Position=8,Mandatory=$true)] [switch]$IncludeVd3d,
        [Parameter(Position=9,Mandatory=$true)] [switch]$Reboot,
        [Parameter(Position=10,Mandatory=$true)][string]$logpath = (throw "Client does not currently support installer logs")
    )

    #Client doesn't support logs: Write-Verbose "Installer logs located at:'$LogPath'"
        
    [System.Collections.ArrayList]$installargs = ("/silent", "SERVER_LOCATION='$ControllerFQDN'")
    # Client doesn't support logs: $installargs.Add("/logpath '$LogPath'") | Out-Null

    # Looks like there is a bug in powershell where it forces a Count() to the pipeline when the Add method is invoked.
    # Turns out that the Client required double quotes for the components arg
    $components = 'ADDLOCAL="'
    if ($IncludeReceiverInside) {
        $components += "ReceiverInside,"
    }
    if ($IncludeICAClient) {
        $components += "ICA_Client,"
    }
    if ($IncludeSSON) {
        $components += "SSON,"
    }
    if ($IncludeUSB) {
        $components += "USB,"
    }
    if ($IncludeDesktopViewer) {
        $components += "DesktopViewer,"
    }
    if ($IncludeFlash) {
        $components += "Flash,"
    }
    if ($IncludePNAgent) {
        $components += "PN_Agent,"
    }
    if ($IncludeVd3d) {
        $components += "Vd3d,"
    }
    $components = $components.TrimEnd(',')
    $components +=  '"'
    $installargs.Add($components) | Out-Null
    # END components    

    if ($Reboot -eq $false) {
        $installargs.Add("/NOREBOOT") | Out-Null
    }
    
    if ($IncludeSSON) {
        Write-Verbose "adding Enabled_SSON section"
        $installargs.Add('ENABLE_SSON="Yes"') | Out-Null   
        Write-Verbose "adding /IncludeSSON flag"
        $installargs.Add("/IncludeSSON") | Out-Null
    }
    
    Write-Verbose "Citrix Reciever Client Install Arguments: $($installargs)"
    return $installargs.ToArray()
}

Export-ModuleMember Install-Ddc, New-DBSchema, Get-DDCInstallArgs

Export-ModuleMember Install-Vda, Install-VdaServer, Get-VDAInstallArgs

Export-ModuleMember Add-BrokerConfigurationPowershellSnapins, Add-BrokerPowershellSnapins, New-DeliveryGroup, Add-MachinesToDeliveryGroup
Export-ModuleMember New-BrokerApplicationForDeliveryGroup, New-BrokerIconFromFile, Set-ApplicationProperties

Export-ModuleMember New-Admin, Remove-Admin

Export-ModuleMember Install-Receiver, Get-ReceiverInstallArgs, Get-CitrixRecieverEnterpriseInstallArgs