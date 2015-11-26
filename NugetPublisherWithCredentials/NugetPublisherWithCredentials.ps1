param(
      [string]$RootDir,
      [string]$NuGetSource,
      [string]$NuGetSourceName,
      [string]$Username,
      [string]$Password)

$ErrorActionPreference = "Stop"

$nugetPath = Get-ToolPath -Name 'NuGet.exe'
if (-not $nugetPath -and $nugetRestore)
{
    Write-Warning (Get-LocalizedString -Key "Unable to locate nuget.exe. Package restore will not be performed for the solutions")
}

Write-Verbose "Adding nuget source $NuGetSourceName"
Invoke-Tool -Path $nugetPath -Arguments "sources add -name $NuGetSourceName -source $NuGetSource -username $Username -password $Password"

$packages = gci $RootDir -Recurse -Filter "*.nupkg"
try {
    $packages | %{
        Write-Verbose "Publishing nuget package $($_.FullName)"
        Invoke-Tool -Path $nugetPath -Arguments "push $($_.FullName) -Source $NuGetSource -ApiKey $NuGetSourceName"
    }
}
catch {
    throw
}
finally {
    Write-Verbose "Removing nuget source $NuGetSourceName"
    Invoke-Tool -Path $nugetPath -Arguments "sources remove -name $NuGetSourceName"
}
