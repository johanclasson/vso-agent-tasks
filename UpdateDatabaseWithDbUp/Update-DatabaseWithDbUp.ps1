param(
    [Parameter(Mandatory=$true)][string]$ConnectionString,
    [string]$ScriptPath = '.',
    [ValidateSet('NullJournal','SqlTable')][string]$Journal = 'SqlTable',
    [string]$Filter = '.*')

$ScriptPath = Resolve-Path $ScriptPath

function Install-DbUpAndGetDllPath {
    $workingDir = Join-Path $env:TEMP 'DatabaseMigration'
    $dllFilePattern = Join-Path $workingDir 'dbup.*\lib\net35\DbUp.dll'

    if (-not (Test-Path $workingDir)) {
        ni $workingDir -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path $dllFilePattern)) {
        $oldLocation = Get-Location
        cd $workingDir
        wget http://nuget.org/nuget.exe -OutFile nuget.exe -UseBasicParsing
        .\nuget.exe install dbup | Out-Null
        rm nuget.exe
        cd $oldLocation
    }
    return Resolve-Path $dllFilePattern | select -ExpandProperty Path -First 1
}

$dllPath = Install-DbUpAndGetDllPath
Add-Type -Path $dllPath

$filterFunc = {
    param([string]$file)
    return $file -match $Filter
}

$dbUp = [DbUp.DeployChanges]::To
$dbUp = [SqlServerExtensions]::SqlDatabase($dbUp, $ConnectionString)
$dbUp = [StandardExtensions]::WithScriptsFromFileSystem($dbUp, $ScriptPath, $filterFunc)
$dbUp = [StandardExtensions]::WithTransactionPerScript($dbUp)
$dbUp = [StandardExtensions]::LogToConsole($dbUp)
if ($Journal -eq "NullJournal") {
    $dbUp = [StandardExtensions]::JournalTo($dbUp, (New-Object DbUp.Helpers.NullJournal))
}
else {
    $dbUp = [SqlServerExtensions]::JournalToSqlTable($dbUp, 'dbo', '_SchemaVersions')
}
$dbUp.Build().PerformUpgrade() | Out-Null