param($TempDir, $Path = ".", $ConnectionString = "Server=.;Database=Test;Trusted_Connection=True;")

#TODO: Generate migration scripts instead (https://github.com/aspnet/EntityFramework6/pull/87)

$ErrorActionPreference = "Continue"

if (-not (Test-Path $Path)) {
    throw "Cannot find path '$Path' because it does not exist."
    exit -1
}

if ($TempDir -eq $null) {
    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "EfMigration"
}
if (-not (Test-Path $TempDir)) {
    ni $TempDir -ItemType Directory | Out-Null
}
$nugetPath = Join-Path $TempDir "nuget.exe"
if (-not (Test-Path ($nugetPath))) {
    wget "http://www.nuget.org/nuget.exe" -OutFile $nugetPath
}

function Get-BaseTypesSafely($Assembly) {
    $dir = Split-Path $Assembly.Location -Parent
    $efPath = Join-Path $dir "EntityFramework.dll"
    Add-Type -Path $efPath
    try {
        return $Assembly.GetTypes() | select -ExpandProperty BaseType | select -ExpandProperty FullName
    }
    catch {
        $types = $_.Exception.InnerException.Types | select -ExpandProperty BaseType | select -ExpandProperty FullName
        Write-Warning "Failed to all load types for $($Assembly.Location)"
        return $types
    }
}

function Find-DllsToMigrate() {
    $dllsToMigrate = @()
    $whiteList = 'Microsoft\..*','EntityFramework\..*','System\..*'
    $efDlls = gci $Path -Recurse -Filter "EntityFramework.dll"
    $dirs = @($efDlls | %{ $_.Directory.FullName } | ?{ Test-Path (Join-Path $_ "EntityFramework.SqlServer.dll") } )
    $dlls = @()
    $dirs | %{ $dlls += gci $_ -Filter *.dll | ?{
        $filename = $_; @($whiteList | ?{ $filename -match $_ }).Length -eq 0
    } |  select -ExpandProperty FullName }
    $dlls | %{
        $dllPath = $_
        $assembly = [System.Reflection.Assembly]::LoadFile($dllPath)
        $referencesEf = @($assembly.GetReferencedAssemblies() | ?{ $_.Name -eq "EntityFramework" }).Length -ne 0
        if ($referencesEf) {
            $baseTypes = Get-BaseTypesSafely $assembly
            $hasMigration = @($baseTypes | ?{ $_ -match "System.Data.Entity.Migrations.DbMigration" }).Length -ne 0
            if ($hasMigration) {
                $dllsToMigrate += $dllPath
            }
        }
    }
    return $dllsToMigrate
}

function Install-Nuget($Version) {
    if (-not (Test-Path (Join-Path $TempDir "EntityFramework.$Version"))) {
        Write-Host "Installing EntityFramework NuGet-package"
        & $nugetPath install EntityFramework -Version $Version -OutputDirectory $TempDir
    }
}

function Run-Migration($dllPath) {
    $dir = Split-Path $dllPath -Parent
    $version = ls (Join-Path $dir EntityFramework.dll) | select -ExpandProperty VersionInfo | select -ExpandProperty ProductVersion
    if (-not ($version -match "\d\.\d\.\d")){
        throw "Could not find Enity Framework version in $version"
    }
    $version = $Matches[0]
    Install-Nuget $version
    Write-Host "Running migration of assembly $dllPath against migration utility of Entity Framework $version."
    cp (Join-Path $TempDir "EntityFramework.$version\tools\migrate.exe") $dir
    cd $dir
    ./migrate.exe (Split-Path $dllPath -Leaf) /connectionString:"$ConnectionString" /connectionProviderName:"System.Data.SqlClient"
    rm ./migrate.exe
}

$oldDir = Get-Location

if ((Get-Item $Path) -is [System.IO.DirectoryInfo]) {
    $dlls = Find-DllsToMigrate
    $dlls | %{
        Run-Migration $_
    }
}
else {
    Run-Migration (Resolve-Path $Path)
}

cd $oldDir
