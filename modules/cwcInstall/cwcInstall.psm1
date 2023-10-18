<#
.SYNOPSIS
    This module file contains single-sourced Generic Installation functions

    Copyright (c) Citrix Systems, Inc. All Rights Reserved.
.DESCRIPTION
    This module file contains single-sourced Generic Installation functions
#>
Set-StrictMode -Version Latest

function Install-MSIOrEXE {
    <#
    .SYNOPSIS
        Install EXE or MSI(from local path, or network path when drive is already mapped) and validate installation.

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Install EXE or MSI(from local path, or network path when drive is already mapped) and validate installation.
    .Parameter installerPath
        Path to the installer (from local path, or network path when drive is already mapped).
        Currently only msi or exe are supported.
    .Parameter installerArgs
        Commandline options to the installer.
        For exe or msi you can pass args as a string[]:
        * In the MSI case msiexec.exe is used as the process and $installerPath inserted at position 0 of the args
    .Parameter expectedExitCode
        The expected exit code returned from installer. This is used to compare with actual return code to determine if installation PASSES.
    .EXAMPLE 
        Install-MSIOrEXE -installerPath X:\XenDesktopVdaSetup.exe -installerArgs @("/Quiet", "/optimize", "/verboselog", "/logpath 'C:\Windows\Temp\Citrix'", "/Components "VDA, PLUGINS", "/NOREBOOT", "/ENABLE_HDX_PORTS")
    .EXAMPLE 
        Install-MSIOrEXE -installerPath C:\CitrixGroupPolicyManagement_x64.msi -installerArgs @("/Q", "/norestart")
        
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)][string] $installerPath,    
        [Parameter(Position=1,Mandatory=$true)][string[]] $installerArgs,
        [Parameter(Position=2,Mandatory=$false)][int[]] $expectedExitCode = @(0),
        [Parameter(Position=3, Mandatory=$false)][switch] $NoNewWindow,
        [Parameter(Position=4, Mandatory=$false)][switch] $Wait = $true
    )
    
    # There is an issue with Powershell module that drive mapped in caller script are not recongized, 
    # Below step is required for Powershell module to be able to recongize the mapped drive
    Get-PSDrive | out-null
    
    Write-Verbose "Installation Args:$($installerArgs)"
    if (-not (Test-Path $installerPath)) {
        throw "Install-MSIOrEXE:Installer path:'$installerPath' doesn't exist"
    }
    
    $ProcessPath = ""
    $extension = (Get-item $installerPath | select extension).extension
    switch ($extension) {
        ".exe" {
            $ProcessPath = $installerPath
            break
        }
        ".msi" {
            # in the MSI case add the MSIExec process name in possition 0 of the args array
            $ProcessPath = "msiexec.exe"
            [System.Collections.ArrayList]$newArgs = ("/i `"$installerPath`"", $installerArgs)
            $installerArgs = $newArgs
            break
        }
        default {
            throw "Install-MSIOrEXE:The installer $installerPath is neither a .exe nor a .msi, not supported"
        }
    }
    
    # start the process
    cwcInstall\doprocess $ProcessPath $installerArgs $expectedExitCode -Wait:$Wait -NoNewWindow:$NoNewWindow
}

function doprocess {
    <#
    .SYNOPSIS
        Wrap process call to provide good debug output and error handling.
    .DESCRIPTON
        Starts a process with supplied args, optionally waits for the process
        to finish to perform exitcode validation.
    .OUTPUTS
        Throws if exitcode fails to meet expected exitcode or returns the process exitcode
        * If -Wait:$false is specified then doprocess returns 0 immediately
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)][string] $ProcessPath,    
        [Parameter(Position=1, Mandatory=$true)][string[]] $ProcessArgs,
        [Parameter(Position=2, Mandatory=$true)][int[]] $ExpectedExitCode,
        [Parameter(Position=3, Mandatory=$false)][switch] $Wait,
        [Parameter(Position=4, Mandatory=$false)][switch] $NoNewWindow
    )
    Write-Verbose "starting process: $ProcessPath" 
    Write-Verbose "process args: $($ProcessArgs)"
    $ProcessArgs | %{
        Write-Verbose "Arg:$_"
    }

    $p = Start-Process -FilePath $ProcessPath -ArgumentList $ProcessArgs -Wait:$wait -PassThru -NoNewWindow:$NoNewWindow -LoadUserProfile
    if(-not $wait)
    {
        # we can't validate process exitcode if we want to quit early
        return 0
    }
    $summary = "Something went wrong process is null..."
    # check if the process started correctly
    if ($p -ne $null) {
        $exitCode = $p.ExitCode
        $summary = "Process:'$ProcessPath' exited:$exitCode [expected:$ExpectedExitCode]"
        Write-Verbose $summary
        Write-Verbose "Process exit time:$($p.ExitTime)"
        if ($ExpectedExitCode -contains $exitCode) {
            return $exitCode
        } 
    }
    throw "FAILED: $summary"
}

function Install-MSP
{
    <#
    .SYNOPSIS
        Install MSP(from local path, or network path when drive is already mapped) and validate installation.

        Copyright (c) Citrix Systems, Inc. All Rights Reserved.
    .DESCRIPTION
        Install MSP(from local path, or network path when drive is already mapped) and validate installation.
    .Parameter installerPath
        Path to the installer (from local path, or network path when drive is already mapped).
    .Parameter installerArgs
        Commandline options to the installer.
        You can pass args as a string[]:
        * Please note that msiexec.exe is used as the process and $installerPath inserted at position 0 of the args
    .Parameter expectedExitCode
        The expected exit code returned from installer. This is used to compare with actual return code to determine if installation PASSES.
    .EXAMPLE 
        Install-MSP -installerPath R:\Patches\XA650W2K8R2X64R04.msp -installerArgs @("/passive", "/norestart", "/log  C:\logs\test.log")
        
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=$true)][string] $installerPath,    
        [Parameter(Position=1,Mandatory=$true)][string[]] $installerArgs,
        [Parameter(Position=2,Mandatory=$false)][int[]] $expectedExitCode = @(0),
        [Parameter(Position=3, Mandatory=$false)][switch] $NoNewWindow,
        [Parameter(Position=4, Mandatory=$false)][switch] $Wait = $true
    )
    
    # There is an issue with Powershell module that drive mapped in caller script are not recongized, 
    # Below step is required for Powershell module to be able to recongize the mapped drive
    Get-PSDrive | out-null
    
    Write-Verbose "Installation Args:$($installerArgs)"
    if (-not (Test-Path $installerPath)) {
        throw "Install-MSP:Installer path:'$installerPath' doesn't exist"
    }
    
    $ProcessPath = ""
    $extension = (Get-item $installerPath | select extension).extension
    if($extension -eq ".msp")
    {
        $ProcessPath = "msiexec.exe"
        [System.Collections.ArrayList]$newArgs = ("/update `"$installerPath`"", $installerArgs)
        $installerArgs = $newArgs
    }
    else
    {
        throw "Install-MSP:The installer $installerPath is not a .msp, not supported"
    }
    
    # start the process
    doprocess $ProcessPath $installerArgs $expectedExitCode -Wait:$Wait -NoNewWindow:$NoNewWindow
}

Export-ModuleMember Install-MSIOrEXE, doprocess, Install-MSP