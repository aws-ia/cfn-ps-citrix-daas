
<#
.SYNOPSIS
    This module file contains single-sourced PVS functions

.DESCRIPTION
    This module file contains single-sourced PVS functions

.NOTES
    Copyright (c) Citrix Systems, Inc. All rights reserved.
#> 
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Install-PVS {
    <#
    .SYNOPSIS
         Install all server side components of PVS (PVS Server, PVS ConsoleseServer).
    .PARAMETER ImagePath
        Path to the root folder of PVS image layout, should contain a server, console and target directory.
    .PARAMETER LogPath
        Path for the installer to put the log files.
    #>
    [CmdletBinding()]
    Param (
             [Parameter(Mandatory=$true)] [string]$ImagePath,
             [Parameter(Mandatory=$false)] [string]$LogPath = (Join-Path -Path $ENV:Temp -ChildPath "Citrix")
    )
    Write-Verbose "Invoking function Install-PVS"
    
    Write-Verbose "Start installing PVS including prerequisites..."
    
    #switch zone check off (don't prompt me to run when an msi is executed)
    $env:SEE_MASK_NOZONECHECKS=1
    
    if (cwcOS-Tools\Test-Processor64Bit) {
        $pvsSrvInstaller = "Server\PVS_Server_x64.exe"
        $pvsConsoleInstaller = "Console\PVS_Console_x64.exe"
    } else {
        $pvsSrvInstaller = "Server\PVS_Server.exe"
        $pvsConsoleInstaller = "Console\PVS_Console.exe"
    }

    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType directory
    }

    Write-Verbose "Installing PVS Server..."    
    $installerArgs = @("/S","/v`"/q/l*v $LogPath\PVSServer.log`"")
    cwcInstall\Install-MSIOrEXE -InstallerPath "$ImagePath\$pvsSrvInstaller" -InstallerArgs $installerArgs -verbose
    
    Write-Verbose "Installing PVS Console..."
    $installerArgs = @("/S","/v`"/q/l*v $LogPath\PVSConsole.log`"")
    cwcInstall\Install-MSIOrEXE -InstallerPath "$ImagePath\$pvsConsoleInstaller" -InstallerArgs $installerArgs -verbose
        
    Write-Verbose "Leaving function function Install-PVS"
}

function Install-PVSClient {
    <#
    .SYNOPSIS
       Installs PVS Client side component and surpresses the reboot
    .Parameter ImagePath
        Path to the root folder of PVS image layout, should contain a server, console and target directory.
    .Parameter InstallerSubPath
        Commandline options for the installer.
    .Parameter LogPath
        Path for the installer to put the log files
    #>
    [CmdletBinding()]
    param( 
        [Parameter(Mandatory=$true)] [string]$ImagePath,
        [Parameter(Mandatory=$false)] [string]$LogPath = (Join-Path -Path $ENV:Temp -ChildPath "Citrix")
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"
    Set-PSDebug -Trace 0

    Write-Verbose "Invoking function Install-PVSClient"
    
    Write-Verbose "Validate ImagePath and logPath..."

    if (-not (Test-Path $ImagePath)) {
        throw "Path '$ImagePath' is not accessible."
    }

    if (-not (Test-Path $LogPath)) {
        Write-Verbose "$LogPath does not exist, attempting to create it ..."
        try {
            New-Item -Path $LogPath -ItemType directory | Out-Null
        }catch {
            throw "Unable to create $LogPath"
        }
    }

    if (cwcOS-Tools\Test-Processor64Bit) {
        $pvsDeviceInstaller = "PVS_Device_x64.exe"
    } else {
        $pvsDeviceInstaller = "PVS_Device.exe"
    }
    
    Write-Verbose "Start installing PVS Client software..."

    # Use the TestApi to install the DDC
     Write-Verbose "Installing PVS Client ..."
        $installerArgs = @("/S","/v`"/q/l*v $LogPath\pvsDevice.log /norestart`"")
        cwcInstall\Install-MSIOrEXE -InstallerPath "$ImagePath\$(Get-ChildItem -Path $ImagePath -Name $pvsDeviceInstaller -Recurse)" -InstallerArgs $installerArgs -expectedExitCode "3010"| Out-Null
}

function New-SiteDBScript{
<#
.Synopsis
 	Creates a PVS database by generating sql script from MAPI.dll function
.Parameter databaseName
	Name of PVS database to create
.Parameter farmName
	Name of PVS farm to create 
.Parameter siteName
	Name of PVS site to create
.Parameter collectionName
	Name of PVS collection to create
.Parameter PVSServiceAccountDomain
	Domain name to use for default auth group who can administer the farm
.Parameter defaultAuthGroup
	AD group to use for default auth group who can administer the farm
.Parameter databaseServer
	SQL server to create database on (use SERVER/INSTANCE format for named instances)
.Parameter dbIs2012
    Must be set to true when using SQL2012 or newer, otherwise leave at default false
.Parameter sqlScriptPath
    Location to create sqlscript to generate db
#>
[CmdletBinding()]
    Param (
            [Parameter(Mandatory=$true)][string] $databaseName,
            [Parameter(Mandatory=$true)][string] $farmName,
            [Parameter(Mandatory=$true)][string] $siteName,
            [Parameter(Mandatory=$true)][string] $collectionName,
            [Parameter(Mandatory=$true)][string] $PVSServiceAccountDomain,
            [Parameter(Mandatory=$true)][string] $defaultAuthGroup,
            [Parameter(Mandatory=$true)][string] $databaseServer,
            [Parameter(Mandatory=$false)][bool] $dbIs2012 = $false,			
            [Parameter(Mandatory=$false)][string] $sqlScriptPath = "$ENV:Temp\Citrix",
            [Parameter(Mandatory=$false)][string] $sqlScriptFileName = "CreateProvisioningServerDatabase.sql")

	write-verbose "Entering function New-SiteDBScript"

    Write-Verbose "Verifying sql script: $sqlScriptPath"
	    if (Test-Path $sqlScriptPath) { Write-Verbose "$sqlScriptPath Exists" }
	    else { Write-Verbose "$sqlScriptPath doesn't exist, creating ..."; new-item $sqlScriptPath -type directory }
	    if (!(Test-Path $sqlScriptPath)) {throw "$sqlScriptPath doesn't exist and fails to be created" }

        [System.Reflection.Assembly]::loadfrom("c:\Program Files\Citrix\Provisioning Services\Mapi.dll")
	    [Mapi.CommandProcessor]::GenerateScript($databaseName, $farmName, $siteName, $collectionName, $defaultAuthGroup, $true, "$sqlScriptPath\$sqlScriptFileName", $dbIs2012)
	    sleep -s 5

	    if (test-path "$sqlScriptPath\$sqlScriptFileName") 
        {
            Write-Verbose "db script succesfully created at: $sqlScriptPath\$sqlScriptFileName"
        }
	    else {throw "Script failed to create" }

    Write-Verbose "Leaving function New-SiteDBScript"
}

function Start-SiteDBScript{
<#
.Synopsis
 	Executes a PVS database script utilizing the SQLPSSnapin
.Parameter sqlScriptPath
	Path to SQL script that creates a PVS database
.Parameter DatabaseServer
    Name of SQL server to create PVS database on
.Parameter DatabaseInstanceName
    Instance name of primary SQL server, leave blank for default instance
#>
[CmdletBinding()]
    Param (
            [Parameter(Mandatory=$true)][string] $sqlScriptPath,
            [Parameter(Mandatory=$true)][string] $DatabaseServer,
            [Parameter(Mandatory=$false)][string] $DatabaseInstanceName)

    cwcSQL\Import-SQLPSModule
	
	Write-Verbose "Executing $sqlScriptPath on $DatabaseServer\$DatabaseInstanceName"
	SQLPS\Invoke-SqlCmd -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -InputFile $sqlScriptPath -Verbose
}

function Join-PVSFarm {
<#
.Synopsis
 	Joins a PVS server to an existing PVS database/farm by generating an answer file and running the configuration wizard silently
.Parameter firstServer
    Boolean indicating if the first server for PVS store
.Parameter storePath
    Path for PVS store
.Parameter databaseServer
	Name of SQL server hosting the PVS site db to join
.Parameter databaseName
	Name of PVS database to join
.Parameter siteName
	Name of PVS site to join
.Parameter storeName
	Name of existing PVS store to asign server to
.Parameter PVSServiceAccountDomain
	Domain name of account PVS services will run under
.Parameter PVSServiceAccountName
	Account name PVS services will run under
.Parameter PVSServiceAccountPassword
    Password for account PVS services will run under
.Parameter PVSStreamingIP
	IP address stream service should use/bind to
.Parameter PVSMgmtIP
	IP address mgmt/soap service should use/bind to
.Parameter LicenseServer
    IP address of CTX license server to use
.Parameter UsePXE
    Int indicating if the PVS server should be configured to use the PXE service 
        If Null, uses another device.
        If n is 0, uses Microsoft DHCP.
        If n is 1, uses Provisioning Services PXE.
.Parameter answerFilePath
    Location to create answer file
#>
[CmdletBinding()]
    Param (
            [Parameter(Mandatory=$true)][bool] $firstServer,
            [Parameter(Mandatory=$false)][string] $storePath,
            [Parameter(Mandatory=$true)][string] $databaseServer,
            [Parameter(Mandatory=$true)][string] $databaseName,
            [Parameter(Mandatory=$false)][string] $secondaryDatabaseServer,
            [Parameter(Mandatory=$false)][string] $secondaryInstanceName,
            [Parameter(Mandatory=$true)][string] $siteName,
            [Parameter(Mandatory=$true)][string] $storeName,
            [Parameter(Mandatory=$true)][string] $PVSServiceAccountName,
            [Parameter(Mandatory=$true)][string] $PVSServiceAccountPassword,
            [Parameter(Mandatory=$true)][string] $PVSStreamingIP,
            [Parameter(Mandatory=$true)][string] $PVSMgmtIP,
            [Parameter(Mandatory=$true)][string] $LicenseServer,
            [Parameter(Mandatory=$false)][int] $UsePXE = $Null,
            [Parameter(Mandatory=$false)][string] $databaseInstance,	
            [Parameter(Mandatory=$false)][string] $answerFilePath = "$ENV:Temp\Citrix")

	write-verbose "Entering function Join-PVSFarm"

    #If a storepath was provided, validate it and attempt to create if it does not exist (works for local paths only)
    if ($storePath) {
        Write-Verbose "Verifying store path $storePath"
	        if (Test-Path "filesystem::$storePath") { Write-Verbose "filesystem::$storePath Exists" }
	            else { Write-Verbose "$storePath doesn't exist, creating ..."; new-item $storePath -type directory }
	        if (!(Test-Path "filesystem::$storePath")) {throw "filesystem::$storePath doesn't exist and fails to be created" }
    }

    Write-Verbose "Verifying ConfigWizard Exe and running"
    if ((test-path "$env:SystemDrive\Program Files\Citrix\Provisioning Services\ConfigWizard.exe"))
    {
        Write-Verbose "ConfigWizard.exe exists, creating answer file & configuring..."
		
	    $AnswerFileTemplate =
@"
FarmConfiguration=2
DatabaseServer=$databaseServer
FarmExisting=$databaseName
DatabaseInstance=$databaseInstance
FailoverDatabaseServer=$secondaryDatabaseServer
FailoverDatabaseInstance=$secondaryInstanceName
ExistingSite=$siteName
UserName=$PVSServiceAccountName
UserPass=$PVSServiceAccountPassword
Database=1
PasswordManagementInterval=7
StreamNetworkAdapterIP=$PVSStreamingIP
ManagementNetworkAdapterIP=$PVSMgmtIP
IpcPortBase=6890
IpcPortCount=20
SoapPort=54321
BootstrapFile=$env:ProgramData\Citrix\Provisioning Services\Tftpboot\ARDBP32.BIN
LS1=$PVSStreamingIP,0.0.0.0,0.0.0.0,6910
AdvancedVerbose=0
AdvancedInterrultSafeMode=0
AdvancedMemorySupport=1
AdvancedRebootFromHD=0
AdvancedRecoverSeconds=50
AdvancedLoginPolling=5000
AdvancedLoginGeneral=30000
LicenseServer=$LicenseServer
LicenseServerPort=27000
"@

        if ($UsePXE) {
            $AnswerFileTemplate = "PXEServiceType=$([int]$UsePXE)`r`n" + $AnswerFileTemplate 
        }

        if ($firstServer) {
            $AnswerFileTemplate = "Store=$storeName`r`nDefaultPath=$storePath`r`n" + $AnswerFileTemplate
        } else {
            $AnswerFileTemplate = "ExistingStore=$storeName`r`n" + $AnswerFileTemplate
        }

        #Prepare args and run configuration wizard
	    Set-Content -Path "$answerFilePath\PVSAnswerFile.txt" -Value $AnswerFileTemplate -Force -Encoding Unicode
		
	    $command = "$env:SystemDrive\Program Files\Citrix\Provisioning Services\ConfigWizard.exe"
	    $args = "/a:$answerFilePath\PVSAnswerFile.txt /o:$answerFilePath\configResults.txt"
		
	    Start-Process $command @($args) -wait
		
        #Parse results file for success or failure
	    if (get-content "$answerFilePath\configResults.txt" | select-string -quiet "Configuration complete")
	    { 
            Write-Verbose "Configuration Wizard completed successfully"
        }
	    else {
            get-content "$answerFilePath\configResults.txt" | Write-Verbose 
            throw "Running PVS Server Configuration Wizard Failed"
        }
	}
	else { throw "ERROR: ConfigWizard is missing" }

    Write-Verbose "Leaving function Join-PVSFarm"
}

function Format-PVSAuthGroup {
<#
.Synopsis
 	Returns an AD group in the required PVS authgroup format
.Parameter GroupName
    Name of AD Group to format
#>
[CmdletBinding()]
    Param (
            [Parameter(Mandatory=$true)][string] $GroupName)

    $distingushidPath = cwcActive-Directory\Get-ADGroupPath -GroupName $GroupName
    Write-Verbose "$GroupName distingushed path is: $distingushidPath"
    
    $OUArray = $distingushidPath.split(",")
    $PVS_Path = ""
    $PVS_DomainName = ""
    foreach ($item in $OUArray) {
        if ($item.toupper().Contains("DC=")) {
            Write-Verbose "DC = $item"
            $PVS_DomainName = $PVS_DomainName + "." + $item.split("=")[1]
        }
        if ($item.toupper().Contains("OU=")) {
            Write-Verbose "OU = $item"
            $OuName = $item.split("=")[1]
            $PVS_Path = $item.split("=")[1] + "/" + $PVS_Path
        }
        if ( ($item.toupper().Contains("CN=")) -and (!$item.toupper().Contains($GroupName.ToUpper())) ) {
            Write-Verbose "CN = $item"
            $OuName = $item.split("=")[1]
            $PVS_Path = $item.split("=")[1] + "/" + $PVS_Path
        }
    }

    $PVS_DomainName = $PVS_DomainName.trim(".")
    $PVS_AuthGroup = "$PVS_DomainName/$PVS_Path$GroupName"
    Write-Verbose "$GroupName PVS formatted path is: $PVS_AuthGroup"

    return $PVS_AuthGroup
}

function Register-MCLIPSSnapin{
<#
.Synopsis
	Registers PVS PoSH dll (32 & 64) and adds it to PoSH session
#>
	write-verbose "invoking function Register-MCLIPSSnapin"
	
    if (test-path "c:\windows\Microsoft.Net\Framework64\v2.0.50727") {
		$installutil64 = "c:\windows\Microsoft.Net\Framework64\v2.0.50727"
		$installutil32 = "c:\windows\Microsoft.Net\Framework\v2.0.50727"
    }elseif (test-path "c:\windows\Microsoft.Net\Framework64\v4.0.30319") {
        $installutil64 = "c:\windows\Microsoft.Net\Framework64\v4.0.30319"
		$installutil32 = "c:\windows\Microsoft.Net\Framework\v4.0.30319"
    }

	if (test-path "c:\program files (x86)")
	{
		write-debug "Registering PVS PSSnapin x64"
		$myStart = New-Object Diagnostics.ProcessStartInfo
		$myStart.Filename = "$installutil64\installutil.exe"
		$myStart.Arguments = "`"$env:SystemDrive\Program Files\Citrix\Provisioning Services Console\McliPSSnapin.dll`""
		try
		{
			$myProcess = [System.Diagnostics.Process]::Start($myStart)
			$myProcess.WaitForExit()
		}
		catch [Exception]
		{
			#catch harmless exceptions for when we already registered the dll
			Write-Debug "$($_.Exception.Message)";
		}
		if($myProcess.exitcode -ne 0) {write-debug "Registing PVS PSSnapin x64 failed" }
		else { write-debug "Registering PVS PSSnapin x64 completed successfully" }

		write-debug "Registering PVS PSSnapin x86"
		$myStart.Filename = "$installutil32\installutil.exe"
		$myStart.Arguments = "`"$env:SystemDrive\Program Files\Citrix\Provisioning Services Console\McliPSSnapin.dll`""
		try
		{
			$myProcess = [System.Diagnostics.Process]::Start($myStart)
			$myProcess.WaitForExit()
		}
		catch [Exception]
		{
			#catch harmless exceptions for when we already registered the dll
			Write-Debug "$($_.Exception.Message)";
		}
		if($myProcess.exitcode -ne 0) {write-debug "Registing PVS PSSnapin x86 failed" }
		else { write-debug "Registering PVS PSSnapin x86 completed successfully" }
	}
	else
	{
		write-debug "Registering PVS PSSnapin x86"
		$myStart.Filename = "$installutil32\installutil.exe"
		$myStart.Arguments = "`"$env:SystemDrive\Program Files\Citrix\Provisioning Services Console\McliPSSnapin.dll`""
		try
		{
			$myProcess = [System.Diagnostics.Process]::Start($myStart)
			$myProcess.WaitForExit()
		}
		catch [Exception]
		{
			#catch harmless exceptions for when we already registered the dll
			Write-Debug "$($_.Exception.Message)";
		}
		if($myProcess.exitcode -ne 0) {write-debug "Registing PVS PSSnapin x86 failed" }
		else { write-debug "Registering PVS PSSnapin x86 completed successfully" }
	}
	
	Write-Verbose "Leaving function Register-MCLIPSSnapin"
}

function Add-MCLIPowershellSnapins{
<#
.Synopsis
 	Load PVS Powershell Snapin (MCLIPsSnapin). This is the old MCLI based snapin
#>
	write-verbose "Entering function Add-PVSPowershellSnapins"
	
    write-debug "Adding PVS PSSnapin to PS Session"
	try{add-pssnapin mclipssnapin -ErrorAction SilentlyContinue |out-null }
	catch [Exception] {
		#catch harmless exceptions in case we already loaded it
		Write-Debug "$($_.Exception.Message)";
	}
	
	write-verbose "Leaving function Add-PVSPowershellSnapins"
}

function Register-BdmPowerShellSdk{
<#
.Synopsis
	Registers PVS BdmPowerShellSdk (32 & 64)
#>
	write-verbose "invoking function Register-BdmPowerShellSdk"
	
    if (test-path "c:\windows\Microsoft.Net\Framework64\v2.0.50727") {
		$installutil64 = "c:\windows\Microsoft.Net\Framework64\v2.0.50727"
		$installutil32 = "c:\windows\Microsoft.Net\Framework\v2.0.50727"
    }elseif (test-path "c:\windows\Microsoft.Net\Framework64\v4.0.30319") {
        $installutil64 = "c:\windows\Microsoft.Net\Framework64\v4.0.30319"
		$installutil32 = "c:\windows\Microsoft.Net\Framework\v4.0.30319"
    }

	if (test-path "c:\program files (x86)")
	{
		write-debug "Registering BdmPowerShellSdk x64"
		$myStart = New-Object Diagnostics.ProcessStartInfo
		$myStart.Filename = "$installutil64\installutil.exe"
		$myStart.Arguments = "`"$env:SystemDrive\Program Files\Citrix\Provisioning Services Console\BdmPowerShellSdk.dll`""
		try
		{
			$myProcess = [System.Diagnostics.Process]::Start($myStart)
			$myProcess.WaitForExit()
		}
		catch [Exception]
		{
			#catch harmless exceptions for when we already registered the dll
			Write-Debug "$($_.Exception.Message)";
		}
		if($myProcess.exitcode -ne 0) {write-debug "Registing BdmPowerShellSdk x64 failed" }
		else { write-debug "Registering BdmPowerShellSdk x64 completed successfully" }

		write-debug "Registering BdmPowerShellSdk x86"
		$myStart.Filename = "$installutil32\installutil.exe"
		$myStart.Arguments = "`"$env:SystemDrive\Program Files\Citrix\Provisioning Services Console\BdmPowerShellSdk.dll`""
		try
		{
			$myProcess = [System.Diagnostics.Process]::Start($myStart)
			$myProcess.WaitForExit()
		}
		catch [Exception]
		{
			#catch harmless exceptions for when we already registered the dll
			Write-Debug "$($_.Exception.Message)";
		}
		if($myProcess.exitcode -ne 0) {write-debug "Registing BdmPowerShellSdk x86 failed" }
		else { write-debug "Registering BdmPowerShellSdk x86 completed successfully" }
	}
	else
	{
		write-debug "Registering BdmPowerShellSdk x86"
		$myStart.Filename = "$installutil32\installutil.exe"
		$myStart.Arguments = "`"$env:SystemDrive\Program Files\Citrix\Provisioning Services Console\BdmPowerShellSdk.dll`""
		try
		{
			$myProcess = [System.Diagnostics.Process]::Start($myStart)
			$myProcess.WaitForExit()
		}
		catch [Exception]
		{
			#catch harmless exceptions for when we already registered the dll
			Write-Debug "$($_.Exception.Message)";
		}
		if($myProcess.exitcode -ne 0) {write-debug "Registing BdmPowerShellSdk x86 failed" }
		else { write-debug "Registering BdmPowerShellSdk x86 completed successfully" }
	}
	
	Write-Verbose "Leaving function Register-BdmPowerShellSdk"
}

function Add-BdmPowerShellSdk{
<#
.Synopsis
 	Load BdmPowerShellSdk into Powershell
#>
	write-verbose "Entering function Add-BdmPowerShellSdk"
	
    write-debug "Adding PVS BdmPowerShellSdk to PS Session"
	try{add-pssnapin -Name BdmPsSnapIn -ErrorAction SilentlyContinue |out-null }
	catch [Exception] {
		#catch harmless exceptions in case we already loaded it
		Write-Debug "$($_.Exception.Message)";
	}
	
	write-verbose "Leaving function Add-BdmPowerShellSdk"
}

function Set-Bootstrap {
<#
.Synopsis
 	Sets a bootstrap IP for a specified PVS server
.Parameter server
    PVS Server in farm to configure
.Parameter boostrapFileName
    Boot strap file name to configure
.Parameter bootstrapNumber
    Int 1-4 of bootstrap server record to set
.Parameter bootstrapIP
    IPAddress of bootstrap server
.Parameter bootstrapPort
    Port of bootstrap 
#>
[CmdletBinding()]
    Param (
            [Parameter(Mandatory=$true)][string] $server,
            [Parameter(Mandatory=$false)][string] $boostrapFileName = "ardbp32.bin",
            [Parameter(Mandatory=$true)][int] $bootstrapNumber,
            [Parameter(Mandatory=$true)][string] $bootstrapIP,
            [Parameter(Mandatory=$false)][string] $bootstrapPort = 6910
            )

    Add-MCLIPowershellSnapins
    
    try {
        Mcli-set ServerBootstrap -p name=$boostrapFileName,servername=$server -r bootserver$($bootstrapNumber)_Ip=$bootstrapIP,bootserver$($bootstrapNumber)_Port=$bootstrapPort
    } catch {
        throw $_
    }
}

function Set-FarmLicensing {
<#
.Synopsis
 	Sets a license server and port for current PVS farm
.Parameter licenseServer
    License Server address to configure
.Parameter licenseServerPort
    License Server port to configure
#>
[CmdletBinding()]
    Param (
            [Parameter(Mandatory=$true)][string] $licenseServer,
            [Parameter(Mandatory=$false)][string] $licenseServerPort = "27000"
            )

    Add-MCLIPowershellSnapins
    
    try {
        Mcli-set farm -r licenseServer=$licenseServer,licenseServerPort=$licenseServerPort
    } catch {
        throw $_
    }
}

function New-BDMIso {
<#
.Synopsis
 	Generates a BDM boot ISO for provided login servers, using DHCP and default options
.Parameter LoginServerHash 
    Hash of LoginServer = Port to add to boot ISO
.Parameter ISOFile
    Full path including name of ISO File to create (i.e. "c:\isoFile.iso")
.Parameter UseDNS
    Switch, pass when using DNS Alias rather than static IPs
.Parameter DNSDomainName
    FQDN for domain of DNS alias
#>
[CmdletBinding()]
    Param (
            [Parameter(Mandatory=$true)][hashtable] $LoginServerHash,
            [Parameter(Mandatory=$false)][string] $ISOFile = "c:\PVSBootISO.iso",
            [Parameter(Mandatory=$false)][switch] $UseDNS,
            [Parameter(Mandatory=$false)][string] $DNSDomainName
    )
    cwcPVS\Add-BdmPowerShellSdk

    Write-Verbose "LoginServers to be configured:"
    $LoginServerHash
    
    # Create the BootDeviceManager to store all setting for the rest of the script.
    $bdm = New-BootDeviceManager

    #if UseDNS was passed configure BDM with the 1 entery in passed hash table
    if ($UseDNS) {
        $bdm.UseDNSforLoginServers($LoginServerHash.GetEnumerator().Name,$LoginServerHash.Get_Item($LoginServerHash.GetEnumerator().Name),"255.255.255.255","255.255.255.255")
        $bdm.DnsDomainName = $DNSDomainName
    }
    else {

        #Set logon Servers using static IPs in hashtable
        $LoginServerList = New-Object 'System.Collections.Generic.List[System.Collections.Generic.KeyValuePair[string,string]]'
        foreach ($server in $LoginServerHash.GetEnumerator()) {
            $ls = New-Object 'System.Collections.Generic.KeyValuePair[string,string]'($($server.Name), $($server.Value))
            $LoginServerList.Add($ls)
        }
        $bdm.LoginServers = $LoginServerList
    }

    # Set the default options
    # Verbose Mode: false
    # Interrupt Safe Mode: false
    # Advanced memory support: true
    # Network recovery: Restore Network Connection, since HardDriveRecover is false and RecoverySeconds is 0
    # Login polling timeout: 5000 MS
    # Login general timeout: 30000 MS
    $bdm.SetOptions($false, $false, $true, 5000, 30000, $false, 0)

    
    # Set the Disk to be the ISO
    $bdm.DiskString = "Citrix ISO Image Recorder"

    #Set DHCP option
    $bdm.DeviceIpDHCP=$true
    
    # Set the file name that will be created.
    $bdm.ISOFileName = $ISOFile

    # Create the file
    # forceBootPartition: false
    # forceLargeDisk: false
    $bdm.Burn($false, $false)
}

function Get-BootstrapServerIPs {
<#
.Synopsis
 	Gets a list of bootstrap IPs for a specified PVS server
.Parameter server
    PVS Server in farm to get bootstrap from
.Parameter boostrapFileName
    Boot strap file name to get
#>
[CmdletBinding()]
    Param (
            [Parameter(Mandatory=$true)][string] $server,
            [Parameter(Mandatory=$false)][string] $boostrapFileName = "ardbp32.bin"
            )

    Add-MCLIPowershellSnapins
    
    try {
        $results = Mcli-get ServerBootstrap -p name=$boostrapFileName,servername=$server
        $BootServerIPs = [System.Collections.ArrayList]@()
        $FinalBootServerIPs = [System.Collections.ArrayList]@()

        for ($i=1; $i -le 4; $i++)
        {
            Write-Verbose "Getting Record for bootserver$($i)_Ip"
            $record = $results | Select-String "bootserver$($i)_Ip"
            $BootServerIPs.add($record.toString().split(":")[1].trim()) | Out-Default
        }

        foreach ($ip in $BootServerIPs) {
            if ($ip -ne "0.0.0.0") {
                $FinalBootServerIPs.Add($ip) | Out-Default
            }
        }
        
        return $FinalBootServerIPs
    } catch {
        throw $_
    }
}

function Get-PVSServerStreamingIP {
<#
.Synopsis
 	Gets the configured streaming IP for a specified PVS server
.Parameter server
    PVS Server in farm to get streaming IP from
#>
[CmdletBinding()]
    Param (
            [Parameter(Mandatory=$true)][string] $server
            )

    Add-MCLIPowershellSnapins
    
    try {
        $PVSServerStringObj = Mcli-get server -p servername=$server
        $PVS_ServerStreamingIP = $([string]($PVSServerStringObj | select-string ip: -CaseSensitive)).split(":")[1].trim()
        write-verbose "Found: $server = $PVS_ServerStreamingIP"
        return $PVS_ServerStreamingIP
    } catch {
        throw $_
    }
}

Export-ModuleMember Install-PVS, Install-PVSClient, New-SiteDBScript, Start-SiteDBScript, Join-PVSFarm, Format-PVSAuthGroup
Export-ModuleMember Register-MCLIPSSnapin, Add-MCLIPowershellSnapins
Export-ModuleMember Set-Bootstrap, Set-FarmLicensing
Export-ModuleMember Register-BdmPowerShellSdk, Add-BdmPowerShellSdk, New-BDMIso, Get-BootstrapServerIPs, Get-PVSServerStreamingIP