# Set up Zendesk API credentials
$zdSubdomain = "your_subdomain"
$zdEmail = "your_email_address"
$zdToken = "your_api_token"

# Set up API endpoints
$zdTicketsUrl = "https://$zdSubdomain.zendesk.com/api/v2/groups/{GROUP_ID}/tickets.json"
$zdAuditUrl = "https://$zdSubdomain.zendesk.com/api/v2/tickets/{TICKET_ID}/audits.json"

# Set up date format
$dateFormat = "yyyy-MM-ddTHH:mm:ssZ"

# Set up group ID and empty arrays for first response times and resolution times
$groupId = {GROUP_ID}
$firstResponseTimes = @()
$resolutionTimes = @()

# Retrieve tickets in group
$tickets = Invoke-RestMethod -Uri $zdTicketsUrl -Headers @{Authorization = "Basic $($zdEmail):$($zdToken)"} -Method Get | Select-Object -ExpandProperty tickets

# Iterate through tickets and calculate first response time and resolution time
foreach ($ticket in $tickets) {
    # Retrieve ticket audits
    $auditUrl = $zdAuditUrl -replace "{TICKET_ID}", $ticket.id
    $audits = Invoke-RestMethod -Uri $auditUrl -Headers @{Authorization = "Basic $($zdEmail):$($zdToken)"} -Method Get | Select-Object -ExpandProperty audits
    
    # Find first public comment made by agent
    $firstPublicComment = $audits | Where-Object { $_.events.event_type -eq "Comment" -and $_.events.public -eq $true -and $_.events.author.role -eq "agent" } | Select-Object -First 1
    
    # Find resolution time
    $resolutionEvent = $audits | Where-Object { $_.events.event_type -eq "Change" -and $_.events.field_name -eq "status" -and $_.events.value -eq "solved" } | Select-Object -Last 1
    
    if ($firstPublicComment -and $resolutionEvent) {
        # Calculate first response time and resolution time and add to arrays
        $firstResponseTime = [DateTime]::ParseExact($firstPublicComment.events.created_at, $dateFormat, $null) - [DateTime]::ParseExact($ticket.created_at, $dateFormat, $null)
        $firstResponseTimes += $firstResponseTime.TotalHours
        
        $resolutionTime = [DateTime]::ParseExact($resolutionEvent.events.created_at, $dateFormat, $null) - [DateTime]::ParseExact($ticket.created_at, $dateFormat, $null)
        $resolutionTimes += $resolutionTime.TotalHours
    }
}

# Calculate average first response time and resolution time for group
if ($firstResponseTimes.Count -gt 0) {
    $avgFirstResponseTime = ($firstResponseTimes | Measure-Object -Average).Average
    Write-Host "Average first response time for group $groupId: $avgFirstResponseTime hours"
} else {
    Write-Host "No first response times found for group $groupId"
}

if ($resolutionTimes.Count -gt 0) {
    $avgResolutionTime = ($resolutionTimes | Measure-Object -Average).Average
    Write-Host "Average resolution time for group $groupId: $avgResolutionTime hours"
} else {
    Write-Host "No resolution times found for group $groupId"
}
