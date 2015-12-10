param([string]$Script)

Write-Output "Running script:`n$Script"
Invoke-Expression -Command $Script