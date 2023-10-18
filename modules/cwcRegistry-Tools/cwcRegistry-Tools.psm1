<#
.SYNOPSIS
	This module file contains registry functions.

	Copyright (c) Citrix Systems, Inc. All Rights Reserved.
.DESCRIPTION
	This module file uses PowerShell native command to create registry keys and
	values, instead of invoking regedit.exe to do it. 
	It supports all registry types, including REG_SZ, REG_EXPAND_SZ, REG_MULTI_SZ,
	REG_BINARY, REG_DWORD, REG_QWORD.
#>
Set-StrictMode -Version 2
$ErrorActionPreference = "Stop"

#Mapping table from registry type to ItemProperty type of PowerShell.
$regType = @{REG_SZ="String";REG_EXPAND_SZ="ExpandString";REG_BINARY="Binary";
			 REG_DWORD="DWord";REG_MULTI_SZ="MultiString";REG_QWORD="QWord"}

function Set-RegistryValues {
	<#
	.SYNOPSIS
		Sets registry values for specified key.
	.DESCRIPTION
		Sets registry value with the specified values. If Key exists, update/add 
		registry value depending on whether value exists. Otherwise, create the
		specified Key, then add the values.
	.Parameter Key
		Specified registry key name.
	.Parameter Type
		Specified registry value type.
	.Parameter Values
		Specified the values to be set.
	.Example 
		Set-RegistryValues -Key "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Type REG_SZ -Values @{DefaultDomainName="testdc.company.com"}
	.Example 
		Set-RegistryValues -Key "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Type REG_DWORD -Values @{AutoLogonCount=1}
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string] 
		$Key,
            
		[Parameter(Mandatory=$true)]
		[ValidateSet("REG_SZ","REG_EXPAND_SZ", "REG_BINARY","REG_DWORD","REG_MULTI_SZ","REG_QWORD")]
		[string]
		$Type,
		
		[Parameter(Mandatory=$true)]
		[Hashtable]
		$Values
	)
	if (Test-Path $Key)
	{
		#If Key exists, skipping.
		Write-Verbose "Updating registry key='$Key'."
	}
	else
	{
		# If Key not exists, create a new one.
		Write-Verbose "Creating registry key='$Key'."
		New-Item -Path $Key -ItemType Registry -Force | Out-Null
		if(-not $?)
		{
			$error[0]
			throw "ERROR:Failed to create registry key='$Key'."
		}
	}
	
	if ($Values.Count -eq 0)
	{
		throw "ERROR:The parameter Values cannot be empty."
	}
    
	# Loop through Values to update it if the value exists, or add it if the value doesn't exist.
	foreach ($ValueName in $Values.Keys)
	{
		Set-ItemProperty -Path $Key -Name $ValueName -Value $Values.$ValueName -Type $regType.$Type -Force
		if(-not $?)
		{
			# When one value failed, throw error.
			$error[0]
			throw "ERROR:Failed to set ItemProperty with Name='$ValueName', Value='$($Values.$ValueName)'."
		}
		Write-Verbose "Successfully sets ItemProperty with Name='$ValueName', Value='$($Values.$ValueName)'."
	}
}

function Get-RegistryValues {
	<#
	.SYNOPSIS
		Gets registry values for specified key or specified value.
	.DESCRIPTION
		When user specifies Key and Value Name, return the specific value name 
		and value pair in hash table. When user only speficies Key, return all 
		value name and value pair in hash table.
		When Key or Value Name doesn't exist, return emtpy hash table. 
	.Parameter Key
		Specified registry key name.
	.Parameter ValueName
		Specified the value name to be retrieved.
	.Example 
		Get-RegistryValues -Key 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ValueName 'AutoAdminLogon' 
	.Example 
		Get-RegistryValues -Key "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)][string]$Key,
		[Parameter(Mandatory=$false)][string]$ValueName
	)
	$hashTbl = @{}
	if(-not (Test-Path $Key))
	{
		#If Key doesn't exist, return empty hash table directly.
		Write-Verbose "Registry key :'$Key' doesn't exist."
		return $hashTbl
	}	
	
	if(-not [string]::IsNullOrEmpty($ValueName))
	{
		Write-Verbose "Getting the value of ValueName:'$ValueName' in Key:'$Key'."
		# When value name doesn't exist, suppress the exception error with SlientlyContinue.
		$psObject1 = Get-ItemProperty -Path $Key -Name $ValueName -ErrorAction SilentlyContinue
		if(-not $psObject1)
		{
			Write-Verbose "Registry value : '$ValueName' doesn't exist in key='$Key'."
			return $hashTbl			
		}
		$psObject = $psObject1 | Select-Object -Property $ValueName
	}
	else
	{
		Write-Verbose "Getting all the values in Key:'$Key'."
		$psObject = Get-ItemProperty -Path $Key
	}
	
	foreach($item in $psObject)
	{
		$item | Get-Member -MemberType *Property | %{$hashTbl.($_.name) = $item.($_.name)}
	}
	
	return $hashTbl
}	

function Remove-RegistryValues {
    <#
    .SYNOPSIS
        Remove registry values for specified key.
    .DESCRIPTION
        Remove registry value with the specified values. If Key exists, remove 
        registry value depending on whether value exists. 
    .Parameter Key
        Specified registry key name.
    .Parameter Values
        Specified the values to be deleted.
    .Example 
        Remove-RegistryValues -Key "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Values @('DefaultDomainName')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string] 
        $Key,
        
        [Parameter(Mandatory=$true)]
        [string[]]
        $Values
    )

    if (-not (Test-Path $Key))
    {
        throw "ERROR:The registry key='$Key' does not exist."
    }
    Write-Verbose "Found registry key='$Key'."
    
    if([string]::IsNullOrEmpty($Values))
    {
        throw "ERROR:The parameter Values cannot be empty."
    }

    # Loop through Values to delete it if the value exists
    $Values | % {
        #If the registry exists then delete it, otherwise skip and give an info
        if (Get-ItemProperty -Path $Key -Name $_ -ErrorAction SilentlyContinue)
        {
            Remove-ItemProperty -Path $Key -Name $_
            Write-Verbose "Succeed to remove the registry $($_)."
        }
        else
        {
            Write-Verbose "The registry $($_) does not exist."
        }
    }
}

function Test-RegistryValues {
    <#
    .SYNOPSIS
        Test if registry value for specified key is as expected.
    .DESCRIPTION
        True if registry entry value is as expected, False otherwise. 
    .Parameter Key
        Specify registry key name.
    .Parameter Entry
        Specify entry to check
    .Parameter Type
        Specify type of the entry
    .Parameter ExpectedValue
        Specify expected value of the entry
    .Parameter Contains
        Specify if ExpectedValue should be contained, not full match
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $Key,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $Entry,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string] $ExpectedValue,
        [Parameter(Mandatory=$false)][switch] $Contains
    )

    $ExpectedValue = $ExpectedValue.trim()

    # Get the specific entry
    $regPairs = Get-RegistryValues -Key $Key -ValueName $Entry

    # Check entry value
    foreach ($entryName in $regPairs.Keys)
    {
        $entryValue = $regPairs.$entryName

        if ($Contains)
        {
            if ($entryValue.Contains($ExpectedValue))
            {
                Write-Verbose "Value of $Key\$Entry is $entryValue"
                Exit 0
            }
            else
            {
                Write-Verbose "Actual value of $Key\$Entry is $entryValue while expecting $ExpectedValue!"
                Exit 1
            }
        }
        else 
        {
            if ($entryValue -eq $ExpectedValue)
            {
                Write-Verbose "Value of $Key\$Entry is $ExpectedValue"
                Exit 0
            }
            else
            {
                Write-Verbose "Actual value of $Key\$Entry is $entryValue while expecting $ExpectedValue!"
                Exit 1
            }
        }
    }
}

Export-ModuleMember Set-RegistryValues, Get-RegistryValues, Remove-RegistryValues, Test-RegistryValues