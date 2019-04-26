function Get-TempDir {
    return $env:LOCALAPPDATA
}

function Get-ResolvedPaths {
    param($rootDir)
    $patterns = @();
    $patterns += 'dbup-core*\lib\net35\*.dll'
    $patterns += 'dbup-sqlserver*\lib\net35\*.dll'
    $patterns | ForEach-Object { Resolve-Path (Join-Path $rootDir $_) -ErrorAction SilentlyContinue } | Select-Object -ExpandProperty Path
}

function Get-DllPaths {
    $tempDir = Join-Path (Get-TempDir) 'DatabaseMigration'
    $paths = @(Get-ResolvedPaths $tempDir)
    if ($paths.Length -ne 2) { # 2 <= number of dlls
        $localDir = Join-Path $PSScriptRoot 'lib'
        $paths = @(Get-ResolvedPaths $localDir)
    }
    return $paths
}

$dllPaths = @(Get-DllPaths)
$dllPaths | ForEach-Object {
    Add-Type -Path $_
}

# Log output is lost after build task is run. This hack solves it.
if (-not ([System.Management.Automation.PSTypeName]'VstsUpgradeLog').Type) {
    Add-Type -TypeDefinition @"
using DbUp.Engine.Output;

public class VstsUpgradeLog : IUpgradeLog
{
    private System.Action<string> WriteHost { get; set; }

    public VstsUpgradeLog(System.Action<string> writeHost)
    {
        WriteHost = writeHost;
    }

    public void WriteInformation(string format, params object[] args)
    {
        WriteHost(string.Format(format, args).Trim());
    }

    public void WriteWarning(string format, params object[] args)
    {
        // ## is separated from command text so that system.debug mode does not bail out
        WriteHost("##" + "vso[task.logissue type=warning;]" + string.Format(format, args));
    }

    public void WriteError(string format, params object[] args)
    {
        WriteHost("##" + "vso[task.logissue type=error;]" + string.Format(format, args));
    }
}
"@ -Language CSharp -ReferencedAssemblies $dllPaths
}

if (-not ([System.Management.Automation.PSTypeName]'FileSystemScriptProvider').Type) {
    # This is a FileSystemScriptProvider inspired of that is implemented in  DbUp 4.0, with added ordering feature.
    Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using DbUp.Engine;
using DbUp.Engine.Transactions;
using DbUp.Support;

public enum FileSearchOrder
{
    Filename = 0,
    FilePath = 1,
    FolderStructure = 2
}

public class FileSystemScriptOptions
{
    public FileSystemScriptOptions()
    {
        Encoding = Encoding.Default;
    }

    public bool IncludeSubDirectories { get; set; }
    public FileSearchOrder Order { get; set; }
    public Func<string, bool> Filter { get; set; }
    public Encoding Encoding { get; set; }
}

public class FileSystemScriptProvider : IScriptProvider
{
    private readonly string directoryPath;
    private readonly Func<string, bool> filter;
    private readonly Encoding encoding;
    private FileSystemScriptOptions options;
    private int nextRunGroupOrder = 1;

    public FileSystemScriptProvider(string directoryPath):this(directoryPath, new FileSystemScriptOptions())
    {
    }

    public FileSystemScriptProvider(string directoryPath, FileSystemScriptOptions options)
    {
        if (options==null)
            throw new ArgumentNullException("options");
        this.directoryPath = directoryPath.Replace("/","\\").EndsWith("\\") ? directoryPath.Substring(0, directoryPath.Length - 1) : directoryPath;
        this.filter = options.Filter;
        this.encoding = options.Encoding;
        this.options = options;
    }

    public IEnumerable<SqlScript> GetScripts(IConnectionManager connectionManager)
    {
        var files = Directory.GetFiles(directoryPath, "*.sql", ShouldSearchSubDirectories()).AsEnumerable();
        if (this.filter != null)
        {
            files = files.Where(filter);
        }
        var infos = files.Select(f => new FileInfo(f));
        if (options.Order == FileSearchOrder.Filename)
        {
            infos = infos.OrderBy(i => i.Name);
        }
        if (options.Order == FileSearchOrder.FilePath)
        {
            infos = infos.OrderBy(i => i.FullName);
        }
        return infos.Select(i => SqlScriptFromFile(i)).ToArray();
    }

    private SqlScript SqlScriptFromFile(FileInfo file)
    {
        using (FileStream fileStream = new FileStream(file.FullName, FileMode.Open, FileAccess.Read))
        {
            var fileName = file.FullName.Substring(directoryPath.Length + 1);
            var options = new SqlScriptOptions()
            {
                ScriptType = ScriptType.RunOnce,
                RunGroupOrder = this.nextRunGroupOrder++
            };
            return SqlScript.FromStream(fileName, fileStream, encoding, options);
        }
    }

    private SearchOption ShouldSearchSubDirectories()
    {
        return options.IncludeSubDirectories ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;
    }
}
"@ -Language CSharp -ReferencedAssemblies $dllPaths
}

$configFunc = {
    param($configuration)
    $configuration.ScriptExecutor.ExecutionTimeoutSeconds = 0
}

function Write-Information {
    # Used to mock out logs in the tests
    param($message) Write-Host $message
}

function New-SchemaIfNotExists {
    # Work around for https://github.com/DbUp/DbUp/issues/346
    param($ConnectionString, $SchemaName)
    if ($SchemaName -eq 'dbo') {
        return
    }
    $query = "IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'$SchemaName') EXEC(N'CREATE SCHEMA [$SchemaName]')"
    # PowerShell versions makes Invoke-Sqlcmd with -ConnectionString unreliable.
    $connection = New-Object System.Data.SqlClient.SqlConnection -ArgumentList $ConnectionString
    $connection.Open()
    $cmd = New-Object System.Data.SqlClient.SqlCommand -ArgumentList $query, $connection
    $cmd.ExecuteNonQuery()
    $cmd.Dispose()
    $connection.Dispose()
}

[Action[string]]$infoDelegate = { param($message) Write-Information $message }

function Update-DatabaseWithDbUp {
    param(
        [Parameter(Mandatory = $true)][string]$ConnectionString,
        [string]$ScriptPath = '.',
        [ValidateSet('NullJournal', 'SqlTable')][string]$Journal = 'SqlTable',
        [string]$Filter = '.*',
        [string]$Encoding = "Default",
        [ValidateSet('NoTransactions', 'TransactionPerScript', 'SingleTransaction')]
        [string]$TransactionStrategy = 'TransactionPerScript',
        [string]$JournalSchemaName = 'dbo',
        [string]$JournalTableName = '_SchemaVersions',
        [ValidateSet('LogScriptOutput', 'Quiet')]
        [string]$Logging = 'Quiet',
        [ValidateSet('SearchAllFolders', 'SearchTopFolderOnly')]
        [string]$SearchMode = 'SearchTopFolderOnly',
        [ValidateSet('Filename', 'FilePath', 'FolderStructure')]
        [string]$Order = 'Filename',
        [bool]$VariableSubstitution = $false,
        [string]$VariableSubstitutionPrefix = "DbUp"
    )

    $filterFunc = {
        param([string]$file)
        return $file -match $Filter
    }
    $options = New-Object FileSystemScriptOptions
    $options.Filter = $filterFunc
    if ($Order -eq 'Filename') {
        $options.Order = 0
    }
    elseif ($Order -eq 'FilePath') {
        $options.Order = 1
    }
    else {
        $options.Order = 2
    }
    if ($SearchMode -eq 'SearchAllFolders') {
        $options.IncludeSubDirectories = $true
    }
    if ($Encoding -ne 'Default') {
        $options.Encoding = [System.Text.Encoding]::GetEncoding([int]::Parse($Encoding))
    }
    $scriptProvider = New-Object FileSystemScriptProvider -ArgumentList $ScriptPath, $options

    $ScriptPath = Resolve-Path $ScriptPath

    $dbUp = [DbUp.DeployChanges]::To
    $dbUp = [SqlServerExtensions]::SqlDatabase($dbUp, $ConnectionString)
    $dbUp = [StandardExtensions]::WithScripts($dbUp, $scriptProvider)
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
    if ($Logging -eq 'LogScriptOutput') {
        $dbUp = [StandardExtensions]::LogScriptOutput($dbUp)
    }
    if ($Journal -eq "NullJournal") {
        $dbUp = [StandardExtensions]::JournalTo($dbUp, (New-Object DbUp.Helpers.NullJournal))
    }
    else {
        New-SchemaIfNotExists -SchemaName $JournalSchemaName -ConnectionString $ConnectionString
        $dbUp = [SqlServerExtensions]::JournalToSqlTable($dbUp, $JournalSchemaName, $JournalTableName)
    }
    $dbUp.Configure($configFunc)
    if ($VariableSubstitution) {
        if (-not [string]::IsNullOrEmpty($VariableSubstitutionPrefix)) {
            $VariableSubstitutionPrefix += '_'
        }
        Get-ChildItem "env:\$VariableSubstitutionPrefix*" | ForEach-Object {
            $name = $_.Name.Substring($VariableSubstitutionPrefix.Length)
            $dbUp = [StandardExtensions]::WithVariable($dbUp, $name, $_.Value)
        }
    }
    else {
        $dbUp = [StandardExtensions]::WithVariablesDisabled($dbUp)
    }
    $result = $dbUp.Build().PerformUpgrade()
    if (!$result.Successful) {
        $errorMessage = ""
        if ($null -ne $result.Error) {
            $errorMessage = $result.Error.Message
        }
        Write-Information "##vso[task.logissue type=error;]Database migration failed. $errorMessage"
        Write-Information "##vso[task.complete result=Failed;]"
    }
    return $result.Successful
}

function New-DatabaseWithDbUp {
    param([string]$ConnectionString)
    $for = [DbUp.EnsureDatabase]::For
    [SqlServerExtensions]::SqlDatabase($for, $ConnectionString, (New-Object VstsUpgradeLog $infoDelegate))
}
