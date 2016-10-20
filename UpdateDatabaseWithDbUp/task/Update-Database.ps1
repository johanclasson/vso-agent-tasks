param([string]$ConnectionString,
      [string]$ScriptPath,
      [string]$JournalToSqlTable,
      [string]$ScriptFileFilter)

$Journal = 'NullJournal'
if ($JournalToSqlTable -eq [bool]::TrueString) {
    $Journal = 'SqlTable'
}

Write-Host "ConnectionString: $ConnectionString"
Write-Host "ScriptPath: $ScriptPath"
Write-Host "Journal: $Journal"
Write-Host "ScriptFileFilter: $ScriptFileFilter"

.\Update-DatabaseWithDbUp.ps1 -ConnectionString $ConnectionString -ScriptPath $ScriptPath -Journal $Journal -Filter $ScriptFileFilter