# Store Approval Message as EasyLife 365 metadata field

If you want to permanently store the approval message, we recommend creating a metadata field of type text field. Give it a name such as `elApproval` and enable the check box `is hidden in wizard`.

Update the parameters in the script below and deploy.

```powershell
# edit parameters
# specify the name and location of the resources that will be created 
$resourceGroupName = "el-approval-test"
$functionAppName = "el-approval-test"
$storageAccountName = "elapprovaltest1"
$location = "westeurope"
# specify attribute name of the section that will store the approval message
$attributeName = "elApproval" 

# login to azure and optionally change subscription
az login
# az account set --subscription 00000000-0000-0000-0000-000000000000

# there should be no need to change anything below this

# create resource group
az group create `
    --name $resourceGroupName `
    --location $location

# create storage account
az storage account create `
    --name $storageAccountName `
    --resource-group $resourceGroupName `
    --location $location `
    --sku Standard_LRS

# create function app and configure settings
$funcAppOutput = az functionapp create `
    --consumption-plan-location $location `
    --name $functionAppName --os-type Windows `
    --resource-group $resourceGroupName `
    --runtime powershell `
    --runtime-version 7.2 `
    --storage-account $storageAccountName `
    --functions-version 4 `
    --assign-identity '[system]' | ConvertFrom-Json

az functionapp config appsettings set `
    --name $functionAppName `
    --resource-group $resourceGroupName `
    --settings "attributeName=$attributeName"

# get service principals for permission assignment
$servicePrincipalId = $funcAppOutput.identity.principalId
$graphObjectId = (az ad sp list --display-name 'Microsoft Graph' | ConvertFrom-Json)[0].id

# assign permissions to the managed identity
@(
    '741f803b-c850-494e-b5df-cde7c675a1ca' # user.readwrite.all
) | ForEach-Object{
    $body = @{
        principalId = $servicePrincipalId
        resourceId = $graphObjectId
        appRoleId = $_
    } | ConvertTo-Json -Compress
    $uri = "https://graph.microsoft.com/v1.0/servicePrincipals/$servicePrincipalId/appRoleAssignments"
    $header = "Content-Type=application/json"
    # for some reason, the body must only use single quotes
    az rest --method POST --uri $uri --header $header --body $body.Replace('"',"'")
}

# update deploy package
$deployPath = Get-ChildItem | `
    Where-Object {$_.Name -notmatch "deploypkg" -and $_.Name -notmatch "_automation" } | `
    Compress-Archive -DestinationPath deploypkg.zip -Force -PassThru

# deploy the zipped package
az functionapp deployment source config-zip `
    --name $functionAppName `
    --resource-group $resourceGroupName `
    --src $deployPath.FullName
```
