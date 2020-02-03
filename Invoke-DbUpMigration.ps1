function Set-VstsInput {
    param($Name, $Value)

    $envVarName = ($Name -replace '\.', '_').ToUpper()
    New-Item "env:\INPUT_$envVarName" -Value $Value -Force
}

function Set-VstsTaskVariable {
    param($Name, $Value)

    $envVarName = ($Name -replace '\.', '_').ToUpper()
    New-Item "env:\$envVarName" -Value $Value -Force
}

# sqllocaldb c UpdateDatabaseWithDbUpTests | Out-Null
Import-Module "$PSScriptRoot\ps_modules\VstsTaskSdk"

Set-VstsTaskVariable 'System_Culture' 'en-us'

Set-VstsInput 'ConnectionString' 'Server=(localdb)\UpdateDatabaseWithDbUpTests;Database=UpdateDatabaseWithDbUpTests;Integrated Security=true'
Set-VstsInput 'ScriptPath' "$PSScriptRoot\DbUpMigration\test\sql\hierarchy"
Set-VstsInput 'JournalToSqlTable' 'True'
Set-VstsInput 'JournalSchemaName' 'dbo'
Set-VstsInput 'JournalTableName' '_SchemaVersions'
Set-VstsInput 'ScriptFileFilter' '.*'
Set-VstsInput 'ScriptEncoding' '001-Default'
Set-VstsInput 'TransactionStrategy' 'TransactionPerScript'
Set-VstsInput 'LogScriptOutput' 'True'
Set-VstsInput 'IncludeSubfolders' 'True'
Set-VstsInput 'Order' 'FilePath'
Set-VstsInput 'VariableSubstitution' 'False'
Set-VstsInput 'VariableSubstitutionPrefix' 'DbUp'

Invoke-VstsTaskScript -ScriptBlock { . .\DbUpMigration\task\Update-Database.ps1 }

Set-VstsInput 'ScriptPath' "$PSScriptRoot\DbUpMigration\test\sql\flat"
Set-VstsInput 'JournalToSqlTable' 'False'
Set-VstsInput 'ScriptFileFilter' '.*variable.*'
Set-VstsInput 'VariableSubstitution' 'True'

New-Item env:\DBUP_TESTVARIABLE -Value 'FooBar' -Force

Invoke-VstsTaskScript -ScriptBlock { . .\DbUpMigration\task\Update-Database.ps1 }
