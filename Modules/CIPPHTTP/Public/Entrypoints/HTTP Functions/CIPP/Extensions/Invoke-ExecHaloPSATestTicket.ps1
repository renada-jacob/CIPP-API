Function Invoke-ExecHaloPSATestTicket {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        CIPP.Extension.ReadWrite
    .SYNOPSIS
        Create a HaloPSA test ticket end-to-end so admins can verify the full integration
        pipeline (auth, ticket type, default priority, outcome, tenant mapping) without
        waiting for a real alert to fire.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    try {
        $ConfigTable = Get-CIPPTable -TableName Extensionsconfig
        $Configuration = ((Get-CIPPAzDataTableEntity @ConfigTable).config | ConvertFrom-Json).HaloPSA

        if (-not $Configuration -or -not $Configuration.Enabled) {
            $Results = [pscustomobject]@{ Results = 'HaloPSA integration is not enabled. Save the integration with Enable Integration ticked, then try again.' }
        } else {
            # Pick the first mapped tenant's Halo client id so the test ticket lands on a real
            # client. Falls back to 1 (the same default the alert pipeline uses) if no mappings
            # exist - admins should set up Tenant Mapping for a more representative test.
            $MappingTable = Get-CIPPTable -TableName CippMapping
            $Mappings = Get-CIPPAzDataTableEntity @MappingTable -Filter "PartitionKey eq 'HaloMapping'"
            $Mapping = $Mappings | Where-Object { $_.IntegrationId } | Select-Object -First 1
            $ClientId = if ($Mapping) { [int]$Mapping.IntegrationId } else { 1 }
            $ClientName = if ($Mapping) { $Mapping.IntegrationName } else { 'Default Client (no Tenant Mapping configured)' }

            $Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ssZ')
            $Title = 'Test ticket from CIPP integration'
            $Description = @"
<p>This is a <strong>test ticket</strong> created by CIPP at $Timestamp to verify end-to-end HaloPSA delivery.</p>
<p>Target client: <strong>$ClientName</strong> (id <code>$ClientId</code>).</p>
<p>The ticket exercises the same code path used for real CIPP alerts, so any configured Ticket Type, Default Priority and (when Consolidate Tickets is on) Outcome should all apply.</p>
<p>It is safe to close this ticket.</p>
"@

            $Result = New-HaloPSATicket -Title $Title -Description $Description -Client $ClientId

            $Results = [pscustomobject]@{ Results = "$Result against client '$ClientName' (id $ClientId). It is safe to close this ticket." }
        }
    } catch {
        $Results = [pscustomobject]@{ Results = "Failed to create HaloPSA test ticket: $($_.Exception.Message). Line $($_.InvocationInfo.ScriptLineNumber)" }
    }

    return ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $Results
        })
}
