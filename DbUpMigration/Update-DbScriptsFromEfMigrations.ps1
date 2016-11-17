$sqlDir = "C:\git\EnklaEtjanster\EnklaEtjanster.Cms\SQL"
$configurationType = "TSPDF.Core.Persistence.Migrations.Configuration"
$dllPath = "C:\git\EnklaEtjanster\EnklaEtjanster.Cms\TSPDF.Core.Persistence\bin\Debug\TSPDF.Core.Persistence.dll"

$dll = gi $dllPath

$oldLocation = Get-Location
cd $dll.Directory.FullName

if (-not(Test-Path $sqlDir)) {
    ni $sqlDir -ItemType Directory | Out-Null
}

Add-Type -Path $dll.Name
$config = New-Object $configurationType
Write-Host "Creating migrator..."
$migrator = New-Object System.Data.Entity.Migrations.DbMigrator $config
Write-Host "Done"
$scriptor = New-Object System.Data.Entity.Migrations.Infrastructure.MigratorScriptingDecorator $migrator
$migrations = $scriptor.GetLocalMigrations()
$lastRunMigration = ""
$migrations | %{
    $path = Join-Path $sqlDir "$_.sql"
    $text = $scriptor.ScriptUpdate($lastRunMigration, $_)
    $text | Out-File $path -Encoding ascii
    $lastRunMigration = $_
    Write-Host "Updated content of $path"
}
Set-Location $oldLocation
