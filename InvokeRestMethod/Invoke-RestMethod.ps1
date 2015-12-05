param(
    [string]$Url,
    [string]$Method = "Post",
    [string]$ContentType = "application/json",
    [string]$Body,
    [string]$Timeout = "00:10:00"
)
$parsedTimeout = [timespan]::Parse($Timeout)

Write-Output "Trying to send $Method-request to $Url within the timebox $parsedTimeout."
$start = Get-Date
while ($true) {
    try {
        if ($Method -eq "Get" -or [string]::IsNullOrEmpty($Body)) {
            Invoke-RestMethod -Uri $Url -Method $Method -TimeoutSec 10 | Out-Null
        }
        else {
            Invoke-RestMethod -Uri $Url -Method $Method -ContentType $ContentType -Body $Body -TimeoutSec 10 | Out-Null
        }
        break
    }
    catch {
        $timeTaken = (Get-Date) - $start
        if ($timeTaken -ge $parsedTimeout) {
            Write-Error "Timeout expired"
            throw
        }
        Write-Output "Waiting. ($_)"
        Start-Sleep -Seconds 10
    }
}
Write-Output "Done!"