param([string]$ConnectionString,
      [string]$ScriptPath,
      [string]$JournalToSqlTable,
      [string]$ScriptFileFilter,
      [string]$TransactionStrategy)

$Journal = 'NullJournal'
if ($JournalToSqlTable -eq [bool]::TrueString) {
    $Journal = 'SqlTable'
}

Write-Host "ConnectionString: $ConnectionString"
Write-Host "ScriptPath: $ScriptPath"
Write-Host "Journal: $Journal"
Write-Host "ScriptFileFilter: $ScriptFileFilter"
Write-Host "TransactionStrategy: $TransactionStrategy"

.\Update-DatabaseWithDbUp.ps1 -ConnectionString $ConnectionString -ScriptPath $ScriptPath -Journal $Journal -Filter $ScriptFileFilter -TransactionStrategy $TransactionStrategy