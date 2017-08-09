param([string]$ConnectionString,
      [string]$ScriptPath,
      [string]$JournalToSqlTable,
      [string]$JournalName,
      [string]$ScriptFileFilter,
      [string]$TransactionStrategy,
      [string]$LogScriptOutput,
      [string]$SearchTopDirectoryOnly,
      [string]$Order)

$journal = 'NullJournal'
if ($JournalToSqlTable -eq [bool]::TrueString) {
    $journal = 'SqlTable'
}
$logging = 'Quiet'
if ($LogScriptOutput -eq [bool]::TrueString) {
    $logging = 'LogScriptOutput'
}
$searchMode = 'SearchAllDirectories'
if ($SearchTopDirectoryOnly -eq [bool]::TrueString) {
    $searchMode = 'SearchTopDirectoryOnly'
}

. .\Update-DatabaseWithDbUp.ps1 
$success = Update-DatabaseWithDbUp -ConnectionString $ConnectionString -ScriptPath $ScriptPath -Journal $journal -JournalName $JournalName -Filter $ScriptFileFilter -TransactionStrategy $TransactionStrategy -Logging $logging -SearchMode $searchMode -Order $Order
if (-not $success) {
    exit -1
}