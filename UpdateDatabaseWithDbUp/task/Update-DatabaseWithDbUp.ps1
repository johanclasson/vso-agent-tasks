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

# Log output is lost after build task is run. This hack solves it.
$sourceCode = @"
public class VstsUpgradeLog : DbUp.Engine.Output.IUpgradeLog
{
    public void WriteInformation(string format, params object[] args)
    {
        System.Console.WriteLine(format, args);
    }

    public void WriteError(string format, params object[] args)
    {
        System.Console.WriteLine("##vso[task.logissue type=error;]" + string.Format(format, args));
    }

    public void WriteWarning(string format, params object[] args)
    {
        System.Console.WriteLine("##vso[task.logissue type=warning;]" + string.Format(format, args));
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]'VstsUpgradeLog').Type) {
    Add-Type -TypeDefinition $sourceCode -Language CSharp -ReferencedAssemblies $dllPath
}

$filterFunc = {
    param([string]$file)
    return $file -match $Filter
}

$dbUp = [DbUp.DeployChanges]::To
$dbUp = [SqlServerExtensions]::SqlDatabase($dbUp, $ConnectionString)
$dbUp = [StandardExtensions]::WithScriptsFromFileSystem($dbUp, $ScriptPath, $filterFunc)
$dbUp = [StandardExtensions]::WithTransactionPerScript($dbUp)
$dbUp = [StandardExtensions]::LogTo($dbUp, (New-Object VstsUpgradeLog))
if ($Journal -eq "NullJournal") {
    $dbUp = [StandardExtensions]::JournalTo($dbUp, (New-Object DbUp.Helpers.NullJournal))
}
else {
    $dbUp = [SqlServerExtensions]::JournalToSqlTable($dbUp, 'dbo', '_SchemaVersions')
}
$result = $dbUp.Build().PerformUpgrade()
if (!$result.Successful) {
    $errorMessage = ""
    if ($result.Error -ne $null) {
        $errorMessage = $result.Error.Message
    }
    Write-Host "##vso[task.logissue type=error;]Database migration failed. $errorMessage"
    Write-Host "##vso[task.complete result=Failed;]"
    Exit -1
}
