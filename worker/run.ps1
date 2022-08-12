# Input bindings are passed in via param block.
param($QueueItem, $TriggerMetadata, $RequestItem, $ApprovalItem)

# import modules, az.accounts is required to obtain a token for mgGraph
Import-Module Az.Accounts, Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Users.Actions, EasyLife365

function Get-AzToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ResourceUri,
        [Switch]$AsHeader
    ) 
    $Context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
    $Token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $ResourceUri).AccessToken
    if ($AsHeader) {
        return @{Headers = @{Authorization = "Bearer $Token" } }
    }
    return $Token
}

$guestEmail = $RequestItem.mail
$approval = $ApprovalItem.answer

if(-not($guestEmail)){
    "could not find guest email in storage table for id: $QueueItem"
} else {
    "processig approval message for $guestEmail : $approval"

    $Token = Get-AzToken -ResourceUri 'https://graph.microsoft.com/'
    Connect-MgGraph -AccessToken $Token

    # get guest user from graph
    $filter = "UserType eq 'Guest' and mail eq '$guestEmail'"
    Get-MgUser -Filter $filter -ErrorAction SilentlyContinue ; $i = 1
    while ($user.count -ne 1) {
        $user = Get-MgUser -Filter $filter -ErrorAction SilentlyContinue 
        Start-Sleep -Seconds 60 ; $i++
        if($i -eq 10){
            Write-Error "could not find user $id" -ErrorAction stop
        }
    }

    # update metadata attribute with approval message
    $id = $user.id
    if($id){
        Set-EasyGuestUser -UserId $id -Metadata @{
            $env:attributeName = $approval
        }
    }
}
