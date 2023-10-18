<#
.SYNOPSIS
    This module file contains functions for handling network interfaces

    Copyright (c) Citrix Systems, Inc. All Rights Reserved.
.DESCRIPTION
    This module file contains functions for handling network interfaces, for example changing interfaces from dhcp to static, etc
#>
Set-StrictMode -Version latest

function Get-IP-Setting {
<#
.SYNOPSIS
	Detects whether current interface setting is DHCP or static
.EXAMPLE
	Add-DC -Domain $Domain -DomainCred $DomainCred
.Parameter Domain
	Name of the domain the DC is being added to
.Parameter DomainCred
	Credentials for the domain
#>
$dhcpSetting = (Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "ipenabled = true").DHCPEnabled
If ($dhcpSetting -match "True")
    {
    Write-Host "DHCP Detected" -background red
    }
    else
    {
    Write-Host "Static IP, check complete" -background darkgreen
    }
}

function Set-IPv4-Static {
<#
.SYNOPSIS
	Change an IPV4 interface to static IP
.EXAMPLE
	Set-IPv4-Static -newIPv4address 192.168.1.2 -prefixlength 22 -currentAddressFamily IPv4 -defaultGateway 192.168.1.1
	Set-IPv4-Static -newIPv4address $newIPv4address -prefixLength $prefixLength -currentAddressFamily $currentAddressFamily -defaultGateway $defaultGateway
.Parameter newIPv4Address
	New IPv4 address for the server
.Parameter prefixLength
	subnet bitness
.Parameter currentAddressFamily
	IPv4 or IPv6
.Parameter defaultGateway
	Default gateway
#>
[CmdletBinding()]
     param (
        [Parameter(Mandatory=$true)] [string]$newIPv4Address,
        [Parameter(Mandatory=$true)] [string]$prefixLength,
        [Parameter(Mandatory=$true)] [string]$currentAddressFamily,
        [Parameter(Mandatory=$true)] [string]$defaultGateway
    )
#Find active IPv4 interface
$interfaces = Get-NetIPInterface -Dhcp Enabled -ConnectionState Connected -AddressFamily IPv4
#Get current IP settings
$ipConfiguration = Get-NetIPConfiguration -InterfaceIndex $interfaces.InterfaceIndex
$ipAddress = $ipConfiguration.IPV4Address
#Throw exception for self-assigned DHCP address, otherwise seta static IP
if ($ipAddress.IPAddress -like '169.254.*') {
	Write-Host "Self assigned IP detected, is this expected?"
	}
    $currentIPAddress = $ipAddress.IPAddress
	#Remove DHCP IP from interface
	Get-NetIPAddress -IPAddress $currentIPAddress | Remove-NetIPAddress -Confirm:$false
	$parameters = @{
		InterfaceIndex = $interfaces.InterfaceIndex
        IPAddress = $newIPv4Address
        PrefixLength = $prefixLength
        AddressFamily = $currentAddressFamily
	}
	if ($defaultGateway -ne $null) {
        $parameters.Add("DefaultGateway",$defaultGateway)
    }
	Write-host "IP Settings $currentAddressFamily" -background darkgreen
	Write-Host $newIPv4Address -background blue
	Write-Host $prefixLength -background blue
	#And finally set the static IP
	New-NetIPAddress @parameters | Out-Null
}

function Set-IPv6-Static {
<#
.SYNOPSIS
	Change an IPV6 interface to static IP
.EXAMPLE
	Set-IPv6-Static -newIPv4address 2001:db8:c0a8:d700::1 -prefixlength 22 -currentAddressFamily IPv6 -defaultGateway 192.168.1.1
	Set-IPv6-Static -newIPv4address $newIPv4address -prefixLength $prefixLength -currentAddressFamily $currentAddressFamily -defaultGateway $defaultGateway
.Parameter newIPv4Address
	New IPv6 address for the server
.Parameter prefixLength
	subnet bitness
.Parameter currentAddressFamily
	IPv4 or IPv6
.Parameter defaultGateway
	Default gateway
#>
[CmdletBinding()]
     param (
        [Parameter(Mandatory=$true)] [string]$newIPv6Address,
        [Parameter(Mandatory=$true)] [string]$prefixLength,
        [Parameter(Mandatory=$true)] [string]$currentAddressFamily,
        [Parameter(Mandatory=$true)] [string]$defaultGateway
    )
#Find active IPv4 interface
$interfaces = Get-NetIPInterface -Dhcp Enabled -ConnectionState Connected -AddressFamily IPv6
#Get current IP settings
$ipConfiguration = Get-NetIPConfiguration -InterfaceIndex $interfaces.InterfaceIndex
$ipAddress = $ipConfiguration.IPV4Address
#Throw exception for self-assigned DHCP address
if ($ipAddress.IPAddress -like 'fe80::*') {
	Throw "Self assigned DHCP detected, check network."
	}
    $currentIPAddress = $ipAddress.IPAddress
	#Remove DHCP IP from interface
	Get-NetIPAddress -IPAddress $currentIPAddress | Remove-NetIPAddress -Confirm:$false
	$parameters = @{
		InterfaceIndex = $interfaces.InterfaceIndex
        IPAddress = $newIPv6Address
        PrefixLength = $prefixLength
        AddressFamily = $currentAddressFamily
	}
	if ($defaultGateway -ne $null) {
        $parameters.Add("DefaultGateway",$defaultGateway)
    }
	Write-host "IP Settings $currentAddressFamily" -background darkgreen
	Write-Host $newIPv6Address -background blue
	Write-Host $prefixLength -background blue
	#And finally set the static IP
	New-NetIPAddress @parameters | Out-Null
}

Export-ModuleMember Get-IP-Setting,Set-IPv4-Static,Set-IPv6-Static