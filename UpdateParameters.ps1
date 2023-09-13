<#
 .SYNOPSIS
    PowerBi_Tool 

 .DESCRIPTION
    This script is used to call function defined in .PSM1 file

.PARAMETERS
        
        $checkModule : Used while importing Azure Active direcctory module.
    #>

[CmdletBinding()]  
param(
    [Parameter(Mandatory = $True)][string]$BuildSourcesDirectory,
    [parameter(Mandatory = $true)]$checkModule, 
    [Parameter(Mandatory=$True)]$ClientID,  
    [Parameter(Mandatory=$True)]$ClientSecret, 
    [Parameter(Mandatory=$True)]$TenantId, 
    [Parameter(Mandatory=$True)]$workspacename,
    [Parameter(Mandatory=$True)]$authority,
    [Parameter(Mandatory=$True)]$resourceAppID,
    [Parameter(Mandatory=$True)]$Admin_user_PowerBI,
    [Parameter(Mandatory=$True)]$Admin_password_PowerBI,
    [Parameter(Mandatory=$True)]$dataset_input,
    [Parameter(Mandatory=$True)]$api_URL,
    [Parameter(Mandatory=$false)]$datasource_Type,
    [Parameter(Mandatory=$false)]$spName,
    [Parameter(Mandatory=$false)]$spValue,
    [Parameter(Mandatory=$false)]$cDSName,
    [Parameter(Mandatory=$false)]$cDSValue,
    [Parameter(Mandatory=$false)]$oDataName,
    [Parameter(Mandatory=$false)]$oDataUrl
    
)

Write-Host "Path of Release Directory :$BuildSourcesDirectory."
# Importing UserCreationProcess.psm1 module.
Import-Module "$BuildSourcesDirectory"
Write-Host "Importing Module :$checkModule."
# Importing Module ie. Active Directory .
ModuleToImport -checkModule $checkModule

#Get Refresh history of PowerBI Report(pbix) 
Update_Parameter -ClientID $ClientID -ClientSecret $ClientSecret -TenantId $TenantId -workspacename $workspacename -authority $authority -resourceAppID $resourceAppID -Admin_user_PowerBI $Admin_user_PowerBI -Admin_password_PowerBI $Admin_password_PowerBI -dataset_input $dataset_input -api_URL $api_URL -datasource_Type $datasource_Type -spName $spName -spValue $spValue -cDSName $cDSName -cDSValue $cDSValue -oDataName $oDataName -oDataUrl $oDataUrl
