
using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$body = $Request.Body 
$id = $body.requestId

# Respond to webhook with 200 ok
Push-OutputBinding -Name Response -Value (
    [HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
    }
)

if($body.outcome -like "3" ){
    "processing approval, adding to queue $id"
    
    # write request id to queue
    Push-OutputBinding -Name queueItem -Value $id

    # add request id and answer to table 
    $answer = $body.answer
    Push-OutputBinding -Name outputTable -Value @{
        PartitionKey = 'approvals'
        RowKey = "$id"
        answer = "$answer"
    } 

} elseif($body.contains("reason")){
    "processing request, adding to table $id"

    # add the guest's mail address to storage table
    $mail = $body.guestRequest.mail
    Push-OutputBinding -Name outputTable -Value @{
        PartitionKey = 'requests'
        RowKey = "$id"
        mail = "$mail"
    }
}
