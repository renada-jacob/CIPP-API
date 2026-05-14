function Get-HaloPriority {
    <#
    .SYNOPSIS
        Get HaloPSA Priorities for use in the integration UI dropdown.
    .DESCRIPTION
        Returns the list of priorities defined in the linked HaloPSA instance, sorted by their
        priority order. Used to populate the DefaultPriority autoComplete on the integration
        settings page so admins can pick which priority CIPP-generated tickets are created with.
    #>
    [CmdletBinding()]
    param ()
    $Table = Get-CIPPTable -TableName Extensionsconfig
    try {
        $Configuration = ((Get-CIPPAzDataTableEntity @Table).config | ConvertFrom-Json -ea stop).HaloPSA
        $Token = Get-HaloToken -configuration $Configuration

        $Priorities = Invoke-RestMethod -Uri "$($Configuration.ResourceURL)/Priority" -ContentType 'application/json' -Method GET -Headers @{Authorization = "Bearer $($Token.access_token)" }
        $Priorities | Sort-Object -Property priorityorder, name
    } catch {
        $Message = if ($_.ErrorDetails.Message) {
            Get-NormalizedError -Message $_.ErrorDetails.Message
        } else {
            $_.Exception.Message
        }
        @(@{ name = "Could not get HaloPSA Priorities, error: $Message"; id = '' })
    }
}
