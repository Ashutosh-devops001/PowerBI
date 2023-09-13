function ModuleToImport 
    {
        param(
        [Parameter(Mandatory=$True)]$checkModule)
        Write-Host "$checkModule" 
        # If module is imported do nothing
        $CheckModule =@($checkModule)
                foreach($Module in $CheckModule)
                {
                    if (Get-Module | Where-Object { $_.Name -eq $Module }) 
                        {
                            write-host "Module $Module is already imported."
                        }
                    else 
                        {      
                            # Importing modules
                            Install-Module -Name $Module -Verbose -Scope CurrentUser -Force                            
                        }
                }        
    }

function SPN_Connection
    {
        param(
        [Parameter(Mandatory=$True)]$ClientID,  
        [Parameter(Mandatory=$True)]$ClientSecret, 
        [Parameter(Mandatory=$True)]$TenantId, 
        [Parameter(Mandatory=$True)]$workspacename)  
        
        $Client_Secreat = $ClientSecret| ConvertTo-SecureString -AsPlainText -Force 
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientID, $Client_Secreat
        #Connect to PowerBI
        Connect-PowerBIServiceAccount -ServicePrincipal -Credential $credential -TenantId "$TenantId"
        # Get PowerBI WorkSpace
        $workspace = Get-PowerBIWorkspace -Name $workspacename 
        Write-Host "Connect to PowerBI workSpace"
        return $workspace
    }

function Get_Token
    {
        param(
        [Parameter(Mandatory=$True)]$ClientID,  
        [Parameter(Mandatory=$True)]$ClientSecret, 
        [Parameter(Mandatory=$True)]$authority,
        [Parameter(Mandatory=$True)]$resourceAppID,
        [Parameter(Mandatory=$True)]$Admin_user_PowerBI,
        [Parameter(Mandatory=$True)]$Admin_password_PowerBI
        )
        
        #-------------------------------------------------------
                    # Get Authentication token
                         Write-Host "token generation is in Progress"
                        $authBody = @{
                            'resource'= $resourceAppID
                            'client_id' = $ClientID
                            'client_secret'= $ClientSecret
                            'grant_type' = 'password'
                            'username' = $Admin_user_PowerBI
                            'password' = $Admin_password_PowerBI
                            }
                         Write-Host "authbody created successfully"
                    #-------------------------------------------------------
                    #Authentiate to Power BI
                        Write-Host "Invoke-RestMethod -Uri $authority -Body $authBody -Method POST"
                        $auth = Invoke-RestMethod -Uri $authority -Body $authBody -Method POST -Verbose
                        $token = $auth.access_token
                        Write-Host "token generated successfully"
                        # Build the API Header with the auth token
                        $authHeader = @{
                            'Content-Type'='application/json'
                            'Authorization'='Bearer ' + $token
                                        }
                        Write-Host "Authentication Header created successfully"
                        return $authHeader

    }

function New-pbiReport
    {
        param(
            [Parameter(Mandatory=$True)]$Path,   
            [Parameter(Mandatory=$True)]$ConflictAction, #Provide file upload option Ignore, Abort, Overwrite, CreateOrOverwrite
            [Parameter(Mandatory=$True)]$ClientID,  
            [Parameter(Mandatory=$True)]$ClientSecret, 
            [Parameter(Mandatory=$True)]$TenantId, 
            [Parameter(Mandatory=$True)]$workspacename,
            [Parameter(Mandatory=$True)]$dataset_input
            )
                try
                    {
                        $ErrorActionPreference = "Stop"
                        $Work_Space = SPN_Connection -ClientID $ClientID -ClientSecret $ClientSecret -TenantId $TenantId -workspacename $Workspacename
                        $Work_Space
                        $items = Get-ChildItem -Path $Path | Where {$_.extension -like ".pbix"}
                        foreach ($Items in $items)
                            {
                            $Dataset_input =@($dataset_input)
                            foreach($datasetinput in $Dataset_input)
                                { 
                                if($datasetinput -eq $Items -or $datasetinput -eq '*' )
                                    {
                                        try
                                            {
                                                Write-Host "Publish Report File to workspace Started : "
                                                $id= New-PowerBIReport -Path $Items.FullName`
                                                                                        -Name $Items.BaseName`
                                                                                                -WorkspaceId $Work_Space.ID -ConflictAction: $ConflictAction | Select -ExpandProperty "Id"
                                        
                            
                                                    Write-Host "Report File : "$($Items.BaseName)" Report ID : $id has been uploaded"
                                            }
                                        catch
                                            {
                                                Write-Warning "Report Upload Error. This script is not overriding the reports.Make sure to delete the existing file in PowerBI workspace, if same report file is trying to upload.." 
                                            }
                                    }
                                    else
                                        {
                                            Write-Warning "Provide report file name as DataSet Input or * in case if all report files needs to published." -ErrorAction Stop
                                            Exit
                                        }
                                } 
                            }
                    }                        
            catch
                {
                    $Error = Resolve-PowerBIError -Last
                    Write-Error "Error encounters $($Error.Message) " -ErrorAction Stop
                }
     
    }

function Delete-pbiReport
    {
        param(
        [Parameter(Mandatory=$True)]$dataset_input)
        
        try
            {
                $Work_Space = SPN_Connection -ClientID $ClientID -ClientSecret $ClientSecret -TenantId $TenantId -workspacename $Workspacename
                    
                $DatasetResponse = Invoke-PowerBIRestMethod -Url "groups/$($Work_Space.ID)/datasets" -Method Get | ConvertFrom-Json
                $datasets = $DatasetResponse.value
                $Dataset_input =@($dataset_input)
                foreach($dataset_input in $Dataset_input)
                    { 
                    foreach($dataset in $datasets)
                        {
                    
                            if($Dataset_input -eq $dataset.Name)
                                {
                                    $datasetid= $dataset.id;
                                    $URL = "groups/$($Work_Space.ID)/datasets/$($datasetid)"
                                    Invoke-PowerBIRestMethod -Url $Url -Method Delete 
                                    Write-Host "Report File : "$($Dataset_input)" has been deleted"
                                }
                           }
                    
                    }
               }
        catch
            {
                $Error = Resolve-PowerBIError -Last
                Write-Error "Error encounters $($Error.Message) " -ErrorAction Stop
            }
    }

function GetRefreshStatus
{
    param(
    [Parameter(Mandatory=$True)]$dataset_input,
    [Parameter(Mandatory=$True)]$api_URL,
    [Parameter(Mandatory=$True)]$ClientID,  
    [Parameter(Mandatory=$True)]$ClientSecret, 
    [Parameter(Mandatory=$True)]$TenantId, 
    [Parameter(Mandatory=$True)]$workspacename,
    [Parameter(Mandatory=$True)]$authority,
    [Parameter(Mandatory=$True)]$resourceAppID,
    [Parameter(Mandatory=$True)]$Admin_user_PowerBI,
    [Parameter(Mandatory=$True)]$Admin_password_PowerBI)

    try
        {
            $Work_Space = SPN_Connection -ClientID $ClientID -ClientSecret $ClientSecret -TenantId $TenantId -workspacename $Workspacename
            $auth_Header = Get_Token -ClientID $ClientID -ClientSecret $ClientSecret -authority $authority -resourceAppID $resourceAppID -Admin_user_PowerBI $Admin_user_PowerBI -Admin_password_PowerBI $Admin_password_PowerBI
            $DatasetResponse = Invoke-PowerBIRestMethod -Url "groups/$($Work_Space.ID)/datasets" -Method Get | ConvertFrom-Json
            $datasets = $DatasetResponse.value
            $Dataset_input =@($dataset_input)
            foreach($datasetinput in $Dataset_input)
                {
                foreach($dataset in $datasets)
                    { 
                    if($datasetinput -eq $dataset.Name)
                        {
                            $dataset_id = $dataset.id
                            
                            Write-Host "Refreshed history of $($dataset.Name) is :"
                            # Check the refresh history   
                            $url_history = "groups/$($Work_Space.ID)/datasets/$($dataset_id)/refreshes"  
                            $refresh_History = Invoke-PowerBIRestMethod -Url $url_history -Method Get
                            $refresh_History  
                                                     
                         }
                    }
                }
            }
        catch
            {
                $Error = Resolve-PowerBIError -Last
                Write-Error "Error encounters $($Error.Message) " -ErrorAction Stop
            }
    }

function RefreshDataSet
    {
    param(
    [Parameter(Mandatory=$True)]$dataset_input,
    [Parameter(Mandatory=$True)]$api_URL,
    [Parameter(Mandatory=$True)]$ClientID,  
    [Parameter(Mandatory=$True)]$ClientSecret, 
    [Parameter(Mandatory=$True)]$TenantId, 
    [Parameter(Mandatory=$True)]$workspacename,
    [Parameter(Mandatory=$True)]$authority,
    [Parameter(Mandatory=$True)]$resourceAppID,
    [Parameter(Mandatory=$True)]$Admin_user_PowerBI,
    [Parameter(Mandatory=$True)]$Admin_password_PowerBI)

    try
        {
            $Work_Space = SPN_Connection -ClientID $ClientID -ClientSecret $ClientSecret -TenantId $TenantId -workspacename $Workspacename
            $auth_Header = Get_Token -ClientID $ClientID -ClientSecret $ClientSecret -authority $authority -resourceAppID $resourceAppID -Admin_user_PowerBI $Admin_user_PowerBI -Admin_password_PowerBI $Admin_password_PowerBI
            $DatasetResponse = Invoke-PowerBIRestMethod -Url "groups/$($Work_Space.ID)/datasets" -Method Get | ConvertFrom-Json
            $datasets = $DatasetResponse.value
            $Dataset_input =@($dataset_input)
            foreach($datasetinput in $Dataset_input)
                {
                foreach($dataset in $datasets)
                    { 
                    if($datasetinput -eq $dataset.Name)
                        {
                            $dataset_id = $dataset.id
                            #Take Over DataSet
                            $url_TakeOver = "$api_URL/groups/$($Work_Space.ID)/datasets/$($dataset_id)/Default.TakeOver"
                            Invoke-RestMethod -Uri $url_TakeOver -Headers $auth_Header -Method Post 
                            Write-Host "DataSet taken Over"
                            # DataSet Refresh
                            $url_Refresh = "$api_URL/groups/$($Work_Space.ID)/datasets/$($dataset_id)/refreshes"
                            Invoke-RestMethod -Uri $url_Refresh -Headers $auth_Header -Method POST -Verbose 
                            Write-Host "DataSet Refreshed"                        
                        }
                    }
                }
            }
        catch
            {
                $Error = Resolve-PowerBIError -Last
                Write-Error "Error encounters $($Error.Message) " -ErrorAction Stop
            }
    }
function UpdateDataSource
    {
    param(
    [Parameter(Mandatory=$True)]$dataset_input,
    [Parameter(Mandatory=$True)]$api_URL,
    [Parameter(Mandatory=$True)]$ClientID,  
    [Parameter(Mandatory=$True)]$ClientSecret, 
    [Parameter(Mandatory=$True)]$TenantId, 
    [Parameter(Mandatory=$True)]$workspacename,
    [Parameter(Mandatory=$True)]$authority,
    [Parameter(Mandatory=$True)]$resourceAppID,
    [Parameter(Mandatory=$True)]$Admin_user_PowerBI,
    [Parameter(Mandatory=$True)]$Admin_password_PowerBI,
    [Parameter(Mandatory=$false)]$oDataUrl,
    [Parameter(Mandatory=$false)]$datasource_Type,
    [Parameter(Mandatory=$false)]$targetServer,
    [Parameter(Mandatory=$false)]$targetDatabase,
    [Parameter(Mandatory=$false)]$originalServer,
    [Parameter(Mandatory=$false)]$originalDatabase,
    [Parameter(Mandatory=$false)]$SharePointurl
    )

    try
        {
            $Work_Space = SPN_Connection -ClientID $ClientID -ClientSecret $ClientSecret -TenantId $TenantId -workspacename $Workspacename
            $auth_Header = Get_Token -ClientID $ClientID -ClientSecret $ClientSecret -authority $authority -resourceAppID $resourceAppID -Admin_user_PowerBI $Admin_user_PowerBI -Admin_password_PowerBI $Admin_password_PowerBI
            Write-Host "Generated Authentication header successfully" 
            $DatasetResponse = Invoke-PowerBIRestMethod -Url "groups/$($Work_Space.ID)/datasets" -Method Get | ConvertFrom-Json
            $datasets = $DatasetResponse.value
            $Dataset_input =@($dataset_input)
            $Dataset_input
            foreach($datasetinput in $Dataset_input)
                {
                foreach($dataset in $datasets)
                    { 
                    if($datasetinput -eq $dataset.Name)
                        {
                            $dataset_id = $dataset.id
                            #Take Over DataSet
                            Write-Host "DataSet is going to take over"
                            $url_TakeOver = "$api_URL/groups/$($Work_Space.ID)/datasets/$dataset_id/Default.TakeOver"
                            $url_TakeOver
                            Write-Host "Invoke-RestMethod -Uri $url_TakeOver -Headers $auth_Header -Method Post "
                            Invoke-RestMethod -Uri $url_TakeOver -Headers $auth_Header -Method Post 
                            Write-Host "DataSet taken Over"
                            $Datasource_Type =@($datasource_Type)
                            foreach($dataset_input in $Datasource_Type)
                            {
                            if ($dataset_input -eq "oData")
                            {
                            $body = @"
{
    "updateDetails": [
    {
        "connectionDetails":  
        {
            "url":  "$($oDataUrl)"
        },
        "datasourceType":  "$($dataset_input)"
    }
  ]
}
"@
}
                    elseif ($dataset_input -eq "SQL" -or $dataset_input -eq "AnalysisServices" )
                    {
$body = @"
{
  "updateDetails":[
    {
      "connectionDetails":
      {
        "server": "$($targetServer)",
        "database": "$($targetDatabase)"
      },
      "datasourceSelector":
      {
        "datasourceType": "$($dataset_input)",
        "connectionDetails":
        {
          "server": "$($originalServer)",
          "database": "$($originalDatabase)"
        }
      }
    }
  ]
}
"@
}
elseif ($dataset_input -eq "SharePoint")
                            {
                            $body = @"
{
    "updateDetails": [
    {
        "connectionDetails":  
        {
            "url":  "$($SharePointurl)"
        },
        "datasourceType":  "$($dataset_input)"
    }
  ]
}
"@
}

                            $URL_UpdateDataSource = "$api_URL/groups/$($Work_Space.ID)/datasets/$($dataset_id)/Default.UpdateDatasources"
                            Write-Host "Updating DataSource : $($datasetinput)"                            
                            Invoke-RestMethod -Uri $URL_UpdateDataSource -Headers $auth_Header -Method Post -Body $body
                            Write-Host "Updated DataSource $($datasetinput)"
                            
                            Write-Host "Updated Datasource details"
                            $url_datasource = "$api_URL/groups/$($Work_Space.ID)/datasets/$($dataset_id)/datasources"
                            $datasources = Invoke-RestMethod -Uri $url_datasource -Headers $auth_Header -Method Get  
                            $datasources.value | ConvertTo-JSON
                           
                            
                            # DataSet Refresh
                            $url_Refresh = "$api_URL/groups/$($Work_Space.ID)/datasets/$($dataset_id)/refreshes"
                            Invoke-RestMethod -Uri $url_Refresh -Headers $auth_Header -Method POST -Verbose  
                            Write-Host "DataSet Refreshed  $($datasetinput)"                 
                        }
                    }
                }
            }
    }
        catch
            {
                $Error = Resolve-PowerBIError -Last
                Write-Error "Error encounters $($Error.Message) " -ErrorAction Stop
            }
    }

function Update_Parameter
    {
    param(
    [Parameter(Mandatory=$True)]$dataset_input,
    [Parameter(Mandatory=$True)]$api_URL,
    [Parameter(Mandatory=$True)]$ClientID,  
    [Parameter(Mandatory=$True)]$ClientSecret, 
    [Parameter(Mandatory=$True)]$TenantId, 
    [Parameter(Mandatory=$True)]$workspacename,
    [Parameter(Mandatory=$True)]$authority,
    [Parameter(Mandatory=$True)]$resourceAppID,
    [Parameter(Mandatory=$True)]$Admin_user_PowerBI,
    [Parameter(Mandatory=$True)]$Admin_password_PowerBI,
    [Parameter(Mandatory=$false)]$datasource_Type,
    [Parameter(Mandatory=$false)]$spName,
    [Parameter(Mandatory=$false)]$spValue,
    [Parameter(Mandatory=$false)]$cDSName,
    [Parameter(Mandatory=$false)]$cDSValue,
    [Parameter(Mandatory=$false)]$oDataName,
    [Parameter(Mandatory=$false)]$oDataUrl
    )

    try
        {
            $Work_Space = SPN_Connection -ClientID $ClientID -ClientSecret $ClientSecret -TenantId $TenantId -workspacename $Workspacename
            $auth_Header = Get_Token -ClientID $ClientID -ClientSecret $ClientSecret -authority $authority -resourceAppID $resourceAppID -Admin_user_PowerBI $Admin_user_PowerBI -Admin_password_PowerBI $Admin_password_PowerBI
            Write-Host "Generated Authentication header successfully" 
            $DatasetResponse = Invoke-PowerBIRestMethod -Url "groups/$($Work_Space.ID)/datasets" -Method Get | ConvertFrom-Json
            
            $datasets = $DatasetResponse.value
            $Dataset_input =@($dataset_input)
            $Dataset_input
            foreach($datasetinput in $Dataset_input)
                {
                foreach($dataset in $datasets)
                    { 
                    if($datasetinput -eq $dataset.Name)
                        {
                            $dataset_id = $dataset.id
                            Write-Host "DataSet is going to take over"
                            $url_TakeOver = "$api_URL/groups/$($Work_Space.ID)/datasets/$dataset_id/Default.TakeOver"
                            $url_TakeOver
                            Invoke-RestMethod -Uri $url_TakeOver -Headers $auth_Header -Method Post 
                            Write-Host "DataSet taken Over"
                            $Datasource_Type =@($datasource_Type)
                            foreach($dataset_input in $Datasource_Type)
                            {
                            $dataset_input
                            if ($dataset_input -eq "SharePoint" )
                    {
$body = @"
{
  "updateDetails": [
    {
      "name": "$($spName)",
      "newValue": "$($spValue)"
    }
  ]
}
"@
}
                elseif ($dataset_input -eq "cds" )
                    {
$body = @"
  {
  "updateDetails": [
    {
      "name": "$($cDSName)",
      "newValue": "$($cDSValue)"
    }
  ]
}
"@
} 
elseif ($dataset_input -eq "oData" )
                    {
$body = @"
  {
  "updateDetails": [
    {
      "name": "$($oDataName)",
      "newValue": "$($oDataUrl)"
    }
  ]
}
"@
} 
                       
                        $URL_UpdateDataSource = "$api_URL/groups/$($Work_Space.ID)/datasets/$($dataset_id)/UpdateParameters"
                        Write-Host "Updating DataSource  $($datasetinput)"   
                        #$URL_UpdateDataSource                   
                        Invoke-RestMethod -Uri $URL_UpdateDataSource -Headers $auth_Header -Method Post -Body $body -Verbose
                        Write-Host "Updated DataSource  $($datasetinput)" 
                        # DataSet Refresh
                        $url_Refresh = "$api_URL/groups/$($Work_Space.ID)/datasets/$($dataset_id)/refreshes"
                        Invoke-RestMethod -Uri $url_Refresh -Headers $auth_Header -Method POST -Verbose  
                        Write-Host "DataSet Refreshed  $($datasetinput)"
                                                  
                        }
                    }
                }
            }
        }
        catch
            {
                $Error = Resolve-PowerBIError -Last
                Write-Error "Error encounters $($Error.Message) " -ErrorAction Stop
            }
    }