<#
.SYNOPSIS
    This module file contains SQL Server installation functions.

    Copyright (c) Citrix Systems, Inc. All Rights Reserved.
.DESCRIPTION
    Functions in this module provided a set of functions to build SQL server installation arguments based on different installation tasks.    
    Serveral default arguments sets have been added in function Initialize-Arguments, and any other more specific or frequently used arguments could be added if required.
.NOTES
    * For cluster installation and addnode installation, built-in accounts cannot be used. 
      So make sure to use -OverrideArgs to specify the accounts and passwords, or use -SetCredential -UserName <Username> -Password <Password> to set the credential for /AGTSVCACCOUNT /ASSVCACCOUNT /SQLSVCACCOUNT.
    * For cluster installation, please do override the /FAILOVERCLUSTERIPADDRESSES value.
      Refer to http://msdn.microsoft.com/en-us/library/ms144259(v=sql.105).aspx#ClusterInstall for more info.
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Add-Quotes{
    <#
    .SYNOPSIS
        Quote strings.        
    .DESCRIPTION
        This function add quotes for input string.      
    .PARAMETER String
        The string to add quotes around.
    .EXAMPLE
        $s = Add-Quotes "Hello World"                     
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,Position=0)][string]$String
    )
    Write-Verbose "Add-Quotes:Quote string $String"
    return "`"$string`""
}

function Remove-Arguments{
    <#
    .SYNOPSIS
        Remove install arguments from given arguments string.
    .DESCRIPTION
        Remove arguments from given arguments string. Including both switch args and key-value pair arguments.
    .PARAMETER SourceArgs
        The original argument string 
    .PARAMETER RemoveArgs
        An array which contains arguments to be removed from original argument string. *Each of the arguments can be preceded WITH slash or NOT. *
    .EXAMPLE        
        Remove argument "QS" in the source argument string.
        Remove-Arguments -SourceArgs "/ACTION=Install /FEATURES=SQL /QS" -RemoveArgs @("QS")
    .EXAMPLE
        Remove argument "Features" in the source argument string(preceded with a slash makes no difference).
        Remove-Arguments -SourceArgs "/ACTION=Install /FEATURES=SQL /QS" -RemoveArgs @("/FEATURES")
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$SourceArgs,
        [Parameter(Mandatory=$true)][String[]]$RemoveArgs
    )
    Write-Verbose "Remove-Arguments: Argument before process:`n$SOurceArgs"
    foreach($Arg in $RemoveArgs){
        $Arg = $Arg.Trim().Trim('/');
        $Reg = "/$Arg(\s|$)|/$Arg=\`".*?`"\s|/$Arg=\'.*?'\s|/$Arg=[^\'\`"]*?(\s|$)"
        $SourceArgs = $SourceArgs -replace $Reg,""
    }
    Write-Verbose "Remove-Arguments: Result after removing:`n$SOurceArgs"
    return $SourceArgs
}

function Set-Arguments{
    <#
    .SYNOPSIS
        Override the non-switch arguments.
    .DESCRIPTION
        Used to set key-value install arguments. You can also set switch argument. If not exist, the argument will be append at the end of argument string.
        *Remember to quote the values with blanks inside.         
    .PARAMETER SourceArgs
        The original argument string 
    .PARAMETER Arguments
        An array which contains arguments to override $SourceArgs, if any arguments of these is not exist, the argument will be append 
    .EXAMPLE
    Set an argument with ACTION="Uninstall"
        $arglist = Set-Arguments -SourceArgs "/ACTION=Install /FEATURES=SQL /AGTSVCACCOUNT=`"domain\admin`" /SQLSYSACCOUNT='test'" -Arguments @("ACTION=Uninstall","/SQLSYSACCOUNT='SeverAdmin'") 
    .EXAMPLE   
    Set a swithc argument "/INDICATEPROGRESS"
        $arglist = Set-Arguments -SourceArgs "/ACTION=Install /FEATURES=SQL /QS" -Arguments @("/INDICATEPROGRESS")
    #>
    [CmdletBinding()]    
    Param(
        [Parameter(Mandatory=$true)][string]$SourceArgs,
        [Parameter(Mandatory=$true)][string[]]$Arguments          
    )        
    Write-Verbose "Set-Arguments: Set arguments $Arguments on source arguments $SourceArgs"
    foreach ($arg in $Arguments){
        $arg = $arg.Trim().Trim('/');                            
        #Search and replace if SourceArgs is not empty string
        $key,$newvalue = $arg -split "="        
        if([string]::IsNullorEmpty($newvalue)){        
            #Switch argument
            $Reg = "/$key(\s|$)"            
            if($SourceArgs -match $Reg){
                #Do nothing if switch argument exist
                continue;
            }
            else{
                #Append the switch argument at the end of original string
                $SourceArgs += " /$arg"
            }
        }
        else{
            #Key-Value argument
            #Create regex pattern for matching argument value
            $Reg = "(?<=/$key=)\'(.*?)\'|(?<=/$key=)\`"(.*?)\`"|(?<=/$key=)[^\'\`"]*?(?=\s|$)"            
            if( $SourceArgs -match $Reg){
                $SourceArgs = $SourceArgs -replace $Reg,$newValue                                        
            }
            else {
                $SourceArgs += " /$arg"
            }
        }        
    }
    Write-Verbose "Set-Arguments:Result after processing:$SourceArgs"
    return $SourceArgs    
}

function Initialize-Arguments{
    <#
    .SYNOPSIS
        Set default arguments.          
    .DESCRIPTION
        1. Please refer to page http://msdn.microsoft.com/en-us/library/ms144259(v=sql.105).aspx for more information about installation arguments.
        2. You can specify any custom installation modes and tasks by modifying this ArgsLib table here.
        *Note that the non-bulitin sql accounts are in format of "current domain\user" like "citrite\user1", please override them with Set-Argumentss or Set-CredentialArguments if necessary *    
    #>  
    [CmdletBinding()]
    Param()
    $DomainAdminUser = [Environment]::UserDomainName + "\" + [Environment]::UserName 
    $script:ArgsLib = @{                         
                    "2K8R2|Enterprise|Standalone|Install" = "/ACTION=Install /FEATURES=SQL /INSTANCENAME=MSSQLSERVER /Q /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$($DomainAdminUser)`" /AGTSVCACCOUNT=`"NT AUTHORITY\Network Service`" /IACCEPTSQLSERVERLICENSETERMS";
                    "2K8R2|Enterprise|Standalone|Uninstall" = "/ACTION=Uninstall /FEATURES=SQL /INSTANCENAME=MSSQLSERVER /Q";
                    "2K8R2|Express|Standalone|Install" = "/ACTION=Install /FEATURES=SQL /INSTANCENAME=SQLEXPRESS /Q /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$($DomainAdminUser)`" /AGTSVCACCOUNT=`"NT AUTHORITY\Network Service`" /IACCEPTSQLSERVERLICENSETERMS";
                    "2K8R2|Express|Standalone|Uninstall" = "/ACTION=Uninstall /FEATURES=SQL /INSTANCENAME=MSSQLSERVER /Q";
                    "2K8R2|Enterprise|Cluster|AddNode" = "/ACTION=AddNode /Q /INSTANCENAME=SQLClusterInstance /SQLSVCACCOUNT=`"$($DomainAdminUser)`" /AGTSVCACCOUNT=`"$($DomainAdminUser)`" /IACCEPTSQLSERVERLICENSETERMS";
                    "2K8R2|Enterprise|Cluster|Install" = "/ACTION=InstallFailoverCluster /Q /InstanceName=SQLClusterInstance  /FAILOVERCLUSTERNETWORKNAME=SQLCluster /FAILOVERCLUSTERIPADDRESSES=`"IPv4;DHCP;Cluster Network 2`" /Features=SQL /AGTSVCACCOUNT=`"$($DomainAdminUser)`" " + " /AGTSVCPASSWORD=<Password> /SQLSVCACCOUNT=`"$($DomainAdminUser)`" /SQLSVCPASSWORD=<Password> /SQLSYSADMINACCOUNTS=`"$($DomainAdminUser)`" /IACCEPTSQLSERVERLICENSETERMS";
                    "2K12|Enterprise|Standalone|Install" = "/ACTION=Install /FEATURES=SQL /INSTANCENAME=MSSQLSERVER /Q /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$($DomainAdminUser)`" /AGTSVCACCOUNT=`"NT AUTHORITY\Network Service`" /IACCEPTSQLSERVERLICENSETERMS";                        
                    "2K12|Enterprise|Standalone|Uninstall" = "/ACTION=Uninstall /FEATURES=SQL /INSTANCENAME=MSSQLSERVER /Q";
                    "2K12|Express|Standalone|Install"    =  "/ACTION=Install /FEATURES=SQL /INSTANCENAME=SQLEXPRESS /Q /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$($DomainAdminUser)`" /AGTSVCACCOUNT=`"NT AUTHORITY\Network Service`" /IACCEPTSQLSERVERLICENSETERMS";                        
                    "2K12|Express|Standalone|Uninstall"    =  "/ACTION=Uninstall /FEATURES=SQL /INSTANCENAME=MSSQLSERVER /Q";
                    "2K12|Enterprise|Cluster|AddNode" = "/ACTION=AddNode /Q /INSTANCENAME=SQLClusterInstance /SQLSVCACCOUNT=`"$($DomainAdminUser)`" /AGTSVCACCOUNT=`"$($DomainAdminUser)`" /IACCEPTSQLSERVERLICENSETERMS";
                    "2K12|Enterprise|Cluster|Install" = "/ACTION=InstallFailoverCluster /Q /InstanceName=SQLClusterInstance  /FAILOVERCLUSTERNETWORKNAME=SQLCluster /FAILOVERCLUSTERIPADDRESSES=`"IPv4;DHCP;Cluster Network 2`" /Features=SQL /AGTSVCACCOUNT=`"$($DomainAdminUser)`" " + " /AGTSVCPASSWORD=<Password> /SQLSVCACCOUNT=`"$($DomainAdminUser)`" /SQLSVCPASSWORD=<Password> /SQLSYSADMINACCOUNTS=`"$($DomainAdminUser)`" /IACCEPTSQLSERVERLICENSETERMS";
                    "2K14|Enterprise|Standalone|Install" = "/ACTION=Install /FEATURES=SQL /INSTANCENAME=MSSQLSERVER /Q /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$($DomainAdminUser)`" /AGTSVCACCOUNT=`"NT AUTHORITY\Network Service`" /IACCEPTSQLSERVERLICENSETERMS";
                    "2K14|Standard|Standalone|Install" = "/ACTION=Install /FEATURES=SQL /INSTANCENAME=MSSQLSERVER /Q /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$($DomainAdminUser)`" /AGTSVCACCOUNT=`"NT AUTHORITY\Network Service`" /IACCEPTSQLSERVERLICENSETERMS";
                    "2K14|Express|Standalone|Install" = "/ACTION=Install /FEATURES=SQL /INSTANCENAME=SQLEXPRESS /Q /SQLSVCACCOUNT=`"NT AUTHORITY\SYSTEM`" /SQLSYSADMINACCOUNTS=`"$($DomainAdminUser)`" /AGTSVCACCOUNT=`"NT AUTHORITY\Network Service`" /IACCEPTSQLSERVERLICENSETERMS";                                      
                    }
    Write-Verbose "Initialize-Arguments:Default arguments initialized."                        
}

function Get-AvailableArgumentKeys{
    <#
    .SYNOPSIS
        List the keys in currently ArgsLib table.    
    .DESCRIPTION
        This function returns the array of keys in default argument lib. You should be able to  see the available version/edition and other information from the keys.            
    #>
    [CmdletBinding()]
    Param()
    return $Script:ArgsLib.Keys;
}

function Get-LibArgument{
     <#
    .SYNOPSIS
        Fetch the default arguments.
    .DESCRIPTION
        Get the pre-defined setup arguments based on given Version, Edition,Mode and argument set name. Return "" if no arguments found.
    .PARAMETER Version
        The major version of SQL server like "2K8R2", "2K12", "2K14".
    .PARAMETER Edition
        The editon of SQL server like "Enterprise","Express","Standard",etc.
    .PARAMETER Mode
        Specify the installation mode such as "Standalone" installation, or "Cluster" installation.
    .PARAMETER Task
        Specify the task under the mode, for example, there're two tasks:"AddNode" and "Install" for install mode "Cluster".
    .PARAMETER LibKey
        Can also get the argument string directly from a LibKey formatted as "2K8R2|Enterprise|Cluster|Install".
    .EXAMPLE        
        Get default argument for installing standalone 2K8R2 sqlserver with enterprise edition:
            Get-LibArgument -Version "2K8R2" -Edition "Enterprise" -Mode "Standalone" -Task "Install"
    .EXAMPLE 
        Directly get the argument from argument library for adding a cluster node to a SQL cluster of 2k12, enterprise editoin.
            Get-LibArgument -LibKey "2K12|Enterprise|Cluster|AddNode"
     #>
    [CmdletBinding(DefaultParameterSetName="direct")]
    param(
          [Parameter(ParameterSetName="detail",Mandatory=$true)][string]$Version,
          [Parameter(ParameterSetName="detail",Mandatory=$true)][string]$Edition,
          [Parameter(ParameterSetName="detail",Mandatory=$true)][string]$Mode,
          [Parameter(ParameterSetName="detail",Mandatory=$true)][string]$Task,
          [Parameter(ParameterSetName="direct",Mandatory=$true)][string]$LibKey)

    switch($PSCmdlet.ParameterSetName){
        'detail'{
            Write-Verbose ("Get-LibArgument: Lookup index " + (@($Version,$Edition,$Mode,$Task) -join "|"))
            $LibKey = @($Version,$Edition,$Mode,$Task) -join "|"
            $tempargs = $Script:ArgsLib[$LibKey]   
            break
        }
        'direct'{
            $tempargs = $Script:ArgsLib[$LibKey]            
            break
        }
        default {
            throw "Unexpected ParameterSetName $($PSCmdlet.ParameterSetName)."
        }
    }
    if ([String]::IsNullOrEmpty($tempargs)){
    
        Write-Verbose "Get-LibArgument: Could not found argument set for $LibKey"
        return ""
    }  
    Write-Verbose "Get-LibArgument: Found argument set $LibKey :`n$tempargs"
    return $tempargs    
 }

function Set-CredentialArguments{
     <#
    .SYNOPSIS
        Override the default account and password in argument library.
    .DESCRIPTION
        This function will override these three accounts most frequently required:
            - AGTSVCACCOUNT
            - ASSVCACCOUNT
            - SQLSVCACCOUNT
        with the account and password provided. 
    .PARAMETER SourceArgs
        The original argument string
    .PARAMETER AccountName
        The account name. 
    .PARAMETER Password
        The corresponding password
    .EXAMPLE    
        Override the credential 
        $clusterArg = Get-LibArgument -LibKey "2K12|Enterprise|Cluster|Install"
        $clusterArg = Set-CredentialArguments -SourceArgs $clusterArg -AccountName "testDomain\UserName01" -Password "password"        
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$SourceArgs,
        [Parameter(Mandatory=$true)][String]$AccountName,
        [Parameter(Mandatory=$true)][String]$Password
    )
    $tempAcct = cwcSQL\Add-Quotes($AccountName)
    $tempPwd = cwcSQL\Add-Quotes($Password)
    $OverridedArgs =  cwcSQL\Set-Arguments -SourceArgs $SourceArgs -Arguments @("/AGTSVCACCOUNT=$tempAcct","/AGTSVCPASSWORD=$tempPwd",
                        "/ASSVCACCOUNT=$tempAcct","/ASSVCPASSWORD=$tempPwd",
                        "/SQLSVCACCOUNT=$tempAcct","/SQLSVCPASSWORD=$tempPwd"
                    )                    
    return $OverridedArgs
 }
 
function Invoke-SQLInstall{
    <#
    .SYNOPSIS
        Invoke the setup.exe and show result.
    .DESCRIPTION
        This function is wrapped in Install-MSSQL. Throws exception when installation failed.
        The install output could be found at $env:Temp\SQL_ins_out.log
        Please check the logs in SQL diretory for detailed log information.
    .PARAMETER
        The setup binary path. 
    .PARAMETER Arguments
        Install arguments string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][String]$SetupPath,
        [Parameter(Mandatory=$true)][String]$Arguments
    )

    if(-not (Test-Path $SetupPath)){
        throw "Invalid setup path for SQL Server: $SetupPath"
    }

    Write-Verbose "Invoke-SQLInstall: Start installation with arguments:$Arguments`n::Setup binary location: $SetupPath"
    $p = Start-Process -FilePath $SetupPath -ArgumentList @($Arguments) -RedirectStandardOutput "$Env:TEMP\SQL_ins_out.log" -passThru -wait    

    $result = Get-Content "$env:Temp\SQL_ins_out.log"        

    if($p.ExitCode -ne 0)
    {    
        Write-Verbose "Invoke-SQLInstall: Error occurred during installation."
        foreach($line in $result){
            Write-Verbose $line
        }
        $exStr = "SQL Server Installation Failed. `n Output:`n $result"
        throw $exStr
    }
    Write-Verbose "Invoke-SQLInstall: SQL Server Installation success."                    
 }

function Install-MSSQL{
     <#
    .SYNOPSIS
        Start a SQL Server installation task with command line arguments.
    .DESCRIPTION
        This function start a MS Sql Server installation based on given arguments and path. Detailed parameters could be passed to utilize the default argument library in SQLInstallation module.
        Note:
        * The setup path should be accessible.
        * Before calling this function please make sure: 
            1. Security warning about invoke a remote ".exe" has been disabled.
            2. Compatibility warning for that binary has been suppressed.
          Otherwise installation could be blocked by those prompts.
    .PARAMETER Version
        The major version of SQL server like "2K8R2", "2K12" or "2K14"
    .PARAMETER Edition
        The editon of SQL server like "Enterprise","Express","Standard",etc.
    .PARAMETER Mode
        Specify the installation mode such as "Standalone" installation, or "Cluster" installation.
    .PARAMETER Task
        Specify the task under the mode, for example, there're two tasks:"AddNode" and "Install" for install mode "Cluster".    
    .PARAMETER OverrideArgs
        An array of arguments to do override
    .PARAMETER SetupPath
        The SQL server setup binary path.
    .PARAMETER Arguments
        (Direct invoke mode) The argument string used for invoke setup binary directly. The function will bypass the process of getting default argument and overriding.
    .PARAMETER SetCredential
        Indicate to use following UserName and Password as the SQL server services(AGTSVC/SQLSVC/ASSVC) account/password.
    .PARAMETER UserName
        UserName and for the SQL server services(AGTSVC/SQLSVC/ASSVC) accounts.
    .PARAMETER Password 
        Password for the SQL server services(AGTSVC/SQLSVC/ASSVC) passwords.
    .EXAMPLE
        Install failover cluster:        
        Install-MSSQL -Version 2K8R2 -Edition Enterprise -Mode "Cluster" -Task "Install" -SetupPath "c:\2008_R2\Enterprise\Image\setup.exe" -Override -OverrideArgs @("/INSTANCENAME=ClusterInstance01","FAILOVERCLUSTERNETWORKNAME=ClusterName01","/FAILOVERCLUSTERIPADDRESSES=`"IPv4;DHCP;Cluster Network 2`"") -SetCredential -UserName "MyDomain\Administrator" -Password "mypassword01" 

    .EXAMPLE
        Add current computer as a node of SQL cluster instance "ClusterInstance01"
        Install-MSSQL -Version 2K8R2 -Edition Enterprise -Mode "Cluster" -Task "AddNode" -SetupPath  "c:\\2008_R2\Enterprise\Image\setup.exe" -Override -OverrideArgs @("/INSTANCENAME=ClusterInstance01") -SetCredential -UserName "myDomain\Administrator" -Password "password02"

    .EXAMPLE
        Directly call setup arguments
        $arglist = Get-LibArgument "2K12|Enterprise|Standalone|alone"
        $arglist = Set-Arguments -SourceArgs $args -Arguments @("/FEATURES=SQL,TOOLS")
        Install-MSSQL -SetupPath "C:\setup.exe" -Arguments $arglist
    
    .EXAMPLE 
        Directly call setup with an ini configuration file.
        $arglist = "/IACCEPTSQLSERVERLICENSETERMS /ConfigurationFile=C:\Sql\config.ini"
        Invoke-MSSQL -SetupPath "c:\sql\setup.exe" -Arguments $arglist    
     #>
    [CmdletBinding(DefaultParameterSetName="invoke")]
    param(
        [Parameter(ParameterSetName="build",Mandatory=$true)]  [string]$Version,
        [Parameter(ParameterSetName="build",Mandatory=$true)]  [string]$Edition,
        [Parameter(ParameterSetName="build",Mandatory=$false)] [string]$Mode,
        [Parameter(ParameterSetName="build",Mandatory=$false)] [string]$Task,         
        [Parameter(ParameterSetName="build",Mandatory=$false)] [string[]]$OverrideArgs,
        [Parameter(ParameterSetName="invoke",Mandatory=$true)]  
        [Parameter(ParameterSetName="build",Mandatory=$true)]  [string]$SetupPath,
        [Parameter(ParameterSetName="invoke",Mandatory=$true)] [string]$Arguments,
        [Parameter(Mandatory=$false)]                          [switch]$SetCredential,
        [Parameter(Mandatory=$false)]                          [string]$UserName,
        [Parameter(Mandatory=$false)]                          [string]$Password                
    )
    switch($PSCmdlet.ParameterSetName)
    {
        "build" 
        #Get arguments from ArgsLib. And override the specified arguments like instance name,cluster disk etc.
        {
            if([System.String]::IsNullOrEmpty($Task)){
                $Task = "Install"
            }
            $Arguments = Get-LibArgument -Version $Version -Edition $Edition -Task $Task -Mode $Mode 

            if ($OverrideArgs -ne $null){
                $Arguments = Set-Arguments -SourceArgs $Arguments -Arguments $OverrideArgs
            }
            break                                                              
        }
        "invoke"
        #Directly invoke with the arguments
        {
            if(-not (Test-Path $SetupPath))
            {
                throw "-Install-MSSQL- Invalid setup path for SQL Server: $SetupPath"
            }                
            break
        }
       
    }
    if ($SetCredential){
    #Set all accounts with one username and password
        if([System.String]::IsNullOrEmpty($UserName) -or [System.String]::IsNullOrEmpty($Password)){
            throw "When use `"-SetCredential`" please specify the -UserName and -Password arguments to set SQL accounts credentials"
        }
        $Arguments = Set-CredentialArguments -SourceArgs $Arguments -AccountName $UserName -Password $Password 
    }

    $result = Invoke-SQLInstall -SetupPath $SetupPath -Arguments $Arguments   

 }

Function Get-SQLEndpoint {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$computername,
        [Parameter(Mandatory=$false)][string]$instancename
    )
 
    Begin {
        Write-Verbose "Loading SQL SMO"
        #Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
        #Add-Type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
        [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.SMO')
        [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.ConnectionInfo')
    }
 
    Process {
 
        try {
            $connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $ComputerName
            $connection.applicationName = "PowerShell SQL SMO"
 
            if ($InstanceName) {
                Write-Verbose "Connecting to SQL named instance"
                $connection.ServerInstance = "${ComputerName}\${InstanceName}"
            } else {
                Write-Verbose "Connecting to default SQL instance"
            }
 
            $connection.StatementTimeout = 0
            $connection.Connect()
            $smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $connection
            $smo.Endpoints | Select Name, EndPointType, ProtocolType, EndpointState, @{Name="ListenerPort";Expression={if ($_.ProtocolType -eq "TCP") {$_.Protocol.TCP.ListenerPort} else {$_.Protocol.HTTP.ListenerPort}}}
        }
        catch {
            Write-Error $_
        }
    }
}

Function New-SQLMirroringTCPEndpoint {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [Parameter(Mandatory=$true)][string]$EndpointName,
        [Parameter(Mandatory=$true)][string]$Edition,
        [Parameter(Mandatory=$false)][string]$InstanceName,
        [Parameter(Mandatory=$false)][int]$EndpointPort = 5022
    )
 
    Begin {
        Write-Verbose "Loading SQL SMO"
        #Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
        #Add-Type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, Version=11.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91"
        [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.SMO')
        [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.ConnectionInfo')
        Set-StrictMode -Off
    }
 
    Process {
            try {
                $connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $ComputerName
                $connection.applicationName = "PowerShell SQL SMO"
 
                if ($InstanceName) {
                    Write-Verbose "Connecting to SQL named instance"
                    $connection.ServerInstance = "${env:computername}\${InstanceName}"
                } else {
                    Write-Verbose "Connecting to default SQL instance"
                }
 
                $connection.StatementTimeout = 0
                $connection.Connect()
                $smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $connection
            }
            catch {
                Write-Error $_
            }
 
            try {
                if (!($smo.Endpoints[$EndpointName])) {
                    if (!((cwcSQL\Get-SQLEndPoint -computername $ComputerName -instancename $InstanceName).ListenerPort -contains $EndpointPort)) {
                        Write-Verbose "Creating a mirroring endpoint named ${EndpointName} at port ${EndpointPort}"
                        $SQLEndPoint = New-Object Microsoft.SqlServer.Management.Smo.Endpoint -ArgumentList $smo, $EndpointName
                        $SQLEndPoint.EndpointType = [Microsoft.SqlServer.Management.Smo.EndpointType]::DatabaseMirroring
                        $SQLEndPoint.ProtocolType = [Microsoft.SqlServer.Management.Smo.ProtocolType]::TCP
                        $SQLEndPoint.Protocol.Tcp.ListenerPort = $EndpointPort

                        if ($Edition.ToLower() -eq "express") {
                            Write-Verbose "Creating a mirroring endpoint Role Witness"
                            $SQLEndPoint.Payload.DatabaseMirroring.ServerMirroringRole = [Microsoft.SqlServer.Management.Smo.ServerMirroringRole]::Witness
                            $SQLEndPoint.Create()
                            $SQLEndPoint.Payload.DatabaseMirroring.EndpointEncryptionAlgorithm = [Microsoft.SqlServer.Management.Smo.EndpointEncryptionAlgorithm]::AES
                            $SQLEndPoint.Alter()
                        } else {
                            Write-Verbose "Creating a mirroring endpoint Role All"
                            $SQLEndPoint.Payload.DatabaseMirroring.ServerMirroringRole = [Microsoft.SqlServer.Management.Smo.ServerMirroringRole]::All
                            $SQLEndPoint.Create()
                            $SQLEndPoint.Payload.DatabaseMirroring.EndpointEncryptionAlgorithm = [Microsoft.SqlServer.Management.Smo.EndpointEncryptionAlgorithm]::AES
                            $SQLEndPoint.Alter()
                        }
                        $SQLEndPoint.Start()
                        $smo.Endpoints[$EndpointName]
                    } else {
                        Write-Verbose "An endpoint with specified port number ${EndpointPort} already exists"
                    }
                } else {
                    Write-Verbose "An endpoint with name ${EndpointName} already exists"
                }
            }
 
            catch {
                Write-Error $_
            }
    }
}

Function Enable-SqlServerRemote{
    <#
    .SYNOPSIS
       Enable remote connection for specified SQL Server instance.
    .DESCRIPTION
       This function enables remote connection by SMO class. References:http://msdn.microsoft.com/en-us/library/hh882461.aspx
    .PARAMETER ManagedComputer
       Managed Computer Name. If not supplied, local computer will be used
    .PARAMETER Instance
       Sql Server Instance Name
    .EXAMPLE
       support_install_enableSqlserverRemoteConnection -ManagedComputer $ManagedComputer -Instance $Instance
    #>

    [CmdletBinding()]
	param(
		[parameter(Mandatory = $false)] [string] $ManagedComputer = $env:COMPUTERNAME,
		[parameter(Mandatory = $false)] [string] $Instance
	)

	# Get a reference to the ManagedComputer class.
	$wmi = cwcSQL\Get-SqlManagedComputer 	
      
	# Enable the TCP protocol on the instance.    
    $Instance = $Instance.ToUpper()
    write-host "$Instance"
    if($Instance){
        $uri = "ManagedComputer[@Name=`'$ManagedComputer`']/ServerInstance[@Name=`'$Instance`']/ServerProtocol[@Name='Tcp']"
    }
    else{
        $uri = "ManagedComputer[@Name=`'$ManagedComputer`']/ServerInstance[@Name=`'MSSQLSERVER`']/ServerProtocol[@Name='Tcp']"
    }
    Write-Verbose "Enable-SqlServerRemote: Trying to get server instances with URI:$uri"
    try{
	    $Tcp = $wmi.GetSmoObject($uri)     
    }catch [Exception]
    {
        if (-not (cwcSQL\Test-PS64Bit)){
            try{
                write-host "ASHDASJDHJKASHDKJASHDJKAS"
                cwcSQL\Enable-SqlServerRemote64 -Instance $Instance -ManagedComputer $ManagedComputer
                Write-Verbose "Enable-SqlServerRemote: Enabled SQLServer remote connection sucess."
                return
            }
            catch [Exception]{
                throw "Could not found instance $Instance under computer $ManagedComputer. Please confirm the instance name."
            }
        }
        else{
            throw "Could not found instance $Instance under computer $ManagedComputer. Please confirm the instance name."
        }
    }
	if ($Tcp.IsEnabled) {
		Write-Verbose "Enable-SqlServerRemote:Apears Sqlserver: $ManagedComputer\$Instance's Remote Connection has already been enabled."		
        return
	}
	$Tcp.IsEnabled = $true
	$Tcp.Alter()
	$succeed = cwcSQL\Restart-SqlServerService -Instance $Instance
	$Tcp.Refresh()
	Write-Verbose "Enable-SqlServerRemote: Enabled SQLServer remote connection sucess."	
}

Function Enable-SqlServerRemote64{
    <#
    .SYNOPSIS
        Enable remote connection for specified SQL Server instance.
    .DESCRIPTION        
        This function will only be invoked Enable-SqlServerRemote in a 64bit PS console. 
        It start a new 64bit powershell session and load SQLConfiguration module in it, then Enable-SqlServerRemote will be launched there.
    .PARAMETER ManagedComputer
        Managed Computer Name. If not supplied, local computer will be used
    .PARAMETER Instance
        Sql Server Instance Name
    .EXAMPLE
        Enable-SqlServerRemote -Instance "MSSQLSERVER" -ManagedComputer "PC01"
    #>
    [CmdletBinding()]
    param(
		[parameter(Mandatory = $false)] [string] $ManagedComputer,
		[parameter(Mandatory = $true)]  [string] $Instance
	)
    if (cwcSQL\Test-PS64Bit)
    {
        Write-Verbose "This function could only be called under 32bit PS"
        return
    }
    #Copy current PSmodule path so that SQLConfiguration could be loaded in the new powershell console
    $currPath = Get-ModulePath -ModuleName "SQLConfiguration"
    $cmd = '& {' + "`n" +  '$env:PSModulePath += ";' + $currPath + "`"`n" +
                " import-module SQLConfiguration `n Enable-SqlServerRemote -Instance $Instance -ManagedComputer $ManagedComputer `n }"    
    
    $bytesCommand = [System.Text.Encoding]::Unicode.GetBytes($cmd)
    $encodedCommand = [Convert]::ToBase64String($bytesCommand)  

    try{
        C:\Windows\sysnative\WindowsPowerShell\v1.0\powershell.exe -encodedCommand $encodedCommand
    }catch{
        throw "Enable-SqlServerRemote64:Error invoking powershell.exe `n$_" 
    }    
}

function Unprotect-SecureString {
    <#
    .SYNOPSIS
        Decrypt a secure string to string(plain text)
    .DESCRIPTION
        This function take a secure string object and decrpted it.
    .PARAMETER SecureString
        The secure string object to be decrypted.
    .EXAMPLE
        $SecStr = Read-Host -AsSecureString
        $plainText = Unprotect-SecureString -SecureString $SecStr
    #>
    param(
        [Parameter(ValueFromPipeline=$true,Mandatory=$true)]
        [System.Security.SecureString]$SecureString        
    )

    $marshal = [System.Runtime.InteropServices.Marshal]
    $ptr = $marshal::SecureStringToBSTR($SecureString)
    $str = $marshal::PtrToStringBSTR($ptr)
    $marshal::ZeroFreeBSTR($ptr)
    $str
}

Function Get-SqlManagedComputer{
<#
    .SYNOPSIS
       Get WMI managed computer class object
    .DESCRIPTION
       This function fetch the WMI managed computer class object corresponding to the given ManagedComputer. If no parameters supplied, it will use the local computer
    .PARAMETER ManagedComputer
       Name of the managed computer. If empty then get local computer instance.
    .PARAMETER UserName
       Username for remote computer
    .PARAMETER Password   
       Password for remote computer
    .EXAMPLE
    Get the local computer:
       Get-SqlManagedComputer

#>
    [CmdletBinding(DefaultParameterSetName="ByName")]
    param(        
        [Parameter(ParameterSetName="ByName", Mandatory=$false)]        
        [Parameter(ParameterSetName="ByPassword",Mandatory=$true)]
        [String]$ManagedComputer,
        [Parameter(ParameterSetName="ByPassword", Mandatory=$true)][String]$UserName,
        [Parameter(ParameterSetName="ByPassword", Mandatory=$true)][System.Security.SecureString]$Password
    )
    
    cwcSQL\Import-SQLProvider
    Write-Verbose "Get-SqlManagedComputer:Trying to get managed computer $($PSCmdlet.ParameterSetName)"
    switch ($PSCmdlet.ParameterSetName){        
        "ByName"{
        
            if ([System.String]::IsNullOrEmpty($ManagedComputer)){                
                $computer = New-Object "Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer"
            }
            else{
                $computer = New-Object "Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer" $ManagedComputer
            }
			break
        }
        "ByPassword"{        
            $ppwd = cwcSQL\Unprotect-SecureString -SecureString $Password
            $computer = New-Object "Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer" $ManagedComputer $UserName $ppwd
			break
        }                
    }
    try{
        #Connect to the managed computer and get the services. Exception will be throw if RPC server not found.
        $null = $computer.Services 
    }catch{
            throw "Get-SqlManagedComputer: The RPC server on ManagedComputer is not available."            
    }
    Write-Verbose "Get-SqlManagedComputer:Success.Return the object."
    return $computer  
}

Function Import-SQLProvider{
    <#
    .SYNOPSIS
        Load SQL Server Provider.
    .DESCRIPTION
        Load the SQL Server assemblies(SMO and SMO WMI) to Windows PowerShell. 
    .NOTES
        This function need be called before any other functions could be lauched in this module.
        These two assemblies should be available in and after SQL Server 2005
    #>
    [CmdletBinding()]
    Param()
    $sqlProvider = ("Microsoft.SqlServer.Smo", "Microsoft.SqlServer.SqlWmiManagement")    	
	$sqlProvider | ForEach-Object {		
		$result = [reflection.assembly]::LoadWithPartialName($_)
        if ($result  -eq $null){
            throw "Error loading SMO assembly $_ for module SQLConfiguration. Please confirm SQL Server is installed on current machine."
        }
        Write-verbose "Import-SQLProvider:load assembly $_ "
	}
}

Function Test-PS64Bit {
    <#
    .SYNOPSIS
        Get the bit process of current powershell session
    .DESCRIPTION
        Internal function for Enable-SqlServerRemote, BEcause when invoked under 32bit PS, that function could not found instances properly.            
    #>
    [CmdletBinding()]
    Param()
    $Arch = (Get-Process -Id $PID).StartInfo.EnvironmentVariables["PROCESSOR_ARCHITECTURE"];
    if ($Arch -eq 'x86') {
        return $false;
    }
    elseif ($Arch -eq 'amd64') {
        return $true
    }
}

Function Restart-SqlServerService{
    <#
    .SYNOPSIS
        Restart the Database Engine
    .DESCRIPTION
        This function get the service name from the WMI SMO object then use it to stop and restart the instance service.
    .PARAMETER ManagedComputer
        Name of the managed computer. If empty then get local computer instance.
    .PARAMETER Instance
        Sql Server Instance Name. For default(unnamed) instance, leave this parameter empty
    .PARAMETER TimeOut
        A int seconds indicates after how long time to stop waiting(service stop/start). By default this is 30 seconds. 
        *To be accurate, please specify this number as multiples of 6.
    .EXAMPLE
        Restart the SQL Server service on local machine of the default instance. 
        Restart-SqlServerService 
    .EXAMPLE
        Restart the SQL Server service on remote machine "PC001" of instance "Instance02", with a timeout 60 seconds.
        Restart-SqlServerService -ManagedComputer PC001 -Instance Instance02 -TimeOut 60
    #>
    [CmdletBinding()]
    param(		
		[Parameter(Mandatory = $false)][string] $Instance,
        [Parameter(Mandatory = $false)][string] $ManagedComputer,
        [Parameter(Mandatory = $false)][int]    $TimeOut = 30         
	)   
    Write-Verbose "Restart instance $Instance from computer:  $ManagedComputer"
	# Get a reference to the ManagedComputer class.	
    if([System.String]::IsNullOrEmpty($ManagedComputer)){
	    $wmi = cwcSQL\Get-SqlManagedComputer 
    }
    else{
        $wmi = cwcSQL\Get-SqlManagedComputer -ManagedComputer $ManagedComputer
    }
	Write-Verbose "Restart-SqlServerService: Got a reference to the ManagedComputer class."

	#Handle instance name
    #All service name are in upper case
    
    if (!$Instance){
        $serviceName = "MSSQLSERVER"  #If no instance name specified, restart the default(unnamed instance)
    }
    else{
        $Instance = $Instance.ToUpper()
	    $serviceName = "MSSQL$" + $Instance   
    }

    # Get a reference to the instance of the Database Engine.
	$databaseEngineService = $wmi.Services[$serviceName]
    if ($databaseEngineService -eq $null) {        
        $availSvc = "";
        #Dump the available services for debug
        foreach($service in $wmi.Services){
             $availSvc += "`t" + $service.Name + "`n";
        }
        throw "Restart-SqlServerService:Could not found service $serviceName under $ManagedComputer, available services are:$availSvc "
    }

    Write-Verbose "Restart-SqlServerService: Service found.Stopping..."
	$databaseEngineService.Stop()

    $j = $TimeOut / 6
	# Wait until  the database engine service stop.
    $i = 0    
	while (($databaseEngineService.ServiceState -ne "Stopped") -and ($i -lt $j)){
        $i++
		sleep -Seconds 6
		$databaseEngineService.Refresh()
	}
	# Refresh the cache and start the database engine service.
	$databaseEngineService.Refresh()

    Write-Verbose "Restart-SqlServerService: Service stopped, now start it again..."
	$databaseEngineService.Start()

	# Wait until the service has time to start, timeout = 60s.
	$i = 0
	while (($databaseEngineService.ServiceState -ne "Running") -and ($i -lt $j)) {
        $i++
		sleep -Seconds 6
		$databaseEngineService.Refresh()
	}
	$databaseEngineService.Refresh()
    Write-Verbose "Restart-SqlServerService:Restarted $Instance Database Engine."	    
}

function Import-SQLPSModule {
    <#
    .SYNOPSIS
        Import SQLPS module
    .DESCRIPTION
        If current available PoSh module does not include 'SQLPS' then, import the following dll:
        'microsoft.sqlserver.management.pssnapins.dll', 'Microsoft.SqlServer.Management.PSProvider.dll'
        So that the SQL related cmdlet can be invoked in PowerShell.
    #>
    $s = Get-Module -ListAvailable | ?{$_.name -ieq 'SQLPS'}
    if($s -ne $null){
         Import-Module -Name 'SQLPS' -Global -Force
         return
    }

    $searchPath = @()
    $searchPath += Join-Path ${env:ProgramFiles(x86)} "Microsoft SQL Server"
    $searchPath += Join-Path ${env:ProgramFiles} "Microsoft SQL Server"

    $res = @(Get-Childitem -Recurse -Path $searchPath -Include @('microsoft.sqlserver.management.pssnapins.dll', 'Microsoft.SqlServer.Management.PSProvider.dll'))
    if($res -ne $null){
            $res |%{
                  Write-Verbose "Importing $_"
                  Import-Module -Name $_.FullName
            }
    }
}  

function Backup-DatabaseToMirrorORG {
    <#
    .SYNOPSIS
         Backs up a database to be imported on a secondary SQL server for mirroring. Requires SQLPS module!
    .PARAMETER DatabaseName
        Name of the database to backup
    .PARAMETER DatabaseServer
        Name of the database server
    .PARAMETER DatabaseInstanceName
        Name of the database server instance
    .PARAMETER BackupPath
        Path to store database backup
    #>
    [CmdletBinding()]
    param(		
		[Parameter(Mandatory = $true)][string] $DatabaseName,
        [Parameter(Mandatory = $true)][string] $DatabaseServer,
        [Parameter(Mandatory = $false)][string] $DatabaseInstanceName,
        [Parameter(Mandatory = $false)][string] $BackupPath = "$env:systemdrive\Windows\temp"
	)
    cwcSQL\Import-SQLPSModule
	
	Write-Verbose "Change recovery mode on $DatabaseServer\$DatabaseInstanceName"
	SQLPS\Invoke-SqlCmd -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "USE master; ALTER DATABASE `"$DatabaseName`" SET RECOVERY FULL;"
	
	Write-Verbose "Backup database on $DatabaseServer\$DatabaseInstanceName"
	SQLPS\Backup-SqlDatabase -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Database $DatabaseName -BackupFile "$BackupPath\$DatabaseName.bak"
}

function Backup-DatabaseToMirror {
    <#
    .SYNOPSIS
         Backs up a database to be imported on a secondary SQL server for mirroring. Requires SQLPS module!
    .PARAMETER DatabaseName
        Name of the database to backup
    .PARAMETER DatabaseServer
        Name of the database server
    .PARAMETER DatabaseInstanceName
        Name of the database server instance
    .PARAMETER BackupPath
        Path to store database backup
    #>
    [CmdletBinding()]
    param(		
		[Parameter(Mandatory = $true)][string] $DatabaseName,
        [Parameter(Mandatory = $true)][string] $DatabaseServer,
        [Parameter(Mandatory = $false)][string] $DatabaseInstanceName,
        [Parameter(Mandatory = $false)][string] $BackupPath = "$env:systemdrive\Windows\temp"
	)
    cwcSQL\Import-SQLPSModule
	
	Write-Verbose "Change recovery mode on $DatabaseServer\$DatabaseInstanceName"
	SQLPS\Invoke-SqlCmd -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "USE master; ALTER DATABASE `"$DatabaseName`" SET RECOVERY FULL;"
	
	Write-Verbose "Backup database on $DatabaseServer\$DatabaseInstanceName"
    SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "BACKUP DATABASE [$DatabaseName] TO DISK = '$BackupPath\$DatabaseName.bak' WITH CHECKSUM"
    SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "RESTORE VERIFYONLY FROM DISK = '$BackupPath\$DatabaseName.bak' WITH CHECKSUM"
}

function Restore-DatabaseForMirror {
    <#
    .SYNOPSIS
         Backs up a database to be imported on a secondary SQL server for mirroring. Requires SQLPS module!
    .PARAMETER DatabaseName
        Name of the database to backup
    .PARAMETER DatabaseServer
        Name of the database server
    .PARAMETER DatabaseInstanceName
        Name of the database server instance
    .PARAMETER BackupPath
        Path to store database backup
    #>
    [CmdletBinding()]
    param(		
		[Parameter(Mandatory = $true)][string] $DatabaseName,
        [Parameter(Mandatory = $true)][string] $DatabaseServer,
        [Parameter(Mandatory = $false)][string] $DatabaseInstanceName,
        [Parameter(Mandatory = $false)][string] $BackupPath = "$env:systemdrive\Windows\temp"
	)
    cwcSQL\Import-SQLPSModule
	
	Write-Verbose "Restore database"
    $dbInfo = SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "RESTORE FILELISTONLY FROM DISK='$BackupPath\$DatabaseName.bak'"
    $dbDLogicalName = ($dbInfo | where {$_.Type -eq "D"}).LogicalName
    $dbLLogicalName = ($dbInfo | where {$_.Type -eq "L"}).LogicalName

    $dataPath = cwcSQL\Get-DefaultSQLDataPath -DatabaseServer $DatabaseServer -DatabaseInstanceName $DatabaseInstanceName
    $logPath = cwcSQL\Get-DefaultSQLLogPath -DatabaseServer $DatabaseServer -DatabaseInstanceName $DatabaseInstanceName

    SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "RESTORE DATABASE [$DatabaseName] FROM DISK='$BackupPath\$DatabaseName.bak' WITH REPLACE,NORECOVERY, MOVE '$dbDLogicalName' TO '$dataPath\$dbDLogicalName.mdf', MOVE '$dbLLogicalName' TO '$logPath\$dbDLogicalName.ldf'"
}

function Get-DefaultSQLDataPath {
    <#
    .SYNOPSIS
         Retrieves the default data path for a SQL server.
    .PARAMETER DatabaseServer
        Name of the database server
    .PARAMETER DatabaseInstanceName
        Name of the database server instance
    #>
    [CmdletBinding()]
    param(		
        [Parameter(Mandatory = $true)][string] $DatabaseServer,
        [Parameter(Mandatory = $false)][string] $DatabaseInstanceName
	)
    Begin {
        Write-Verbose "Loading SQL SMO"
        [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.SMO') | Out-Null
        [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.ConnectionInfo') | Out-Null
    }
 
    Process {
 
        try {
            $connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $DatabaseServer
            $connection.applicationName = "PowerShell SQL SMO"
 
            if ($DatabaseInstanceName) {
                Write-Verbose "Connecting to SQL named instance"
                $connection.ServerInstance = "${DatabaseServer}\${DatabaseInstanceName}"
            } else {
                Write-Verbose "Connecting to default SQL instance"
            }
 
            $connection.StatementTimeout = 0
            $connection.Connect()
            $smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $connection

            <#
            when the default location for the user database files is the same as the system database files, the DefaultFile and DefaultLog properties are never initialized.
            If you change them (using Management Studio or via the registry values) then the properties will be populated, but if you don't the values will be empty. 
            This is true for a default SQL 2008 r2 installation but was fixed by MS at some point and now works in SQL 2014. Accomidate it by using MasterDBPath &
            MasterDBLogPath when values are null 
            #>

            if ($smo.Settings.DefaultFile.Length -eq 0) {
	            return $smo.Information.MasterDBPath
	        } else {
                return $smo.Settings.DefaultFile
            }

        }
        catch {
            Write-Error $_
        }
    }
}
function Get-DefaultSQLLogPath {
    <#
    .SYNOPSIS
         Retrieves the default log path for a SQL server.
    .PARAMETER DatabaseServer
        Name of the database server
    .PARAMETER DatabaseInstanceName
        Name of the database server instance
    #>
    [CmdletBinding()]
    param(		
        [Parameter(Mandatory = $true)][string] $DatabaseServer,
        [Parameter(Mandatory = $false)][string] $DatabaseInstanceName
	)
    Begin {
        Write-Verbose "Loading SQL SMO"
        [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.SMO') | Out-Null
        [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.ConnectionInfo') | Out-Null
    }
 
    Process {
 
        try {
            $connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $DatabaseServer
            $connection.applicationName = "PowerShell SQL SMO"
 
            if ($DatabaseInstanceName) {
                Write-Verbose "Connecting to SQL named instance"
                $connection.ServerInstance = "${DatabaseServer}\${DatabaseInstanceName}"
            } else {
                Write-Verbose "Connecting to default SQL instance"
            }
 
            $connection.StatementTimeout = 0
            $connection.Connect()
            $smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $connection

            <#
            when the default location for the user database files is the same as the system database files, the DefaultFile and DefaultLog properties are never initialized.
            If you change them (using Management Studio or via the registry values) then the properties will be populated, but if you don't the values will be empty. 
            This is true for a default SQL 2008 r2 installation but was fixed by MS at some point and now works in SQL 2014. Accomidate it by using MasterDBPath &
            MasterDBLogPath when values are null 
            #>

            if ($smo.Settings.DefaultLog.Length -eq 0) {
	            return $smo.Information.MasterDBLogPath
	        } else {
                return $smo.Settings.DefaultLog
            }
        }
        catch {
            Write-Error $_
        }
    }
}
function Get-DefaultSQLBackupPath {
    <#
    .SYNOPSIS
         Retrieves the default backup path for a SQL server.
    .PARAMETER DatabaseServer
        Name of the database server
    .PARAMETER DatabaseInstanceName
        Name of the database server instance
    #>
    [CmdletBinding()]
    param(		
        [Parameter(Mandatory = $true)][string] $DatabaseServer,
        [Parameter(Mandatory = $false)][string] $DatabaseInstanceName
	)
 
    try {
        Write-Verbose "Loading SQL SMO"
        [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.SMO') | Out-Null
        [System.Reflection.Assembly]::LoadWithPartialName( 'Microsoft.SqlServer.ConnectionInfo') | Out-Null

        $connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $DatabaseServer
        $connection.applicationName = "PowerShell SQL SMO"
 
        if ($DatabaseInstanceName) {
            Write-Verbose "Connecting to SQL named instance"
            $connection.ServerInstance = "${DatabaseServer}\${DatabaseInstanceName}"
        } else {
            Write-Verbose "Connecting to default SQL instance"
        }
 
        $connection.StatementTimeout = 0
        $connection.Connect()
        $smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $connection

        return $smo.Settings.BackupDirectory
    }
    catch {
        Write-Error $_
    }
}

function Set-MirrorPartner {
    <#
    .SYNOPSIS
         Enableds a mirror partner for a database and optionally a witness server
    .PARAMETER DatabaseName
        Name of the database to backup
    .PARAMETER DatabaseServer
        Name of the database server
    .PARAMETER DatabaseInstanceName
        Name of the database server instance
    .PARAMETER MirrorServer
        Name of the database Mirror Partner
    .PARAMETER MirrorInstanceName
        Name of the database Mirror instance
    .PARAMETER WitnessServer
        Name of the Witness server
    .PARAMETER WitnessInstanceName
        Name of the Witness server instance
    #>
    [CmdletBinding()]
    param(		
		[Parameter(Mandatory = $true)][string] $DatabaseName,
        [Parameter(Mandatory = $true)][string] $DatabaseServer,
        [Parameter(Mandatory = $false)][string] $DatabaseInstanceName,
        [Parameter(Mandatory = $true)][string] $MirrorServer,
        [Parameter(Mandatory = $false)][string] $MirrorInstanceName,
        [Parameter(Mandatory = $false)][string] $EndpointPort = "5022"
	)
	cwcSQL\Import-SQLPSModule
    
    $MirrorServerString = "'TCP://$MirrorServer" + ":$EndpointPort'"

    Write-Host "Enabling $MirrorServerString as mirror partner for $DatabaseName on $DatabaseServer\$DatabaseInstanceName"

    SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "ALTER DATABASE $DatabaseName SET PARTNER = $MirrorServerString" -QueryTimeout 300
}

function Set-MirrorWitness {
    <#
    .SYNOPSIS
         Enableds a mirror partner for a database and optionally a witness server
    .PARAMETER DatabaseName
        Name of the database to backup
    .PARAMETER DatabaseServer
        Name of the database server
    .PARAMETER DatabaseInstanceName
        Name of the database server instance
    .PARAMETER MirrorServer
        Name of the database Mirror Partner
    .PARAMETER MirrorInstanceName
        Name of the database Mirror instance
    .PARAMETER WitnessServer
        Name of the Witness server
    .PARAMETER WitnessInstanceName
        Name of the Witness server instance
    #>
    [CmdletBinding()]
    param(		
		[Parameter(Mandatory = $true)][string] $DatabaseName,
        [Parameter(Mandatory = $true)][string] $DatabaseServer,
        [Parameter(Mandatory = $false)][string] $DatabaseInstanceName,
        [Parameter(Mandatory = $false)][string] $WitnessServer,
        [Parameter(Mandatory = $false)][string] $WitnessInstanceName,
        [Parameter(Mandatory = $false)][string] $EndpointPort = "5022"
	)
	cwcSQL\Import-SQLPSModule
    
    $WitnessServerString = "'TCP://$WitnessServer" + ":$EndpointPort'"

    Write-Host "Enabling $WitnessServerString as witness for $DatabaseName on $DatabaseServer\$DatabaseInstanceName"

    SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "ALTER DATABASE $DatabaseName SET WITNESS = $WitnessServerString" -QueryTimeout 300
}

function Set-MirrorEndPointConnectPermissions {
    <#
    .SYNOPSIS
         Enables a server logon and connect permissions to specified endpoint
    .PARAMETER DatabaseServer
        Name of the database server
    .PARAMETER DatabaseInstanceName
        Name of the database server instance
    .PARAMETER Account
        Name of the account to grant permissions in form of domain\user
    .PARAMETER EndpointName
        Name of the endpoint to assign connect permissions
    #>
    [CmdletBinding()]
    param(		
        [Parameter(Mandatory = $true)][string] $DatabaseServer,
        [Parameter(Mandatory = $false)][string] $DatabaseInstanceName,
        [Parameter(Mandatory = $true)][string] $Account,
        [Parameter(Mandatory = $false)][string] $EndpointName = "Mirroring"
	)
	cwcSQL\Import-SQLPSModule

    Write-Host "Enabling logon and connect permissions for $Account on $DatabaseServer\$DatabaseInstanceName"
    $error.clear()
    try {
        SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "CREATE LOGIN [$Account] FROM WINDOWS;"
    }
    catch {
        #Ignore exception if user account already exists
        if ($_.Exception.Message.ToLower().Contains("already exists")) {
            write-verbose "$Account already exists as logon ... skipping"
        }
    }
    SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "GRANT CONNECT on ENDPOINT::$EndpointName TO [$Account];"

    #Write-Host "Restarting Endpoint: $EndpointName on $DatabaseServer\$DatabaseInstanceName"
    #SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "ALTER ENDPOINT $EndpointName STATE = STOPPED"
    #SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "ALTER ENDPOINT $EndpointName STATE = STARTED"
}

function Set-XDControllerPermissions {
    <#
    .SYNOPSIS
         Enables a server logon and grants sysadmin and dbcreator roles
    .PARAMETER DatabaseServer
        Name of the database server
    .PARAMETER DatabaseInstanceName
        Name of the database server instance
    .PARAMETER Account
        Name of the account to grant permissions in form of domain\user
    #>
    [CmdletBinding()]
    param(		
        [Parameter(Mandatory = $true)][string] $DatabaseServer,
        [Parameter(Mandatory = $false)][string] $DatabaseInstanceName,
        [Parameter(Mandatory = $true)][string] $Account
	)
	cwcSQL\Import-SQLPSModule

    #enable machine account logon for DDC
    try {
        Write-Verbose "Enabling logon for $Account on $DatabaseServer\$DatabaseInstanceName"
        SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "CREATE LOGIN [$Account] FROM WINDOWS;"
    } catch {
        Write-Verbose $_.Exception.Message
    }

    #add machine account logon for DDC to dbcreator and sysadmin role
    try {
        Write-Verbose "Adding $Account to roles sysadmin and dbcreator on $DatabaseServer\$DatabaseInstanceName"
        SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "ALTER SERVER ROLE [sysadmin] ADD MEMBER [$Account]"
        SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "ALTER SERVER ROLE [dbcreator] ADD MEMBER [$Account]"
    } catch {
        Write-Verbose $_.Exception.Message
        try {
            #try using an older format incase of 2008 SQL
            SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "EXEC sp_addsrvrolemember [$Account], 'sysadmin';"
            SQLPS\Invoke-SQLCMD -ServerInstance "$DatabaseServer\$DatabaseInstanceName" -Query "EXEC sp_addsrvrolemember [$Account], 'dbcreator';"
        } catch {
            Write-Verbose $_.Exception.Message
        }
    }
}

Initialize-Arguments
Export-ModuleMember Remove-Arguments,Set-Arguments,Initialize-Arguments,Get-AvailableArgumentKeys,Get-LibArgument,Set-CredentialArguments,Add-Quotes
Export-ModuleMember Invoke-SQLInstall,Install-MSSQL
Export-ModuleMember Get-SQLEndpoint, New-SQLMirroringTCPEndpoint
Export-ModuleMember Enable-SqlServerRemote, Enable-SqlServerRemote64, Unprotect-SecureString, Get-SqlManagedComputer, Test-PS64Bit, Restart-SqlServerService, Import-SQLProvider
Export-ModuleMember Import-SQLPSModule, Backup-DatabaseToMirror, Restore-DatabaseForMirror, Set-MirrorPartner,Set-MirrorWitness, Set-MirrorEndPointConnectPermissions
Export-ModuleMember Get-DefaultSQLDataPath, Get-DefaultSQLLogPath, Get-DefaultSQLBackupPath
Export-ModuleMember Set-XDControllerPermissions