# Powershell script to trigger and resolve PRTG alerts in PagerDuty using the events v2 API

# Notes
# Copy the line below (exluding the hash) into the parameters field in the PRTG notification template
# '%probe' '%device' '%deviceid' '%sensor' '%sensorid' '%group' '%groupid' '%home' '%host' '%status' '%colorofstate' '%down' '%priority' '%message' '%comments' '%datetime'

# Ingest the alert payload from PRTG
Param(
    [string]$probe,
    [string]$device,
    [string]$deviceid,
    [string]$sensor,
    [string]$sensorid,
    [string]$group,
    [string]$groupid,
    [string]$prtg_home,
    [string]$prtg_host,
    [string]$status,
    [string]$colorofstate,
    [string]$down,
    [string]$priority,
    [string]$message,
    [string]$comments,
    [string]$datetime
)

# Determine the Event Action
$regex = [regex] "\((.*)\)"
$action = $regex::match($status, $regex).groups[1]

switch ($action) {
    "now: Up" { $PDevent = "resolve" }
    default { $PDevent = "trigger" }
}

# Determine the Severity
switch ($colorofstate) {
    "#b4cc38"	{ $Severity = "info" }
    "#ffcb05"	{ $Severity = "warning" }
    #   "Error"		{$Severity="error"}
    "#d71920"	{ $Severity = "critical" }
    default { $Severity = "critical" }
}

$RoutingKey = "3534011a3b6d450a8ae967b57f6ef48a"
$Url = "https://events.pagerduty.com/v2/enqueue"

$Description = "$device $sensor $status $down"
# $Severity = "critical"
$Timestamp = Get-Date -UFormat "%Y-%m-%dT%T%Z"

$AlertPayload = @{
    routing_key  = $RoutingKey
    event_action = $PDevent
    dedup_key    = $sensor
    client       = "PRTG Network Monitor"
    client_url   = $prtg_home
    payload      = @{
        summary        = $Description
        timestamp      = $Timestamp
        source         = $device
        severity       = $Severity
        component      = $group
        class          = $sensor
        custom_details = @{
            prtg_server  = $prtg_home
            probe        = $probe
            group        = $group, $groupid
            device       = $device, $deviceid
            sensor       = $sensor, $sensorid
            url          = $prtg_host
            colorofstate = $colorofstate
            down         = $down
            downtime     = $downtime
            priority     = $priority
            message      = $message
            datetime     = $datetime
            comments     = $comments
            status       = $status
        }
    }
}

# Convert Events Payload to JSON

$json = ConvertTo-Json -InputObject $AlertPayload

$logEvents = "C:\pagerduty\logs\prtg2pd_log.txt"

# Send to PagerDuty and Log Results

$LogMtx = New-Object System.Threading.Mutex($False, "LogMtx")
$LogMtx.WaitOne() | Out-Null

try {
    Invoke-RestMethod	-Method Post `
        -ContentType "application/json" `
        -Body $json `
        -Uri $Url `
    | Out-File $logEvents -Append
}

finally {
    $LogMtx.ReleaseMutex() | Out-Null
}