
<#
.SYNOPSIS
    This module file contains single-sourced CWC utility functions.

    Copyright (c) Citrix Systems, Inc. All Rights Reserved.
.DESCRIPTION
    This module file contains single-sourced CWC common utility functions.
#> 
Set-StrictMode -Version Latest

function ComputerName-IsFQDN {
    <#
    .SYNOPSIS
        Validates the provided computer name is a FQDN

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Validates the provided computer name is a FQDN and returns true or false
    .Parameter ComputerName
        Computer Name to validate
    .EXAMPLE
        i.e. cwcTools\ComputerName-IsFQDN -ComputerName CTX-XDC-001
        ie.e cwcTools\ComputerName-IsFQDN -ComputerName CTX-XDC-001.2k3.local
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]  [string]$ComputerName
    )
    $NameSplit = $ComputerName.split(".")
    if ($NameSplit.count -ge 2) {
        return $true
    } elseif ($NameSplit.count -eq 1) {
        return $false
    } else {
        throw "Unable to determine if $ComputerName is a FQDN, please verify it is a properly formated windows computer name"
    }
}

function New-FQDN {
    <#
    .SYNOPSIS
        Creates a FQDN from a provided computer name and domain name

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Returns a FQDN from a provided computer name and domain name. If the name is already fully qualified, nothing change is made
    .Parameter ComputerName
        Computer Name to fully qualify
     .Parameter DomainName
        Fully qualified domain name to append
    .EXAMPLE
        i.e. cwcTools\New-FQDN -ComputerName CTX-XDC-001 -DomainName 2k3.local
        ie.e cwcTools\New-FQDN -ComputerName CTX-XDC-001.2k3.local -DomainName 2k3.local
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]  [string]$ComputerName,
        [Parameter(Mandatory=$true)]  [string]$DomainName
    )
    if (cwcTools\ComputerName-IsFQDN -ComputerName $ComputerName) {
        Write-Verbose "$ComputerName is already fully qualified"
        return $ComputerName
    } else {
        Write-Verbose "$ComputerName is not fully qualified"
        return "$ComputerName.$DomainName"
    }
}

function New-UQDN {
    <#
    .SYNOPSIS
        Creates an unqualified domain name (i.e. hostname) from a provided computer name

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Returns a unqualified from a provided computer name. If the name is already unqualified, no changes are made
    .Parameter ComputerName
        Computer Name to fully qualify
    .EXAMPLE
        i.e. cwcTools\New-UQDN -ComputerName CTX-XDC-001
        ie.e cwcTools\New-UQDN -ComputerName CTX-XDC-001.2k3.local
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]  [string]$ComputerName
    )
    if (cwcTools\ComputerName-IsFQDN -ComputerName $ComputerName) {
        Write-Verbose "$ComputerName is fully qualified, unqualifying"
        return $ComputerName.split(".")[0]
    } else {
        Write-Verbose "$ComputerName is already unqualified"
        return "$ComputerName"
    }
}

function New-UQUserName {
    <#
    .SYNOPSIS
        Creates an unqualified user name from a provided user name

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Returns a unqualified user name. If the name is already unqualified, no changes are made
    .Parameter UserName
        Username Name to fully qualify
    .EXAMPLE
        i.e. cwcTools\New-UQDN -UserName administrator
        ie.e cwcTools\New-UQDN -UserName 2k3\administrator
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]  [string]$UserName
    )
    if ($UserName.Contains("@")) {
        Write-Verbose "$UserName is UPN format, unqualifying"
        return $UserName.split("@")[0]
    } elseif ($UserName.Contains("\")) {
        Write-Verbose "$UserName is downlevel format, unqualifying"
        return $UserName.split("\")[1]
    } else {
        Write-Verbose "$UserName is already unqualified"
        return "$UserName"
    }
}

function Get-ScaleX.Extra {
    <#
    .SYNOPSIS
        Get content of scalex.extra file as a hash, fail gracefully (return empty hash) if file does not exist

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Returns a hash of scalex.extra file.
    .EXAMPLE
        i.e. cwcTools\Get-ScaleX.Extra
    #>
    $extra = @{}
    $xtraFile = "../../scalex.extra"
    if (Test-Path $xtraFile) {
        Get-Content -Path $xtraFile | ForEach-Object {if ($_ -match "(.*)=(.*)") { $extra[$matches[1]]=$matches[2]; }}
    }
    return $extra
}

function Adjust-ComputerName {
    <#
    .SYNOPSIS
        Adjust the computer name if this is a multiple server deployment to avoid name clashes

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Uses scalex.extra file to generate a computer name for multi server deployments
    .Parameter ComputerName
        Base name to use for adjusted ComputerName
    .EXAMPLE
        i.e. cwcTools\Adjust-ComputerName -ComputerName CTX-XDC
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]  [string]$ComputerName
    )
    $extra = cwcTools\Get-ScaleX.Extra
    $index = $extra["index"]   
    $instanceCount = $extra["instanceCount"]
    if ((-not [String]::IsNullOrEmpty($index)) -and ($instanceCount -gt 1)) {
        $ComputerName = "${ComputerName}-$index"
    }
    else {
        $ComputerName = "${ComputerName}-1"
    }
    return $ComputerName
}

Export-ModuleMember ComputerName-IsFQDN, New-FQDN, New-UQDN, New-UQUserName
Export-ModuleMember Adjust-ComputerName, Get-ScaleX.Extra