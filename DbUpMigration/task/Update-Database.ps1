param([string]$ConnectionString,
      [string]$ScriptPath,
      [string]$JournalToSqlTable,
      [string]$JournalName,
      [string]$ScriptFileFilter,
      [string]$ScriptEncoding,
      [string]$TransactionStrategy,
      [string]$LogScriptOutput,
      [string]$IncludeSubfolders,
      [string]$Order,
      [string]$VariableSubstitution,
      [string]$VariableSubstitutionPrefix)

$journal = 'NullJournal'
if ($JournalToSqlTable -eq [bool]::TrueString) {
    $journal = 'SqlTable'
}
$logging = 'Quiet'
if ($LogScriptOutput -eq [bool]::TrueString) {
    $logging = 'LogScriptOutput'
}
$searchMode = 'SearchTopFolderOnly'
if ($IncludeSubfolders -eq [bool]::TrueString) {
    $searchMode = 'SearchAllFolders'
}
$variableSubstitutionValue = $VariableSubstitution -eq [bool]::TrueString
$encoding = $ScriptEncoding.Split("-")[1]

. .\Update-DatabaseWithDbUp.ps1 
$success = Update-DatabaseWithDbUp -ConnectionString $ConnectionString -ScriptPath $ScriptPath -Journal $journal -JournalName $JournalName -Filter $ScriptFileFilter -Encoding $encoding -TransactionStrategy $TransactionStrategy -Logging $logging -SearchMode $searchMode -Order $Order -VariableSubstitution $variableSubstitutionValue -VariableSubstitutionPrefix $VariableSubstitutionPrefix
if (-not $success) {
    exit -1
}
