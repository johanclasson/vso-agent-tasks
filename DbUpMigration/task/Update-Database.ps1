$connectionString = Get-VstsInput -Name ConnectionString -Require
$scriptPath = Get-VstsInput -Name ScriptPath -Require
$journalToSqlTable = Get-VstsInput -Name JournalToSqlTable -AsBool
$journalSchemaName = Get-VstsInput -Name JournalSchemaName -Require
$journalTableName = Get-VstsInput -Name JournalTableName -Require
$scriptFileFilter = Get-VstsInput -Name ScriptFileFilter -Require
$scriptEncoding = Get-VstsInput -Name ScriptEncoding -Require
$transactionStrategy = Get-VstsInput -Name TransactionStrategy -Require
$logScriptOutput = Get-VstsInput -Name LogScriptOutput -AsBool
$includeSubfolders = Get-VstsInput -Name IncludeSubfolders -AsBool
$order = Get-VstsInput -Name Order -Require
$variableSubstitution = Get-VstsInput -Name VariableSubstitution -AsBool
$variableSubstitutionPrefix = Get-VstsInput -Name VariableSubstitutionPrefix -Require

$journal = 'NullJournal'
if ($journalToSqlTable) {
    $journal = 'SqlTable'
}
$logging = 'Quiet'
if ($logScriptOutput) {
    $logging = 'LogScriptOutput'
}
$searchMode = 'SearchTopFolderOnly'
if ($includeSubfolders) {
    $searchMode = 'SearchAllFolders'
}
$encoding = $scriptEncoding.Split("-")[1]

. "$PSScriptRoot\Update-DatabaseWithDbUp.ps1" 
$success = Update-DatabaseWithDbUp `
    -ConnectionString $connectionString `
    -ScriptPath $scriptPath `
    -Journal $journal `
    -JournalSchemaName $journalSchemaName `
    -JournalTableName $journalTableName `
    -Filter $scriptFileFilter `
    -Encoding $encoding `
    -TransactionStrategy $transactionStrategy `
    -Logging $logging `
    -SearchMode $searchMode `
    -Order $order `
    -VariableSubstitution $variableSubstitution `
    -VariableSubstitutionPrefix $variableSubstitutionPrefix
if (-not $success) {
    exit -1
}
