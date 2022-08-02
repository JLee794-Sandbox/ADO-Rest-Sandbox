# ADO Rest Sandbox

This is a demo sandbox to explore API-related topics to assist in Azure DevOps resource management.

Inside this project you will find various Powershell scripts located in [./Scripts/](./Scripts/) directory, and accessory tools that assist in development efforts within the [./Tools/](./Tools/) directory.

## Topics

1. [Managing Project Agent-Pool Permissions](#managing-project-agent-pool-permissions)

## Managing Project Agent-Pool Permissions

### Problem

Currently in the Azure DevOps portal, the capability to modify default behaviors for agent pool permission allocation on new projects is not supported. This can raise concerns for many as the default behavior is to grant **administrative** access to project-scoped roles (e.g Build/Release Administrator, Project Administrator) to organization-scoped agent pool resources.
Meaning, project-scoped users can potentially remove existing agents that are being leveraged by other projects within the organization, and add their own agents that could bypass any security or standards that are baked into dedicated CICD machine images.

### Solution

Through leveraging the Azure DevOps REST API, facilitate the project creation as well as the agent pool role assignments for all default project permissions.

#### Relevant Files

1. [PostmanCollection](./Tools/PostmanCollections/CreateProject-AgentPoolConfig.ADO%20Rest%20API.postman_collection.json)
1. [CreateProject-AgentPoolConfig.ps1](./Scripts/CreateProject-AgentPoolConfig.ps1)

#### Steps to Deploy

##### [CreateProject-AgentPoolConfig.ps1](./Scripts/CreateProject-AgentPoolConfig.ps1)

1. [Generate a DevOps PAT](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=Windows#create-a-pat)
    1. TODO: Narrow down the exact permissions required to make these requests
    1. Current DevOps Pat Permissions (working):

        > // TODO: Narrow down exact permissions needed
        >
        >**!!! The permissions below are most likely more permissive than necessary and were leveraged for demo purposes only. Use at your own risk !!!**

        1. Agent Pools: Read & Manage
        1. Project and Team: Read, write, & manage
        1. Security: Manage
        1. Tokens: Read & manage
        1. User Profile
2. Set the Azure DevOps PAT to the `$env:PAT` environment variable

```pwsh
# Set PAT as environment var
$env:PAT = '<your devops pat>'
```

3. Invoke the script with your project variables
    Input Arguments:
    - `$Organization`: URI of your DevOps organization (e.g `https://dev.azure.com/my-ado-org`)
    - `$ProjectName`: Name of the new project to create, or an existing project to update the project roles on.
    - `$ProjectDescription`: [OPTIONAL] Short project description to initialize with (defaults to `$null`).
    - `$VersionControl`: [OPTIONAL] Version control to be used by the repositories inside the project, can be `TFVC` or `Git` (defaults to `Git`).
    - `ProcessTemplate`: [OPTIONAL] Process template name to search for within the organization to initialize the project with (defaults to `Scrum`).
    - `PoolDefaultRole`: [OPTIONAL] Agent pool permission to assign the default project permissions upon creation (defaults to `User`).

```pwsh
./Scripts/CreateProject-AgentPoolConfig.ps1 `
  -Organization "https://dev.azure.com/some-org" `
  -ProjectName "My-New-Project" `
  -ProjectDescription "Project and Agent Pool permission management via REST API PoC"
```

##### [PostmanCollection](./Tools/PostmanCollections/CreateProject-AgentPoolConfig.json)

1. [Generate a DevOps PAT](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=Windows#create-a-pat)
    1. TODO: Narrow down the exact permissions required to make these requests
    1. Current setup (working):
        // TODO: Narrow down exact permissions needed
        **_ !!! The permissions below are most likely more permissive than necessary. Use at your own risk !!! _**
        1. Agent Pools: Read & Manage
        1. Project and Team: Read, write, & manage
        1. Security: Manage
        1. Tokens: Read & manage
        1. User Profile
1. Follow the [PostMan import documentation](https://learning.postman.com/docs/getting-started/importing-and-exporting-data/#importing-data-into-postman) to import the `./Tools/PostmanCollections/CreateProject-AgentPoolConfig.json` collection
1. Set up your variables within your environment to execute the templated queries.
    - organization
    - projectId
    - PAT (set as secret!!!)
    - roleDisplayName
