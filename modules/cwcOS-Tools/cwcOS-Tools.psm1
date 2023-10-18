<#
.SYNOPSIS
    This module file contains Windows Operating Systems functions.

    Copyright (c) Citrix Systems, Inc. All Rights Reserved.
.DESCRIPTION
    This module file includes all general functions related to operating
	systems. For example, local	group member, autoadmin logon, account 
	conversion, credential, time synchronization, IP resolution and other
	routine functions. 
#>
Set-StrictMode -Version 2
$ErrorActionPreference = "Stop"

function Test-OSPlatform {
	<#
	.Synopsis
		Check whether operating system platform of local computer matches the string to be queried. 
    .Description
        When the operating system platform of local computer matches the string to be queried, return TRUE.
        Otherwise, return FALSE.	
	.Parameter Platform
		Specified the operating system platform to be queried.
	.Example
		Test-OSPlatform -Platform 'XP'
	#>	    
    [CmdletBinding()]
    param(
		[Parameter(Mandatory=$True)][string]$Platform 
    )
    $os = (Get-WmiObject win32_operatingsystem).Caption
    if(-not $os)
    {
        Write-Verbose "ERROR: Failed to get operating system information."
        return $false
    }
    
    if($os -match $Platform)
    {
        Write-Verbose "The OS of local computer is '$os'. Matched with '$Platform'! "
        return $true
    }
    
    Write-Verbose "The OS of local computer is '$os'. Unmatched with '$Platform'! "
    return $false
}

function ConvertTo-Credential {
	<#
	.Synopsis
		Converts user account and password info to PSCredential.
	.Description
		Converts password from plain text to security srting, then combine it with user account
		info to build PSCredential.
	.Parameter User
		Specified user account.
	.Parameter Password
		Specified user password.      
	.Example
		ConverTo-Credential -User "testdc/user1" -Password "abc123~"
	#>	
	[CmdletBinding()]
	param(
		[parameter(mandatory=$true)][string]$User, 
		[parameter(mandatory=$true)][string]$Password
	)
	Write-Verbose "Creating credential for user:'$User'."
	$securityPassword = ConvertTo-SecureString -Force -AsPlainText $Password
	$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $securityPassword
	
	return $credential
}

function Set-HostName {
    <#
    .Synopsis
        Renames the computer
    .Description
        Uses WMI to rename a computer using the specified hostname. Does not reboot!
    .Parameter HostName
		Specified hostname
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$HostName
    )
    $computerObj = Get-WmiObject Win32_ComputerSystem
    if ($computerObj.Name.ToLower() -ne $HostName.ToLower()) {
        $result = $computerObj.rename($HostName)
        if ($result.ReturnValue -ne 0) {
            throw "Failed to rename computer. Error code $($result.ReturnValue)"
        }
        else {
            Write-Output "Renamed computer $HostName"
        }
    } else {
        Write-Output "Computer is already named $HostName (continuing)"
    }
}

function Download-File {
    <#
    .SYNOPSIS
    Download a file from the specified location 

    .DESCRIPTION
    Download a file from the specified location to the specified destination folder. 

    .PARAMETER FileName
    The name of the file to retrieve

    .PARAMETER Path
    The location to copy the file from. This may be 
        An HTTP(S) URL (e.g. https://example.com/downloads), 
        A UNC share (e.g. \\computer\downloads) or
        A simple file system path (e.g. D:\downloads)

    .PARAMETER ToFolder
    Destination folder for the file.

    .OUTPUT
    On success the script returns the local path of the downloaded file.

    #>
    [CmdletBinding()]
	param(
        [parameter(mandatory=$true)][string]$FileName,
        [parameter(mandatory=$true)][string]$Path,
        [parameter(mandatory=$false)][string]$ToFolder = "$Env:Temp"
    )

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    for($i=1;$i -le 10; $i++)
    {
        try {
            if (-not (Test-Path $ToFolder)) {
                New-Item -Path $ToFolder -ItemType Directory | Out-Null
            }  
            if ($ToFolder -eq ".") {
                $ToFolder = Get-Location
            }
            $localFile = Join-Path "$ToFolder" "$FileName"

            if ($Path -match "^https?://\w+") {
                # "Web URL"
                $Url = "$Path/$FileName"
                $client = New-Object System.Net.WebClient
                $client.DownloadFile($url, $localFile)
            } elseif (($Path -match "^\\\\\w+") -or ($Path -match "^[C-Z]:\\\w+\\")) {
                # "Local copy"
                write-verbose "Path $Path\$FileName Destination $ToFolder"
                Copy-Item -Path "$Path\$FileName" -Destination $ToFolder
            } else {
                write-host $Path " isn't support"
                break
            }
            return $localFile
        } catch {
            write-host "Download file from $path failed , sleep 10 seconds and retry "
            $error[0]
            write-host ""
            Start-Sleep -s 10
        }
    }
}

function Mount-Iso{
<#
.SYNOPSIS
	If Windows > 8, will use Mount-DiskImage API
.PARAMETER isoPath
	Path to the iso file to mount
.PARAMETER mountPoint
	(Optional) local folder to mount to. If omitted, the iso will only be loaded as a new drive.
	If supplied, the folder must exist (and be empty) and then the iso contents will then also 
	be visible there in the local filesystem.
.RETURNS
	The drive letter (randomly assigned from free letters).
#>
[cmdletbinding()]
Param([string]$IsoPath,
	  [string]$Mountpoint = "" # without any trailing \
	 )
					
	if ( -not (Test-Path $IsoPath)) { 
		throw "$IsoPath does not exist" 
	}
	if ($(Test-Windows8orGreater)) {
		Write-Host "Mounting $IsoPath using powershell (Server2012)"
		if (-not ([string]::isnullorempty($Mountpoint))) {
			Write-Warning "Mount-point: '$Mountpoint' will be ignored - unsupported option."
		}
        If ((Get-DiskImage -ImagePath "$IsoPath" | Get-Volume) -isnot [Object]) {
		    Mount-DiskImage -ImagePath $IsoPath
		    $driveLetter = (Get-DiskImage $IsoPath | Get-Volume).DriveLetter
		    return ($driveLetter + ":\")
        } Else {
			Write-Verbose "Image already mounted" 
            $driveLetter = (Get-DiskImage $IsoPath | Get-Volume).DriveLetter
            return ($driveLetter + ":\")
		}
	}
	else {
        Throw "OS is not Win8 or greater unable to mount"
	}
}

Function Dismount-Iso {
<#
.SYNOPSIS
	Unmount a mount point. If Windows > 8, will use Mount-DiskImage API
.PARAMETER driveLetter
	The mount point path. (Drive letter if windows > 8). 
	If the mount point is provided, use -ismountpoint. The drive letter 
	then gets resolved by the function first before un-mounting.
.RETURNS
	The drive letter (randomly assigned from free letters).
#>
[cmdletbinding()]
Param([string] $DriveLetter
	)
	
	write-host '...' -nonewline
	start-sleep -s 5
	 
	if ($(Test-Windows8orGreater)) {
		Write-Host "Unmounting $DriveLetter using powershell"
		Get-Volume ($DriveLetter.Replace(":\","")) | Get-DiskImage | Dismount-DiskImage
	}
	else {
		Throw "OS is not Win8 or greater unable to unmount"
	}
}

function Test-Windows8orGreater {
<#
.SYNOPSIS
	Internal method, if Windows <8 or < 2012, will return $false
#>

	$osVersion = [Environment]::OSVersion.Version
	return $osVersion -ge (new-object 'Version' 6,2)
}

function Unzip-File { 
 
    <# 
    .SYNOPSIS 
        Unzip-File is a function which extracts the contents of a zip file. 
 
    .DESCRIPTION 
        Unzip-File is a function which extracts the contents of a zip file specified via the -File parameter to the 
    location specified via the -Destination parameter. This function first checks to see if the .NET Framework 4.5 
    is installed and uses it for the unzipping process, otherwise COM is used. 
 
    .PARAMETER File 
        The complete path and name of the zip file in this format: C:\zipfiles\myzipfile.zip  
  
    .PARAMETER Destination 
        The destination folder to extract the contents of the zip file to. If a path is no specified, the current path 
    is used. 
 
    .PARAMETER ForceCOM 
        Switch parameter to force the use of COM for the extraction even if the .NET Framework 4.5 is present. 

    .PARAMETER Overwrite 
        Switch parameter to force overwriting files that already exists, only is applicable to .Net Framework extractions 
 
    .EXAMPLE 
        Unzip-File -File C:\zipfiles\AdventureWorks2012_Database.zip -Destination C:\databases\ 
 
    .EXAMPLE 
        Unzip-File -File C:\zipfiles\AdventureWorks2012_Database.zip -Destination C:\databases\ -ForceCOM 
 
    .EXAMPLE 
        'C:\zipfiles\AdventureWorks2012_Database.zip' | Unzip-File 
 
    .EXAMPLE 
        Get-ChildItem -Path C:\zipfiles | ForEach-Object {$_.fullname | Unzip-File -Destination C:\databases} 
 
    .INPUTS 
        String 
 
    .OUTPUTS 
        None 
 
    .NOTES 
        Author:  Mike F Robbins 
        Website: http://mikefrobbins.com 
        Twitter: @mikefrobbins 
 
    #> 
 
    [CmdletBinding()] 
    param ( 
        [Parameter(Mandatory=$true,  
                   ValueFromPipeline=$true)] 
        [ValidateScript({ 
            If ((Test-Path -Path $_ -PathType Leaf) -and ($_ -like "*.zip")) { 
                $true 
            } 
            else { 
                Throw "$_ is not a valid zip file. Enter in 'c:\folder\file.zip' format" 
            } 
        })] 
        [string]$File, 
 
        [ValidateNotNullOrEmpty()] 
        [ValidateScript({ 
            If (Test-Path -Path $_ -PathType Container) { 
                $true 
            } 
            else { 
                Throw "$_ is not a valid destination folder. Enter in 'c:\destination' format" 
            } 
        })] 
        [string]$Destination = (Get-Location).Path, 
 
        [bool]$ForceCOM,
        [switch]$Overwrite
    ) 
 
 
    If (-not $ForceCOM -and ($PSVersionTable.PSVersion.Major -ge 3) -and 
       ((Get-ItemProperty -Path "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Version -like "4.5*" -or 
       (Get-ItemProperty -Path "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Client" -ErrorAction SilentlyContinue).Version -like "4.5*")) { 
 
        Write-Verbose -Message "Attempting to Unzip $File to location $Destination using .NET 4.5" 
 
        if (!$Overwrite) {
            try { 
                [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null 
                [System.IO.Compression.ZipFile]::ExtractToDirectory("$File", "$Destination") 
            }
            catch { 
                Write-Warning -Message "Unexpected Error. Error details: $_.Exception.Message" 
            }
        }
        else {
            Write-Verbose -Message "Attempting to Unzip $File to location $Destination using .NET 4.5 with Overwrite"  
            # Load the required assembly.
            Add-Type -AssemblyName System.IO.Compression.FileSystem

            # Open the specified zip file.
            $zip = [System.IO.Compression.ZipFile]::OpenRead($File)
            
            # Loop through each item contained in the zip file.
            foreach ($item in $zip.Entries) {

                # Attempt to unzip the file. If a file with the same name already exists, overwrite it
                try {
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($item,(Join-Path -Path $Destination -ChildPath $item.FullName),$true)
                } catch {
                    Write-Warning -Message "Unexpected Error. Error details: $_.Exception.Message" 
                }
            }
        }
 
 
    } 
    else { 
 
        Write-Verbose -Message "Attempting to Unzip $File to location $Destination using COM" 
 
        try { 
            $shell = New-Object -ComObject Shell.Application 
            $shell.Namespace($destination).copyhere(($shell.NameSpace($file)).items()) 
        } 
        catch { 
            Write-Warning -Message "Unexpected Error. Error details: $_.Exception.Message" 
        } 
 
    } 
 
}

function Test-LocalGroupMember {
	<#
	.Synopsis
		Determins whether the user is a member of specific local group.
	.Description
		If the user is a local group member, return TRUE. Otherwise, return FALSE. 
	.Parameter Group
		Specified the local group name to which the user is added.
	.Parameter User
		Specified the user to be added to the local group.		
	.Example
		Test-LocalGroupMember -Group 'Remote Desktop Users' -User 'Kevin'
	#>		
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)][string]$Group,
		[Parameter(Mandatory=$true)][string]$User
	)
	trap {
		Write-Verbose "$($MyInvocation.InvocationName) Error: $($_.ToString())."
	}	
	
	# Assign stdout to $res, while using trap to capture error message. 
	$res = net localgroup $Group 2>&1
	if($res -contains "$User")
	{
		Write-Verbose "User:'$User' already in Group:'$Group'."
		return $true
	}
	
	if($res -contains "Everyone")
	{
		Write-Verbose "Everyone is in Group:'$Group'"
		return $true
	}	
	
	Write-Verbose "User:'$User' is not in Group:'$Group'."
	return $false	
}

function Add-LocalGroupMember {
	<#
	.Synopsis
		Adds the user to a local group.
	.Description
		When the user is a member of the specific local group, skip it. 
		Otherwise, add the user to the local group.   		
	.Parameter Group
		Specified the local group name to which the user is added.
	.Parameter User
		Specified the user to be added to the local group.		
	.Example
		Add-LocalGroupMember -Group 'Remote Desktop Users' -User 'Kevin'
	#>		
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)][string]$Group,
		[Parameter(Mandatory=$true)][string]$User
	)
	trap {
		Write-Verbose "$($MyInvocation.InvocationName) Error: $($_.ToString())."
	}
	
	if(cwcOS-Tools\Test-LocalGroupMember -Group $Group -User $User)
	{
		Write-Verbose "Already in Group:'$Group'. Skipping."
		return
	}
	
	# Assign stdout to $res, while using trap to capture error message. 
	$res = net localgroup $Group $User /Add 2>&1
	Write-Verbose "$res."
}

function Add-SMBShare {
<#
.SYNOPSIS
    Creates an SMB file share  
.DESCRIPTION
    Creates an SMB file share  
.Parameter SharePath
    Local path for the share 
.Parameter ShareName
    Name of the share

.EXAMPLE
    Add-SMBShare -SharePath 'L:\Shares' -ShareName 'SCVMMLibrary'
#>
	[CmdletBinding()]
	param (
        [Parameter(Mandatory=$true)] [string] $SharePath,
		[Parameter(Mandatory=$true)] [string] $ShareName,
		[Parameter(Mandatory=$false)] [string] $Access
    )

    if (test-path $SharePath) {
	    $share = New-SmbShare –Name $ShareName –Path $SharePath -FullAccess $Access
        return $share
    } else {
        write-verbose "$SharePath not found"
    }
}

function Get-ProcessorArchitecture {
    <#
    .SYNOPSIS
        Get the processor architecture (x86 or x64) of the machine.

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Get the processor architecture (x86 or x64) of the machine vm guest / physical host.
        
        This uses Win32_Processor to ensure compatability with Windows XP -> Windows 8.
        * Gracefully handles multiple CPU / VCPUs.
        * Win32_Processor -> AddressWidth is not virtualized.
    .OUTPUTS
        x86 or x64
    .LINK
        http://msdn.microsoft.com/en-us/library/windows/desktop/aa394373(v=vs.85).aspx
    #>
    [CmdletBinding()]
    param( # forces exception where a caller inadvertedly assumes parameters
    )
    switch (@(Get-WmiObject Win32_Processor)[0].AddressWidth) {
        64 {
            Write-Output "x64"
            return
        } 
        32 {
            Write-Output "x86"
            return
        }
    }
    # in the event of an unrecognised architecture dump information 
    # for analysis and throw processor not recognized exception.
    Get-WmiObject Win32_Processor | fl
    Throw "Processor architecture not recognized."
}


function Test-Processor32Bit {
    <#
    .SYNOPSIS
        Validates the processor bitness is 32-bit.

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Calls the get the processor architecture function (x86 or x64) of the 
        machine vm guest / physical host and returns true if the bitness is 32-bit.
    .OUTPUTS
        True if 32-bit
        False if not
    .LINK
        http://msdn.microsoft.com/en-us/library/windows/desktop/aa394373(v=vs.85).aspx
    #>    
    (Get-ProcessorArchitecture) -eq "x86"
}
function Test-Processor64Bit {
    <#
    .SYNOPSIS
        Validates the processor bitness is 64-bit.

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Calls the get the processor architecture function (x86 or x64) of the 
        machine vm guest / physical host and returns true if the bitness is 64-bit.
    .OUTPUTS
        True if 64-bit
        False if not
    .LINK
        http://msdn.microsoft.com/en-us/library/windows/desktop/aa394373(v=vs.85).aspx
    #>
    (Get-ProcessorArchitecture) -eq "x64"
}


Export-ModuleMember Test-OSPlatform
Export-ModuleMember ConvertTo-Credential, Set-HostName
Export-ModuleMember Download-File, Mount-Iso, Dismount-Iso, Test-Windows8orGreater, Unzip-File
Export-ModuleMember Test-LocalGroupMember, Add-LocalGroupMember
Export-ModuleMember Add-SMBShare
Export-ModuleMember Get-ProcessorArchitecture, Test-Processor32Bit, Test-Processor64Bit