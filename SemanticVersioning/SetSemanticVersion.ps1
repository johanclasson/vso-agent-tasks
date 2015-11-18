Param(
  [string]$pathToSearch = $env:BUILD_SOURCESDIRECTORY,
  [string]$buildNumber = $env:BUILD_BUILDNUMBER,
  [regex]$pattern = "\d+\.\d+\.\d+\.\d+",
  [string]$makeReleaseVersion = [bool]::FalseString,
  [string]$preReleaseName = "",
  [string]$includeRevInPreRelease = [bool]::FalseString,
  [string]$patternSplitCharacters = "."
)

$ErrorActionPreference = "Stop"

if ([bool]::Parse($makeReleaseVersion)) {
    $preReleaseName = $null
    $includeRevInPreRelease = [bool]::FalseString
}
elseif ([string]::IsNullOrEmpty($preReleaseName)) {
    Write-Host "Prerelease name is not set"
    exit 1
}

$searchFilter = "AssemblyInfo.*"
if ($buildNumber -match $pattern -ne $true) {
    Write-Host "Could not extract a version from [$buildNumber] using pattern [$pattern]"
    exit 2
}

# Set version variables
$extractedBuildNumbers = @($Matches[0].Split(([char[]]$patternSplitCharacters)))
if ($extractedBuildNumbers.Length -ne 4) {
    Write-Host "The extracted build number $($Matches[0]) does not contain the expected 4 elements"
    exit 2
}
$version = "$($extractedBuildNumbers[0]).$($extractedBuildNumbers[1])"
$fileVersion = [string]::Join(".",$extractedBuildNumbers)
$informationalVersion = "$($extractedBuildNumbers[0]).$($extractedBuildNumbers[1]).$($extractedBuildNumbers[2])"
if ([string]::IsNullOrEmpty($preReleaseName) -ne $true) {
    $informationalVersion += "-$preReleaseName"
    if ([bool]::Parse($includeRevInPreRelease)) {
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
