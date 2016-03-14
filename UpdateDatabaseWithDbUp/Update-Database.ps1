param([string]$ConnectionString,
      [string]$ScriptPath,
      [string]$JournalToSqlTable,
      [string]$ScriptFileFilter)

$Journal = 'NullJournal'
if ($JournalToSqlTable -eq [bool]::TrueString) {
    $Journal = 'SqlTable'
}

.\Update-DatabaseWithDbUp.ps1 -ConnectionString $ConnectionString -ScriptPath $ScriptPath -Journal $Journal -Filter $ScriptFileFilter