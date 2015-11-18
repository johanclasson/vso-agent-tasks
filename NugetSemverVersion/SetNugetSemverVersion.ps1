Param(
  [string]$pathToSearch = $env:BUILD_SOURCESDIRECTORY,
  [string]$buildNumber = $env:BUILD_BUILDNUMBER,
  [switch]$makeReleaseVersion,
  [string]$preReleaseName,
  [switch]$includeRevInPreRelease
)

$ErrorActionPreference = "Stop"

if ($makeReleaseVersion) {
    $preReleaseName = $null
    $includeRevInPreRelease = $false
}
elseif ([string]::IsNullOrEmpty($preReleaseName)) {
    Write-Host "Prerelease name is not set"
    exit 1
}

$searchFilter = "AssemblyInfo.*"
$pattern = "\d+\.\d+\.\d+\.\d+"
if ($buildNumber -match $pattern -ne $true) {
    Write-Host "Could not extract a version from [$buildNumber] using pattern [$pattern]"
    exit 1
}

# Set version variables
$extractedBuildNumbers = $Matches[0].Split('.')
$version = "$($extractedBuildNumbers[0]).$($extractedBuildNumbers[1])"
$fileVersion = [string]::Join(".",$extractedBuildNumbers)
$informationalVersion = "$($extractedBuildNumbers[0]).$($extractedBuildNumbers[1]).$($extractedBuildNumbers[2])"
if ([string]::IsNullOrEmpty($preReleaseName) -ne $true) {
    $informationalVersion += "-$preReleaseName"
    if ($includeRevInPreRelease) {
        $informationalVersion += ([int]$extractedBuildNumbers[3]).ToString("0000")
    }
}
Write-Host "Using version $version, file version $fileVersion and informational version $informationalVersion"

function Replace-Version($content, $version, $attribute) {
    $versionAttribute = "[assembly: $attribute(""$version"")]"
    $pattern = "\[assembly: $attribute\("".*""\)\]"
    $versionReplaced = $false
    $content = $content | %{
        if ($_ -match $pattern) {
            $versionReplaced = $true
            Write-Host "     * Replaced $($Matches[0]) with $versionAttribute"
            $_ = $_ -replace [regex]::Escape($Matches[0]),$versionAttribute
        }
        $_
    }
    if (-not $versionReplaced) {
        Write-Host "     * Added $versionAttribute to end of content"
        $content += [System.Environment]::NewLine + $versionAttribute
    }
    return $content
}

gci -Path $pathToSearch -Filter $searchFilter -Recurse | %{
    Write-Host "  -> Changing $($_.FullName)"
         
    # remove the read-only bit on the file
    sp $_.FullName IsReadOnly $false
 
    # run the regex replace
    $content = gc $_.FullName
    $content = Replace-Version -content $content -version $version -attribute 'AssemblyVersion'
    $content = Replace-Version -content $content -version $fileVersion -attribute 'AssemblyFileVersion'
    $content = Replace-Version -content $content -version $informationalVersion -attribute 'AssemblyInformationalVersion'
    $content | sc $_.FullName -Encoding UTF8
}
Write-Host "Done!"
