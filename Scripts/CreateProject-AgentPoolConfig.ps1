# ==========================================================
# Custom Project Creation
# --------------------------------------------------
# Goal: Facilitate Project Creation and Update Agent
#         Pool Permissions on the default Project permissions
#         for both existing and new Projects
# --------------------------------------------------
# 1. Retrieve Process Template ID by Name $ProcessTemplate
# 2. Create Project with said Process Template ID and Version Control type ($VersionControl)
#  2.1 If Project already exists, skip to step 5 with the Project ID
# 3. Monitor project creation via the Operations API
# 4. Once created, retrieve the project ID by name
# 5. Update the project's agent pool permissions for all roles to the
#       specified permissions ($PoolDefaultRole)
# ==========================================================
# Known Limitations:
#   - ADO API does not support filtering within the request
#     - filtering must be done after the response is received
# ==========================================================

[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string] $Organization, # = "https://dev.azure.com/my-ado-org",
    [Parameter(Mandatory=$true)]
    [string] $ProjectName, # = "poc-test-delme2",
    [Parameter()]
    [string] $ProjectDescription,
    [ValidateSet("Git","TFVC")]
    [string] $VersionControl = "Git",
    [Parameter()]
    [string] $ProcessTemplate = "Scrum",
    [Parameter()]
    [string] $PoolDefaultRole = "User"
)

$PersonalAccessToken = $Env:PAT

Set-StrictMode -Version Latest
Set-Variable SerializationDepth -Option Constant -Value 100 -ErrorAction SilentlyContinue

Function Invoke-DevOpsAPI
{
[CmdletBinding()]
Param(
    [parameter(Position=0, Mandatory=$true)]
    [string] $Uri,
    [Parameter(Position=1)]
    [string] [ValidateSet('Default','Get', 'Post', 'Put')]
    $Method = 'Get',
    [parameter(Position=2, Mandatory=$true)]
    [string] $PersonalAccessToken,
    [Parameter(Position=3)]
    [object] $Body,
    [Parameter(Position=4)]
    [string] $ContentType
)
    [string] $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$PersonalAccessToken)))

    [hashtable] $AuthHeader = 
    @{ 
        Authorization = "Basic $base64AuthInfo"
    }

    [hashtable] $params =
    @{
        'Uri'= $Uri;
        'Headers'= $AuthHeader;
        'Method'= $Method;
    }

    if (!($null -eq $Body))
    {
        $params += @{'Body' = $Body}
    }
    if (![string]::IsNullOrEmpty($ContentType))
    {
        $params += @{'ContentType' = $ContentType }
    }

    try {
        return Invoke-RestMethod -UseBasicParsing @params        
    }
    catch {
        Write-Error "$($_.Exception.Message)"
        
    }
}

Function GET-ProcessTemplate {
    Param (
        [string] $Organization,    
        [string] $ProcessTemplate,
        [string] $PersonalAccessToken
    )
    # Get a list of process template for a given Organization/Collection
    [string] $Uri = "$Organization/_apis/process/processes"
    $result = Invoke-DevOpsAPI -Uri $Uri -PersonalAccessToken $PersonalAccessToken
    if (($null -eq $result) -or ($result.Count -eq 0)) {
        return $null
    }
    # Loop through the process templates and check by Name
    foreach ($process in $result.Value) {
        if ($process.name -eq $ProcessTemplate) {
            return $process
        }
    }
    # Template not found
    return $null
}

Function GET-ADOProject {
    Param(
        [string] $Organization,    
        [string] $ProjectName,
        [string] $PersonalAccessToken
    )
    # Get a list of projects for a given Organization/Collection
    [string] $Uri = "$Organization/_apis/projects?api-version=6.1-preview.4"
    $result = Invoke-DevOpsAPI -Uri $Uri -PersonalAccessToken $PersonalAccessToken
    if (($null -eq $result) -or ($result.Count -eq 0)) {
        # Write-Host "Could not find projects within org"
        return $null
    }
    # Loop through the projects and check by Name
    foreach ($project in $result.Value) {
        if ($project.name -eq $ProjectName) {
            # Write-Host "Found Project: $ProjectName"
            return $project
        }
    }
    # Project not found
    # Write-Host "Could not find projects within orgs"

    return $null
}

Function New-ADOProject {
    # https://dev.azure.com/{{organization}}/_apis/projects?api-version=6.0
    Param(
        [string] $Organization,    
        [string] $ProjectName,
        [string] $ProjectDescription,
        [string] $VersionControl,
        [string] $TemplateId,
        [string] $PersonalAccessToken
    )
    [string] $Uri = "$Organization/_apis/projects?api-version=6.0"
    [hashtable] $body = @{
        "name" = "$ProjectName"
        "capabilities" = @{ "versioncontrol" = @{ "sourceControlType" = $VersionControl}
                            "processTemplate" = @{ "templateTypeId" = $TemplateId }
        }
        "visibility" = "private"
    }
    if (![string]::IsNullOrEmpty($ProjectDescription)) {
        $body += @{ "description"=$ProjectDescription}
    }
    else {
        $body += @{"description"="Autogenerated by Scrpipt"}
    }
    return Invoke-DevOpsAPI -Uri $Uri -PersonalAccessToken $PersonalAccessToken `
        -Method Post `
        -Body (ConvertTo-Json $body -Depth $SerializationDepth) `
        -ContentType 'application/json'
}

Function Get-ProjectSecurityRoles {
    #   https://dev.azure.com/{{organization}}/_apis/securityroles/scopes/distributedtask.globalagentqueuerole/roleassignments/resources/{{projectId}}?api-version=7.1-preview.1
    Param (
        [string] $Organization,    
        [string] $ProjectId,
        [string] $PersonalAccessToken
    )
    [string] $Uri = "$Organization/_apis/securityroles/scopes/distributedtask.globalagentqueuerole/roleassignments/resources/$($ProjectId)?api-version=7.1-preview.1"

    return Invoke-DevOpsAPI -Uri $Uri -PersonalAccessToken $PersonalAccessToken
}

Function Get-Operation {
    Param (
        [string] $Organization,    
        [string] $OperationId,
        [string] $PersonalAccessToken
    )
    [string] $Uri = "$Organization/_apis/operations/$OperationId"
    return Invoke-DevOpsAPI -Uri $Uri -PersonalAccessToken $PersonalAccessToken
}

Function PUT-AgentPoolRole {
    #https://dev.azure.com/{{organization}}/_apis/securityroles/scopes/distributedtask.globalagentqueuerole/roleassignments/resources/{{roleId}}?api-version=7.1-preview.1
    Param(
        [string] $Organization,    
        [string] $ProjectId,    
        [array] $RoleIds,
        [string] $RoleToAssign,
        [string] $PersonalAccessToken
    )
    [string] $Uri = "$Organization/_apis/securityroles/scopes/distributedtask.globalagentqueuerole/roleassignments/resources/$($ProjectId)?api-version=7.1-preview.1"
    
    $body = @()

    foreach ($role in $RoleIds) {
        $body += @{
            userId = $role
            roleName = $RoleToAssign
        }
    }
    
    return Invoke-DevOpsAPI -Uri $Uri -PersonalAccessToken $PersonalAccessToken `
        -Method Put `
        -Body (ConvertTo-Json $body -Depth $SerializationDepth) `
        -ContentType 'application/json'
}
# ==========================================================
# 1. Retrieve Process Template ID by Name
# ==========================================================
# GET-ADOProject -Organization $Organization -ProjectName 'JinLeeSandbox' -PersonalAccessToken $PersonalAccessToken
# Invoke-RestMethod -Uri "$Organization/_apis/projects?api-version=7.0" -Method get -Headers @{Authorization='Basic ' + [Convert]::ToBase64string([Text.Encoding]::ASCII.GetBytes("$PersonalAccessToken"))}

# Find Process Template by Name
$template = GET-ProcessTemplate -Organization $Organization -ProcessTemplate $ProcessTemplate -PersonalAccessToken $PersonalAccessToken
if ($null -eq $template) {
    Write-Host -ForegroundColor Red "Template '$ProcessTemplate' not found in '$Organization'"
    exit 1
}
# ==========================================================
# 2. If Project not exists, create Project with said Process Template ID
#      Otherwise, retrieve Project ID
# ==========================================================
# Check if Projects already exists
$project = GET-ADOProject -Organization $Organization -ProjectName $ProjectName -PersonalAccessToken $PersonalAccessToken

if ($null -eq (GET-ADOProject -Organization $Organization -ProjectName $ProjectName -PersonalAccessToken $PersonalAccessToken)) {
    Write-Host -ForegroundColor Yellow "Project '$ProjectName' does not exist in '$Organization'"
    Write-Host "Creating Project '$ProjectName'" -NoNewline -ForegroundColor Yellow
    $result = New-ADOProject `
                -Organization $Organization `
                -ProjectName $ProjectName -ProjectDescription $ProjectDescription `
                -VersionControl $VersionControl `
                -TemplateId $template.id `
                -PersonalAccessToken $PersonalAccessToken
        
    # ==========================================================
    # 3. Monitor project creation via the Operations API
    # ==========================================================
    # Get Operation results
    $operation = Get-Operation -Organization $Organization -OperationId $result.id -PersonalAccessToken $PersonalAccessToken
    if ($result.status -notin 'queued', 'succeeded', 'notSet')
    {
        Write-Host ""
        Write-Host -ForegroundColor Red "Project creation faild! Status: '$($result.status)'"
        Write-Host -ForegroundColor Red $operation.resultMessage
        exit 3
    }

    # Wait for Project creation to finish
    Do {
        Write-Host "." -ForegroundColor Yellow -NoNewline
        Start-Sleep -Seconds 1 
        $operation = Get-Operation -Organization $Organization -OperationId $result.id -PersonalAccessToken $PersonalAccessToken
    } while($operation.status -eq "inProgress")
    # Write result of Operation
    switch ($operation.status) {
        "succeeded" { Write-Host ""; Write-Host -ForegroundColor Green "Project Creation Succeeded!"  }
        Default { Write-Host -ForegroundColor Red "Project creation failed! $($operation.resultMessage)" exit 3}
    }
    $project = GET-ADOProject -Organization $Organization -ProjectName $ProjectName -PersonalAccessToken $PersonalAccessToken
}

# ==========================================================
# 4. Update the project's agent pool permissions for:
#    - Build Administrator
#    - Release Administrator
#    - Project Administrator
# ==========================================================
# Get the current assigned project-scoped roles for the agent pools
$roles = Get-ProjectSecurityRoles -Organization $Organization -ProjectId $project.id -PersonalAccessToken $PersonalAccessToken
if ($null -eq $roles) {
    Write-Host -ForegroundColor Red "Failed to retrieve project-scoped roles for agent pools"
    exit 4
}

$roleIds = @()
foreach ($role in $roles.value) {
    $roleIds += $role.identity.id
}

$updatedRoles = PUT-AgentPoolRole -Organization $Organization -RoleIds $roleIds -ProjectId $project.id -RoleToAssign $PoolDefaultRole -PersonalAccessToken $PersonalAccessToken
if ($null -eq $updatedRoles) {
    Write-Host -ForegroundColor Red "Failed to update project agent pool permissions"
    exit 4
}

foreach ($updatedRole in $updatedRoles.value) {
    Write-Host ""
    Write-Host -ForegroundColor Yellow "Updated Roles:"
    $updatedRole | ConvertTo-Json -Depth $SerializationDepth | Write-Host -ForegroundColor Yellow -NoNewline
}

Write-Host ""; Write-Host -ForegroundColor Green "Project Agent Pool Role Assignment Succeeded!"; exit 0