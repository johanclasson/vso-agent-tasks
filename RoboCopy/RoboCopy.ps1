param([string]$Source, [string]$Destination)

robocopy /MIR /R:5 /W:30 /NS /NC /NFL /NDL /NP $Source $Destination
if ($LASTEXITCODE -gt 3){
    Write-Error "Something bad happened ($LASTEXITCODE)"
    exit -1
}
else {
    exit 0
}
