[CmdletBinding()]
param()

$connectedServiceName = Get-VstsInput -Name "connectedServiceName"
$resourceGroupName = Get-VstsInput -Name "resourceGroupName"
$resourceGroupName = $resourceGroupName.Trim()

$ErrorActionPreference = "Stop"

# Initialize Azure.
Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
Initialize-Azure

Write-Host "Searching for deployments in resource group '$resourceGroupName'"

$deployment = Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName | Sort Timestamp -Descending | Select -First 1
if(-not $deployment)
{
    throw "Found no deployments for $resourceGroupName."
}
$deployment.Outputs.Keys | %{
    $name = $_;
    $variableName = "arm.$name"
    $value = $deployment.Outputs[$name].Value
    Write-Host "##vso[task.setvariable variable=$variableName;]$value"
    Write-Host "Setting varable $('$')($variableName) to '$value'"
}


