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
    [Parameter(Mandatory=$True)]$path,
    [Parameter(Mandatory=$True)]$conflictaction,  
    [Parameter(Mandatory=$True)]$dataset_input  
)

Write-Host "Path of Release Directory :$BuildSourcesDirectory."
# Importing UserCreationProcess.psm1 module.
Import-Module "$BuildSourcesDirectory"
Write-Host "Importing Module :$checkModule."
# Importing Module ie. Active Directory .
ModuleToImport -checkModule $checkModule

#Upload PowerBI Report(pbix) to PowerBI workspace
New-pbiReport -ClientID $ClientID -ClientSecret $ClientSecret -TenantId $TenantId -workspacename $workspacename -Path $path -ConflictAction $conflictaction -dataset_input $dataset_input
