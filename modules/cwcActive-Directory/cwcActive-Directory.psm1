<#
.SYNOPSIS
    This module file contains Active Directory functions.

    Copyright (c) Citrix Systems, Inc. All Rights Reserved.
.DESCRIPTION
    This module file includes Test-DomainMember, Add-DomainMember functions.
	Later, add more functions related to Active Directory to this module file.
#>
Set-StrictMode -Version 2
$ErrorActionPreference = "Stop"

function Test-DomainMember {
	<#
	.Synopsis
		Determins whether the local computer is a member of specific domain.
	.Description
		If the host is a domain member, return TRUE. Otherwise, return FALSE. 
	.Parameter DomainDnsName
		Specified the domain name to which the computer are added.
	.Example
		Test-DomainMember -DomainDnsName "testdc.company.com"
	#>	
    param(
		[parameter(mandatory=$true)][string]$DomainDnsName
	)
	$computer = Get-WmiObject Win32_ComputerSystem
	if(-not $computer)
	{
		#When it failed to get computer system info, assume FALSE by default.
		Write-Verbose "ERROR: Failed to get computer system information."
		return $false
	}
	
	if($computer.Domain -ieq $DomainDnsName)
	{
		Write-Verbose "Computer $(hostname) is a member of domain '$DomainDnsName'."
		return $true
	}
	
	Write-Verbose "Computer $(hostname) is not a member of domain '$DomainDnsName'."
	return $false
}

function Add-DomainMember {
	<#
	.Synopsis
		Adds the local computer to a domain.
    .Description
		When the local computer is a member of the specific domain, skip it. 
		Otherwise, leverage Add-Computer cmdlet to join the domain, reboot host to make the change effective if needed.         
	.Parameter DomainDnsName
		Specified the domain name to which the computer are added.
	.Parameter AdministratorUser
		Specifies a user account that has permission to join the computer to a new domain.
	.Parameter AdministratorPassword
		Specifies a passoword of a user account that has permission to join the computer to a new domain.
    .Parameter OUPath
        Specifies an organizational unit (OU) for the domain account. Enter the full distinguished name of the OU in quotation marks. The default value is the default OU for machine objects in the domain.
        i.e. "OU=Citrix,DC=domain,DC=Domain,DC=com"
	.Parameter Reboot
		Restarts the computer that were added to the domain. A restart is often required to make the change effective.
	.Example
		Add-DomainMember -DomainDnsName "testdc.company.com" -AdministratorUser "testdc\johndoe" -AdministratorPassword "abc123~"
	.Example
		Add-DomainMember -DomainDnsName "testdc.company.com" -AdministratorUser "testdc\johndoe" -AdministratorPassword "abc123~" -Reboot        
	#>		
	[CmdletBinding()]
	Param(
		[parameter(mandatory=$true)][ValidateNotNull()][string]$DomainDnsName,
		[parameter(mandatory=$true)][string]$AdministratorUser, 
		[parameter(mandatory=$true)][string]$AdministratorPassword,
        [Parameter(Mandatory=$false)][AllowEmptyString()][AllowNull()][string] $OUPath
	)
	if(cwcActive-Directory\Test-DomainMember -DomainDnsName $DomainDnsName)
	{
		Write-Verbose "Already in Domain:'$DomainDnsName'. Skipping."
        return
	}
	
	#Convert account/password to PScredential.
	$psCredential = cwcOS-Tools\ConvertTo-Credential -User $AdministratorUser -Password $AdministratorPassword 
    
	#Add computer to the domain, ensure failures don't block on user input on failure / warning
    $error.clear()
    If ($OUPath -eq '') {
        write-verbose "No OUPath provided, joining domain ..."
	    Add-Computer -DomainName $DomainDnsName -Credential $psCredential -Force
    } else {
        write-verbose "OUPath provided, joining domain in $OUPath ..."
        Add-Computer -DomainName $DomainDnsName -OUPath $OUPath -Credential $psCredential -Force
    }
	if (-not $?)
	{    
		$error
		throw "ERROR: Failed to join domain..."
	}    
	Write-Verbose "Domain join succeed."
}

function Test-OU {
	<#
	.Synopsis
		Determins whether a given OU path exists in the current domain.
	.Parameter OUPath
        Specifies an organizational unit (OU) path to the root OU the service account has full permissions to. Enter the full distinguished name of the OU in quotation marks. 
        i.e. "OU=Citrix,DC=domain,DC=Domain,DC=com"
	#>	
    param(
		[parameter(mandatory=$true)][string]$OUPath
	)
	Return $([ADSI]::Exists("LDAP://$OUPath"))
}

function Test-UserGroup {
	<#
	.Synopsis
		Determins whether a given user or group exists in the current domain.
	.Parameter Name
       Name of user or group to test
	#>	
    param(
		[parameter(mandatory=$true)][string]$Name
	)
    try {
        [string]$distinguishedName = ([adsi]"").distinguishedName
		$domainName = $distinguishedName.replace("DC=", "").replace(",", ".")		
        Return [ADSI]::Exists("WinNT://$domainName/$Name")
    } catch {
        return $false
    }
}



function New-OU {
	<#
	.Synopsis
		Creates an OU at a given path in the current domain.
	.Parameter NewOUName
        Name of new OU to create
    .Parameter OUPath
        Specifies an organizational unit (OU) path to the root OU the service account has full permissions to. Enter the full distinguished name of the OU in quotation marks. 
        i.e. "OU=Citrix,DC=domain,DC=Domain,DC=com"
	#>	
    param(
        [parameter(mandatory=$true)][string]$NewOUName,
		[parameter(mandatory=$true)][string]$OUPath
	)
    if (!(cwcActive-Directory\Test-OU -OUPath "OU=$NewOUName,$OUPath"))  {
        if (cwcActive-Directory\Test-OU -OUPath $OUPath) 
        {
            write-verbose "$OUPath exists, creating $OUPath"
            $Class = “organizationalUnit”
            $OU = “OU=$NewOUName”
            $objADSI = [ADSI]“LDAP://$OUPath”
            $objOU = $objADSI.create($Class, $OU)
            $objOU.setInfo()
        } else {
            throw "$OUPath does not exist"
        }
    } else {
        write-verbose "$NewOUName already exists in $OUPath ... skipping"
    }
}

function New-Group {
	<#
	.Synopsis
		Creates a group at a given path in the current domain.
	.Parameter NewGroupName
        Name of new OU to create
    .Parameter OUPath
        Specifies an organizational unit (OU) path to the root OU the service account has full permissions to. Enter the full distinguished name of the OU in quotation marks. 
        i.e. "OU=Citrix,DC=domain,DC=Domain,DC=com"
	#>	
    param(
        [parameter(mandatory=$true)][string]$NewGroupName,
		[parameter(mandatory=$true)][string]$OUPath
	)
    
    $FQGroupName = "CN=$NewGroupName,$OUPath"
    write-verbose "$FQGroupName"
    if (cwcActive-Directory\Test-UserGroup -Name $NewGroupName )
    {
        write-verbose "$NewGroupName already exists ... skipping"
    } else {
        write-verbose "$NewGroupName does not exist, creating in $OUPath"
        $objOU = [ADSI]"LDAP://$OUPath"
        $objGroup = $objOU.Create("group", "cn=$NewGroupName")
        $objGroup.Put("sAMAccountName", "$NewGroupName")
        $objGroup.SetInfo()
    }
}

Function Test-ADUser {
    <#
	.Synopsis
		Tests if an AD user exists in the current domain.
	.Parameter UserName
        Name of user account to test
	#>
    param (
        [parameter(mandatory=$true)][string]$UserName
    )

    $UserName = cwcActive-Directory\Test-SAMAccountName -UserName $UserName

    $searcher = [adsisearcher]"(samaccountname=$UserName)"
    $rtn = $searcher.findall()
 
    if($rtn.count -gt 0) { return $true }
    else { return $false }
}

Function Test-SAMAccountName {
    <#
	.Synopsis
		Tests if a SamAccount name is greater than 20 characters and returns truncated name if required.
	.Parameter UserName
        Name of user account to test
	#>
    param (
        [parameter(mandatory=$true)][string]$UserName
    )
    if ( $($UserName | Measure-Object -Character).Characters -gt 20) {
        Write-Verbose "$UserName is greater than 20 character SamAccount limit!"
        $UserName = $UserName.Substring(0,20)
        Write-Verbose "Truncating to $UserName"
    }
    return $UserName
}


Function Get-ADUserPath {
    <#
	.Synopsis
		Returns distigushed path for AD user in the current domain w/out LDAP:// prefix
	.Parameter UserName
        Name of user account to get
	#>
    param (
        [parameter(mandatory=$true)][string]$UserName
    )

    if (cwcActive-Directory\Test-ADUser -UserName $UserName)
	{
        $UserName = cwcActive-Directory\Test-SAMAccountName -UserName $UserName
        $searcher = [adsisearcher]"(samaccountname=$UserName)"
        $rtn = $searcher.findone()
        $fullPath = $rtn.Path
        Return $fullPath.split("//")[2]
    }
    else {
        write-verbose "$UserName not found"
    }
}

Function Get-ADGroupPath {
    <#
	.Synopsis
		Returns distigushed path for AD group in the current domain w/out LDAP:// prefix
	.Parameter UserName
        Name of group to get
	#>
    param (
        [parameter(mandatory=$true)][string]$GroupName
    )

    if (cwcActive-Directory\Test-UserGroup -Name $GroupName)
	{
        $UserName = cwcActive-Directory\Test-SAMAccountName -UserName $GroupName
        $searcher = [adsisearcher]"(samaccountname=$GroupName)"
        $rtn = $searcher.findone()
        $fullPath = $rtn.Path
        Return $fullPath.split("//")[2]
    }
    else {
        write-verbose "$GroupName not found"
    }
}

function New-ADUser {
	<#
	.Synopsis
		Creates a new active directory user.
	.Description
		Creates a new active directory user. If user only specifies user name,
		the new active directory user is created in 'CN=Users,DC=XD,DC=Local'.
		It replicates function New-ADUser in ActiveDirectory module and 
		extend basic interfaces to Windows Server 2K8 or earlier. 
	.Parameter Name
		Specifies the name of the object.
	.Parameter Path
		Specifies the X.500 path of the organization unit or container where the object is created.			
	.Parameter SamAccountName
		Specifies the security account manager account name of the user.
	.Parameter UserPrincipalName
		Specifies a user principle name(UPN) in the format <user>@<Domain-Name>.
	.Parameter DisplayName
		Specifies the display name of the object.
	.Parameter AccountPassword
		Specifies a new password value for an account.
	.Parameter PasswordNeverExpires
		Specifies whether the password of an account can expire.
	.Example
		New-ADUser -Name 'u1' -Path 'CN=Users,DC=XD,DC=Local' -AccountPassword 'Abc@123' -PasswordNeverExpires $True
	.Example
		New-ADUser -Name 'u2'
	#>			
	[CmdletBinding()]
	Param(
		[parameter(mandatory=$true)][ValidateNotNull()][string]$Name,
		[parameter(mandatory=$false)][string]$Path,
		[parameter(mandatory=$false)][string]$SamAccountName=$Name, 
		[parameter(mandatory=$false)][string]$UserPrincipalName, 
		[parameter(mandatory=$false)][string]$DisplayName=$Name,
        [parameter(mandatory=$false)][string]$Description="",
		[parameter(mandatory=$false)][string]$AccountPassword, 
		[parameter(mandatory=$false)][bool]$PasswordNeverExpires=$false
	)
	#To verify if the user has been exist
	if (!(cwcActive-Directory\Test-ADUser -UserName $Name))
	{
		[string]$distinguishedName = ([adsi]"").distinguishedName
		$domainName = $distinguishedName.replace("DC=", "").replace(",", ".")		

		if([string]::IsNullOrEmpty($Path))
		{
			$Path = "CN=Users," + $distinguishedName
		}
		
		Write-Verbose "Creating new user account $Name in path $Path of Active Directory."
		
		if([string]::IsNullOrEmpty($UserPrincipalName))
		{
			$UserPrincipalName = $Name + "@" + $domainName
		}
		
	    If ($(cwcActive-Directory\Test-OU -OUPath $Path) -eq $false) {
		    throw "Unable to create user, $Path does not exist!"
	    }

        $SamAccountName = cwcTools\New-UQUserName -UserName $Name
        $SamAccountName = cwcActive-Directory\Test-SAMAccountName -UserName $SamAccountName
        
		$cn = "CN=$SamAccountName"
		$objOU = [ADSI]("LDAP://" + $Path)
		$objUser = $objOU.Create("user", $cn)
		$objUser.SetInfo()
		$objUser.samaccountname = $SamAccountName
		$objUser.displayname = $DisplayName
		$objUser.userprincipalname = $UserPrincipalName
        $objUser.description = $Description
        $objUser.psbase.InvokeSet("AccountDisabled",$false)
		$objUser.SetInfo()
		
		if(-not ([string]::IsNullOrEmpty($AccountPassword)))
		{
			Write-Verbose "Setting account password."
			$objUser.SetPassword($AccountPassword)
			$objUser.SetInfo()
		}
		
		if($PasswordNeverExpires)
		{
			Write-Verbose "Setting password never expires."
			$objUser.useraccountcontrol = 66112
			$objUser.SetInfo()
		}
	} else {
        Write-Verbose "User $Name already exists ... skipping"
    }
}

function Add-ADGroupMember {
	<#
	.Synopsis
		Adds one member to an Active Directory group
	.Description
		Adds one users, groups, service accounts or computers as new members 
		of an Active Directory group. 
		It replicates function Add-ADGroupMember in ActiveDirectory module 
		and extend some basic interfaces to Windows Server 2K8 or earlier. 		
	.Parameter Identity
		Specifies an Active Directory group object by Distinguished Name.
	.Parameter Member
		Specifies user, group and computer objects to add to a group.		
	.Example
		Add-ADGroupMember -Identity 'CN=Domain Admins,CN=Users,DC=XD,DC=Local' -Member 'CN=u1,CN=Users,DC=XD,DC=Local'
	#>		
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)][string]$Identity,
		[Parameter(Mandatory=$true)][string]$Member
	)
    try {
	    Write-Verbose "Adding user $Member to Active Group $Identity"
	    $objGroup = [ADSI]("LDAP://" + $Identity)
	    $objGroup.Member += $Member
	    $objGroup.SetInfo()
    } catch {
        Write-Verbose "Failed to add user $Member to Active Group $Identity"
        Write-Verbose $_.Exception.Message
    }
}

function Remove-ADGroupMember {
	<#
	.Synopsis
		Removes one member from an Active Directory group
	.Description
		Removes a users, groups, service accounts or computers as members 
		of an Active Directory group. It replicates function Add-ADGroupMember in ActiveDirectory module 
		and extend some basic interfaces to Windows Server 2K8 or earlier. 		
	.Parameter Identity
		Specifies an Active Directory group object by Distinguished Name.
	.Parameter Member
		Specifies user, group and computer objects to add to a group.		
	.Example
		Remove-ADGroupMember -Identity 'CN=Domain Admins,CN=Users,DC=XD,DC=Local' -Member 'CN=u1,CN=Users,DC=XD,DC=Local'
	#>		
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)][string]$Identity,
		[Parameter(Mandatory=$true)][string]$Member
	)
    try {
	    Write-Verbose "Removing user $Member from Active Group $Identity"
	    $objGroup = [ADSI]("LDAP://" + $Identity)
	    $UserObj = [ADSI]("LDAP://" + $Member)
	    $objGroup.Remove($UserObj.adspath)
    } catch {
        Write-Verbose "Failed to remove user $Member from Active Group $Identity"
        Write-Verbose $_.Exception.Message
    }
}

function Add-LocalAdministrator {
    <#
    .Synopsis 
        Adds a user or group to local administrator group
    .Description
        Adds the given user or group to local administrators group on a local computer
    .Parameter ObjectType
        This parameter takes either of two values, User or Group. This parameter indicates the type of object
        you want to add to local administrators
    .Parameter ObjectName
        Name of the object (user or group) which you want to add to local administrators group. This should be in 
        Domain\UserName or Domain\GroupName format
    .Example
        Add-LocalAdministrator -ObjectType User -ObjectName "AD\TestUser1"
        Adds AD\TestUser1 user account to local administrators group on the local computer
    .Example
        Add-LocalAdministrator -ObjectType Group -ObjectName "ADDomain\AllUsers"
        Adds AD\TestUser1 Group to local administrators group on a local computer
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][ValidateSet("User","Group")][String] $ObjectType,
        [Parameter(Mandatory=$true)][string] $ObjectName,
        [Parameter(Mandatory=$true)][string] $DNSDomainName
    )
 
    $ObjDomain = cwcActive-Directory\Get-UserNetBIOSName
    $ComputerName = $env:COMPUTERNAME

    if ($ObjectType -eq "User") {
        $ObjectName = cwcActive-Directory\Test-SAMAccountName -UserName $ObjectName
    }

    try {
        $GroupObj = [ADSI]"WinNT://$ComputerName/Administrators"
        $GroupObj.Add("WinNT://$ObjDomain/$ObjectName")
        Write-Verbose "Successfully added $ObjectName $ObjectType to $ComputerName"
    } catch {
        Write-Verbose "Failed to add $ObjectName $ObjectType to $ComputerName"
        Write-Verbose $_.Exception.Message
    }
}

function Remove-LocalAdministrator {
    <#
    .Synopsis 
        Removes a user or group to local administrator group
    .Description
        Removes the given user or group to local administrators group on a local computer
    .Parameter ObjectType
        This parameter takes either of two values, User or Group. This parameter indicates the type of object
        you want to add to local administrators
    .Parameter ObjectName
        Name of the object (user or group) which you want to add to local administrators group. This should be in 
        Domain\UserName or Domain\GroupName format
    .Example
        Remove-LocalAdministrator -ObjectType User -ObjectName "AD\TestUser1"
        Adds AD\TestUser1 user account to local administrators group on the local computer
    .Example
        Remove-LocalAdministrator -ObjectType Group -ObjectName "ADDomain\AllUsers"
        Adds AD\TestUser1 Group to local administrators group on a local computer
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][ValidateSet("User","Group")][String] $ObjectType,
        [Parameter(Mandatory=$true)][string] $ObjectName,
        [Parameter(Mandatory=$true)][string] $DNSDomainName
    )
 
    $ObjDomain = cwcActive-Directory\Get-UserNetBIOSName
    $ComputerName = $env:COMPUTERNAME

    if ($ObjectType -eq "User") {
        $ObjectName = cwcActive-Directory\Test-SAMAccountName -UserName $ObjectName
    }

    try {
        $GroupObj = [ADSI]"WinNT://$ComputerName/Administrators"
        $GroupObj.Remove("WinNT://$ObjDomain/$ObjectName")
        Write-Verbose "Successfully removed $ObjectName $ObjectType from $ComputerName"
    } catch {
        Write-Verbose "Failed to remove $ObjectName $ObjectType from $ComputerName"
        Write-Verbose $_.Exception.Message
    }
}

function Get-UserNetBIOSName {
    <#
    .Synopsis 
        Gets the current user's NetBIOS domain name
    #>
    return $Env:USERDOMAIN
}

function Get-MachineDNSDomainName {
    <#
    .Synopsis 
        Gets the current machines's DNS domain name via WMI
    #>
    return (gwmi WIN32_ComputerSystem).Domain
}

Export-ModuleMember Add-DomainMember, Test-DomainMember
Export-ModuleMember Test-OU, New-OU, New-Group
Export-ModuleMember Test-SAMAccountName, Test-ADUser, Test-UserGroup, Get-ADUserPath, Get-ADGroupPath, New-ADUser, Add-ADGroupMember, Remove-ADGroupMember, Add-LocalAdministrator, Remove-LocalAdministrator
Export-ModuleMember Get-UserNetBIOSName, Get-MachineDNSDomainName