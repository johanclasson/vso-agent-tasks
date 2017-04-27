param(
    [Parameter(Mandatory=$true)][string]$ConnectionString,
    [string]$ScriptPath = '.',
    [ValidateSet('NullJournal','SqlTable')][string]$Journal = 'SqlTable',
    [string]$Filter = '.*',
    [ValidateSet('NoTransactions','TransactionPerScript','SingleTransaction')]
    [string]$TransactionStrategy = 'TransactionPerScript',
	[string]$JournalName = '_SchemaVersions')

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
        
        # Check if nuget.exe is already in the path and use that
        $nuget = Get-Command "nuget.exe" -ErrorAction SilentlyContinue
        if ($nuget -eq $null) {
            # nuget.exe not in path, download it
            wget https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile nuget.exe -UseBasicParsing
            $nuget = ".\nuget.exe"
        }
        
        & $nuget install dbup | Out-Null

        if (Test-Path .\nuget.exe) {
            rm .\nuget.exe
        }

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
    private System.Action<string> WriteHost { get; set; }

    public VstsUpgradeLog(System.Action<string> writeHost)
    {
        WriteHost = writeHost;
    }

    public void WriteInformation(string format, params object[] args)
    {
        WriteHost(string.Format(format, args));
    }

    public void WriteWarning(string format, params object[] args)
    {
        WriteHost("##vso[task.logissue type=warning;]" + string.Format(format, args));
    }

    public void WriteError(string format, params object[] args)
    {
        WriteHost("##vso[task.logissue type=error;]" + string.Format(format, args));
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

$configFunc = {
    param($configuration)
    $configuration.ScriptExecutor.ExecutionTimeoutSeconds = 0
}

[Action[string]]$infoDelegate = {param($message) Write-Host $message}

$dbUp = [DbUp.DeployChanges]::To
$dbUp = [SqlServerExtensions]::SqlDatabase($dbUp, $ConnectionString)
$dbUp = [StandardExtensions]::WithScriptsFromFileSystem($dbUp, $ScriptPath, $filterFunc)
if ($TransactionStrategy -eq 'TransactionPerScript') {
    $dbUp = [StandardExtensions]::WithTransactionPerScript($dbUp)
}
elseif ($TransactionStrategy -eq 'SingleTransaction') {
    $dbUp = [StandardExtensions]::WithTransaction($dbUp)
}
else {
    $dbUp = [StandardExtensions]::WithoutTransaction($dbUp)
}
$dbUp = [StandardExtensions]::LogTo($dbUp, (New-Object VstsUpgradeLog $infoDelegate))
if ($Journal -eq "NullJournal") {
    $dbUp = [StandardExtensions]::JournalTo($dbUp, (New-Object DbUp.Helpers.NullJournal))
}
else {
    $dbUp = [SqlServerExtensions]::JournalToSqlTable($dbUp, 'dbo', $JournalName)
}
$dbUp.Configure($configFunc)
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
