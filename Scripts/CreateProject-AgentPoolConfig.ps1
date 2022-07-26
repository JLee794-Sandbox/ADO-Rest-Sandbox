# ==========================================================
# Custom Project Creation
# --------------------------------------------------
# Goal: Facilitate Project Creation and Update Agent
#         Pool Permissions for the Project Roles
# --------------------------------------------------
# 1. Retrieve Process Template ID by Name
# 2. Create Project with said Process Template ID
# 3. Monitor project creation via the Operations API
# 4. Once created, retrieve the project ID by name
# 5. Update the project's agent pool permissions for:
#    - Build Administrator
#    - Release Administrator
#    - Project Administrator
# ==========================================================
# Known Limitations:
#   - ADO API does not support filtering within the request
#     - filtering must be done after the response is received
# ==========================================================

# TODO: Parameterize Input Parameters
$Organization = "https://dev.azure.com/jinle"
$ProjectName = "rest-poc-delme"
$PersonalAccessToken = $Env:PAT
$PoolDefaultRole = "User"
$ProcessTemplateName = "Agile"
$DefaultRolesToUpdate = @(
  "Build Administrator",
  "Release Administrator",
  "Project Administrator"
)



Function Invoke-DevOpsAPI
{
[CmdletBinding()]
Param(
    [parameter(Position=0, Mandatory=$true)]
    [string] $Uri,
    [Parameter(Position=1)]
    [string] [ValidateSet('Default','Get', 'Post')]
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



# ==========================================================
# 1. Retrieve Process Template ID by Name
# ==========================================================
Invoke-RestMethod -Uri "$Organization/_apis/projects?api-version=7.0" -Method get -Headers @{Authorization='Basic ' + [Convert]::ToBase64string([Text.Encoding]::ASCII.GetBytes("$PersonalAccessToken"))}


# ==========================================================
# 2. Create Project with said Process Template ID
# ==========================================================

# ==========================================================
# 3. Monitor project creation via the Operations API
# ==========================================================

# ==========================================================
# 4. Once created, retrieve the project ID by name
# ==========================================================

# ==========================================================
# 5. Update the project's agent pool permissions for:
#    - Build Administrator
#    - Release Administrator
#    - Project Administrator
# ==========================================================
