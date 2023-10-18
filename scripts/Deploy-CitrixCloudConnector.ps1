[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [String] $CtxCustomerId, 

    [Parameter(Mandatory=$true)]
    [String] $CtxClientID,

    [Parameter(Mandatory=$true)]
    [String] $CtxClientSecret,

    [Parameter(Mandatory=$false)]
    [string] $CtxResourceLocationName = "AWS-QuickStart"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Function New-BearerAuthenticationToken {
    Param (
        [Parameter(Mandatory=$True)]
        [string]
        $ClientID,
        [Parameter(Mandatory=$True)]
        [string]
        $ClientSecret
    )
   
    $postHeaders = @{"Content-Type"="application/json"}
    $body = @{
      "ClientId"=$clientId;
      "ClientSecret"=$clientSecret
    }
    $trustUrl = "https://trust.citrixworkspacesapi.net/root/tokens/clients"
   
    $response = Invoke-RestMethod -Uri $trustUrl -Method POST -Body (ConvertTo-Json $body) -Headers $postHeaders
    $bearerToken = $response.token
   
    return $bearerToken;
   
   }

Function Get-ResourceLocation {
Param (
    [Parameter(Mandatory=$true)]
    [string] $customerId,
    [Parameter(Mandatory=$true)]
    [string] $bearerToken
)

$requestUri = [string]::Format("https://registry.citrixworkspacesapi.net/{0}/resourcelocations", $customerId)
$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
    "Authorization" = "CWSAuth bearer=$bearerToken"
}


$response = Invoke-RestMethod -Uri $requestUri -Method GET -Headers $headers

return $response.items;
}

try {

    Start-Transcript -Path C:\cfn\log\Deploy-CitrixCloudConnector.ps1.txt -Append    

    # Error handling
    $Global:ErrorActionPreference = "Stop";

    # Check domain membership for CCC server (required)
    Write-Host "Checking domain membership of current machine"
    If (-not $(Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
        Throw "Citrix Cloud Connector machine must be member of Active Directory domain, aborting"
    }

    # Check if user is administrator
    Write-Host "Checking permissions"
    If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Throw "You must be administrator in order to execute this script, aborting"
    }

    # Get bearer authentication token
    Write-Host "Generating new authentication token";
    $CtxAuthToken = New-BearerAuthenticationToken -ClientID $CtxClientId -ClientSecret $CtxClientSecret;

    For ($m_Counter = 0; $m_Counter -lt 5; $m_Counter++) {
        # Get Resource Location ID
        Write-Host "Get Resource Location ID from Citrix Cloud";
        $CtxResourceLocationId = Get-ResourceLocation -customerId $CtxCustomerId -bearerToken $CtxAuthToken | Where-Object {$_.name -eq $CtxResourceLocationName} | Select-Object -First 1 -ExpandProperty "id";

        # Validate that Resource Location ID has been retrieved
        If ($CtxResourceLocationId -isnot [String]) {
            Write-Host "Resource location $CtxResourceLocationName is not available, waiting for 5 minutes"
            Start-Sleep -Seconds 60;
        } Else {
            Write-Host "Resource location $CtxResourceLocationName has been retrieved successfully"; 
            Break; 
        }
    }

    # Validate that Resource Location ID has been retrieved
    If ($CtxResourceLocationId -isnot [String]) {
        Throw "Not able to retrieve resource location with name $CtxResourceLocationName, aborting"
    }

    # Download Citrix Cloud Connector from Citrix Cloud
    Write-Host "Downloading Citrix Cloud Connector installer";
    $m_CCCTempFile = $(New-TemporaryFile).FullName + ".exe";
    $m_CCCURL = "https://downloads.cloud.com/$CtxCustomerId/connector/cwcconnector.exe";
    (New-Object System.Net.WebClient).DownloadFile($m_CCCURL, $m_CCCTempFile);

    # Install Citrix Cloud Connector
    Write-Host "Installing Citrix Cloud Connector";
    $m_CCCCmdArgs = "/q /CustomerName:$CtxCustomerId /ClientId:$CtxClientID /ClientSecret:$CtxClientSecret /Location:$CtxResourceLocationId /AcceptTermsOfService:true";
    $m_ErrorLevel = Start-Process -FilePath $m_CCCTempFile -ArgumentList $m_CCCCmdArgs -Wait -PassThru;

    # Check errorlevel returned by installation. If installation fails, more details can be found in %LOCALAPPDATA%\Temp\CitrixLogs\CloudServicesSetup
    If ($m_ErrorLevel.ExitCode -ne 0) {
        Throw "Installation of Citrix Cloud Connector failed with errorcode $($m_ErrorLevel.ExitCode), aborting"; 
    }

    # Delete installer
    Write-Host "Cleaning up after installation"
    Remove-Item $m_CCCTempFile
}
catch {
        $_ | Write-AWSQuickStartException
    }
    