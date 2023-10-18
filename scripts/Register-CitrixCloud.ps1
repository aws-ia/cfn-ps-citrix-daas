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

Function New-ResourceLocation {
    Param (
      [Parameter(Mandatory=$true)]
      [string] $name,
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
    $body = @{
      "name" = $name
    }
  
    $response = Invoke-RestMethod -Uri $requestUri -Method POST -Body (ConvertTo-Json $body) -Headers $headers
  
    return $response;
  }

Function Get-XAXDServiceEntitlement {
    Param (
      [Parameter(Mandatory=$true)]
      [string] $customerId,
      [Parameter(Mandatory=$true)]
      [string] $bearerToken
    )
  
    $requestUri = [string]::Format("https://core.citrixworkspacesapi.net/{0}/serviceStates", $customerId)
    $headers = @{
      "Content-Type" = "application/json"
      "Accept" = "application/json"
      "Authorization" = "CWSAuth bearer=$bearerToken"
    }
  
    $response = Invoke-RestMethod -Uri $requestUri -Method GET -Body (ConvertTo-Json $body) -Headers $headers
  
    return $response.items;
  } 

try {

    Start-Transcript -Path C:\cfn\log\Register-CitrixCloud.ps1.txt -Append    

    # Error handling
    $Global:ErrorActionPreference = "Stop";

    # Check if user is administrator
    Write-Host "Checking permissions"
    If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Throw "You must be administrator in order to execute this script"
    }

    # Get bearer authentication token
    Write-Host "Generating new authentication token";
    $CtxAuthToken = New-BearerAuthenticationToken -ClientID $CtxClientId -ClientSecret $CtxClientSecret;

    # Check if XenApp/XenDesktop Service is available for current account. If it is not, abort, as PowerShell SDK will fail to authenticate. 
    Write-Host "Checking XenApp/XenDesktop Service entitlement"
    $m_XAXDServiceEntitlementState = Get-XAXDServiceEntitlement -customerId $CtxCustomerId -bearerToken $CtxAuthToken | Where-Object {$_.servicename -eq "xendesktop"} | Select-Object -ExpandProperty "state"
    If ($m_XAXDServiceEntitlementState -notin "ProductionTrial", "Production", "PartnerProduction") {
      Throw "Current service entitlement for XenApp/XenDesktop is in state $m_XAXDServiceEntitlementState. This does not allow the use of XenApp/XenDesktop service."
    }

    # TODO: Check if resource location already exists. If not, create a new one. If yes and -Force is specified, remove and recreate it. 

    # Create new resource location
    Write-Host "Creating new Resource Location in Citrix Cloud";
    New-ResourceLocation -name $CtxResourceLocationName -customerId $CtxCustomerId -bearerToken $CtxAuthToken;
  }
catch {
    $_ | Write-AWSQuickStartException
}
