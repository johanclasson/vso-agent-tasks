$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\..\task\$sut"

$databasename = 'UpdateDatabaseWithDbUpTests'
$connectionString = "Server=.;Database=$databasename;Trusted_Connection=True;"
$logFilePath = "TestDrive:\Log.txt"

function New-Database {
    Mock Write-Information {
        $message | Out-File -FilePath $logFilePath -Append -Encoding ascii
    }
    New-DatabaseWithDbUp -ConnectionString $connectionString
}

function Remove-Datbase {
    Invoke-Sqlcmd -ServerInstance . -Database 'Master' -Query "alter database [$databasename] set single_user with rollback immediate"
    Invoke-Sqlcmd -ServerInstance . -Database 'Master' -Query "drop database [$databasename]"
}

function Assert-Data {
    param($ExpectedEntries, $PropertyName, $TableName)
    $data = @(Invoke-TestSql "select * from $TableName")
    $data.Length | Should Be @($ExpectedEntries).Length
    $dataValues = $data | Select-Object -ExpandProperty $PropertyName
    for ($i = 0; $i -lt $data.Length; $i++) {
        $dataValues[$i] | Should Be $ExpectedEntries[$i]
    }
}

function Assert-Persons {
    param($ExpectedPersons)
    Assert-Data -ExpectedEntries $ExpectedPersons -PropertyName 'Name' -TableName 'Person'
}

function Assert-Jornal {
    param($ExpectedScripts, $TableName)
    Assert-Data -ExpectedEntries $ExpectedScripts -PropertyName 'ScriptName' -TableName $TableName
}

function Invoke-TestSql {
    param($Query)
    return Invoke-Sqlcmd -ServerInstance . -Database $databasename -Query $Query
}

function Write-LogContentToHost {
    Get-Content $logFilePath | ForEach-Object{ Write-Host $_ }
}

function Clear-LogContent {
    if (Test-Path $logFilePath) {
        Remove-Item $logFilePath
    }
}

Describe 'update database searching and filtering top folder only' {
    BeforeAll {
        New-Database
        $result = Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'good'
    }
    It 'should complete successfully' {
        $result | Should Be $true
    }
    It 'should contain the expected data' {
        Assert-Persons 'John'
    }
    It 'should jornal to the default table' {
        Assert-Jornal '02-table-good.sql','03-data-good.sql' '_SchemaVersions'
    }
    AfterAll {
        Remove-Datbase
    }
}

Describe 'update database with variable substitution' {
    BeforeAll {
        New-Database
    }
    function Invoke-Upgrade {
        param($Prefix = "")
        Clear-LogContent # This is to fix some fishy behavior that the TestDrive is not reset for each context
        return Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'variable' -VariableSubstitution $true -Logging LogScriptOutput -VariableSubstitutionPrefix $Prefix -Journal NullJournal
    }
    Context 'without any environment variables' {
        BeforeAll {
            $result = Invoke-Upgrade
        }
        It 'should fail' {
            $result | Should Be $false
        }
    }
    Context 'with environment variable and no prefix' {
        BeforeAll {
            $env:TESTVARIABLE = 'MyTestValue'
            $result = Invoke-Upgrade
            Remove-Item env:\TESTVARIABLE
        }
        It 'should complete successfully' {
            $result | Should Be $true
        }
        It 'should log print statements' {
            $logFilePath | Should Contain 'MyTestValue'
        }
    }
    Context 'with environment variable and prefix' {
        BeforeAll {
            $env:MYPREFIX_TESTVARIABLE = 'MyTestValue'
            $result = Invoke-Upgrade -Prefix 'MyPrefix'
            Remove-Item env:\MYPREFIX_TESTVARIABLE
        }
        It 'should complete successfully' {
            $result | Should Be $true
        }
        It 'should log print statements' {
            $logFilePath | Should Contain 'MyTestValue'
        }
    }
    Context 'with environmentvariable with the wrong prefix' {
        BeforeAll {
            $env:TESTVARIABLE = 'MyTestValue'
            $env:MyWrongPrefix_TESTVARIABLE = 'MyTestValue'
            $result = Invoke-Upgrade -Prefix 'MyPrefix'
            Remove-Item env:\TestVariable
            Remove-Item env:\MyWrongPrefix_TestVariable
        }
        It 'should fail' {
            $result | Should Be $false
        }
    }
    AfterAll {
        Remove-Datbase
    }
}

Describe 'update database searching all folders ordering by filename' {
    BeforeAll {
        New-Database
        $result = Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\hierarchy" -SearchMode SearchAllFolders -Order Filename
    }
    It 'should complete successfully' {
        $result | Should Be $true
    }
    It 'should jornal to the default table' {
        Assert-Jornal '01-table-good.sql','04\02-data-good.sql','03-data-good.sql','02\04-data-good.sql','05-data-good.sql' '_SchemaVersions'
    }
    AfterAll {
        Remove-Datbase
    }
}

Describe 'update database searching all folders ordering by file path' {
    BeforeAll {
        New-Database
        $result = Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\hierarchy" -SearchMode SearchAllFolders -Order FilePath
    }
    It 'should complete successfully' {
        $result | Should Be $true
    }
    It 'should jornal to the default table' {
        Assert-Jornal '01-table-good.sql','02\04-data-good.sql','03-data-good.sql','04\02-data-good.sql','05-data-good.sql' '_SchemaVersions'
    }
    AfterAll {
        Remove-Datbase
    }
}

Describe 'update database searching all folders ordering by folder structure' {
    BeforeAll {
        New-Database
        $result = Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\hierarchy" -SearchMode SearchAllFolders -Order FolderStructure
    }
    It 'should complete successfully' {
        $result | Should Be $true
    }
    It 'should jornal to the default table' {
        Assert-Jornal '01-table-good.sql','03-data-good.sql','05-data-good.sql','02\04-data-good.sql','04\02-data-good.sql' '_SchemaVersions'
    }
    AfterAll {
        Remove-Datbase
    }
}

Describe 'update database with different paths' {
    BeforeEach {
        New-Database
    }
    function Assert-ScriptPathCompatibility {
        param($ScriptPath)
        $result = Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath $scriptPath -SearchMode SearchAllFolders
        $result | Should Be $true
        Assert-Jornal '01-table-good.sql','04\02-data-good.sql','03-data-good.sql','02\04-data-good.sql','05-data-good.sql' '_SchemaVersions'
    }
    Context 'without trailing backslash' {
        It 'should work' {
            Assert-ScriptPathCompatibility "$here\sql\hierarchy"
        }
    }
    Context 'with trailing backslash' {
        It 'should work' {
            Assert-ScriptPathCompatibility "$here\sql\hierarchy\"
        }
    }
    Context 'without trailing slash' {
        It 'should work' {
            Assert-ScriptPathCompatibility ("$here\sql\hierarchy".Replace('\','/'))
        }
    }
    Context 'with trailing slash' {
        It 'should work' {
            Assert-ScriptPathCompatibility ("$here\sql\hierarchy\".Replace('\','/'))
        }
    }
    AfterEach {
        Remove-Datbase
    }
}

Describe 'the transaction strategy transaction per script with bad data' {
    BeforeAll {
        New-Database
        $result = Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'good|bad' -TransactionStrategy TransactionPerScript
    }
    It 'should fail' {
        $result | Should Be $false
    }
    It 'should contain the expected data' {
        Assert-Persons 'John'
    }
    It 'should jornal the successful scripts' {
        Assert-Jornal '02-table-good.sql', '03-data-good.sql' '_SchemaVersions'
    }
    AfterAll {
        Remove-Datbase
    }
}

Describe 'the transaction strategy no transactions with bad data' {
    BeforeAll {
        New-Database
        $result = Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'good|bad' -TransactionStrategy NoTransactions
    }
    It 'should fail' {
        $result | Should Be $false
    }
    It 'should contain the expected data' {
        Assert-Persons 'John','Doe'
    }
    It 'should jornal the successful scripts' {
        Assert-Jornal '02-table-good.sql', '03-data-good.sql' '_SchemaVersions'
    }
    AfterAll {
        Remove-Datbase
    }
}

Describe 'the transaction strategy single transaction with bad data' {
    BeforeAll {
        New-Database
        Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'nothing' -TransactionStrategy SingleTransaction # Need one successful transaction so that the journal table is created
        $result = Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'good|bad' -TransactionStrategy SingleTransaction
    }
    It 'should fail' {
        $result | Should Be $false
    }
    It 'should jornal the successful scripts' {
        Assert-Jornal '01-nothing.sql' '_SchemaVersions'
    }
    AfterAll {
        Remove-Datbase
    }
}

Describe 'custom journal name' {
    BeforeAll {
        New-Database
        $result = Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'good' -JournalName 'Migrations'
    }
    It 'should jornal to the custom table' {
        Assert-Jornal '02-table-good.sql','03-data-good.sql' 'Migrations'
    }
    AfterAll {
        Remove-Datbase
    }
}

Describe 'null journal' {
    BeforeAll {
        New-Database
        Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'table-good'
        Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'data-good' -Journal NullJournal
        Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'data-good' -Journal NullJournal
    }
    It 'should contain the expected data' {
        Assert-Persons 'John','John'
    }
    It 'should jornal to the default table' {
        Assert-Jornal '02-table-good.sql' '_SchemaVersions'
    }
    AfterAll {
        Remove-Datbase
    }
}

Describe 'logging with script output' {
    BeforeAll {
        New-Database
        Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'log' -Logging LogScriptOutput
    }
    It 'should log output from New-DatabaseWithDbUp' {
        $logFilePath | Should Contain 'Created database UpdateDatabaseWithDbUpTests'
    }
    It 'should log print statements' {
        $logFilePath | Should Contain 'MyPrint'
    }
    It 'should not contain any empty rows' {
        Get-Content $logFilePath | ForEach-Object { [string]::IsNullOrWhiteSpace($_) | Should Be $false }
    }
    It 'should log errors' {
        $logFilePath | Should Contain ([regex]::Escape('##vso[task.logissue type=error;]System.Data.SqlClient.SqlException (0x80131904): MyError'))
        $logFilePath | Should Contain ([regex]::Escape('##vso[task.logissue type=error;]Database migration failed. MyError'))
    }
    It 'should fail build on error' {
        $logFilePath | Should Contain ([regex]::Escape('##vso[task.complete result=Failed;]'))
    }
    # It seams to be impossible to invoke the DbUp.Engine.Output.IUpgradeLog.WriteWarning method! Hence it is left untested.
    AfterAll {
        Remove-Datbase
    }
}

Describe 'logging without script output' {
    BeforeAll {
        New-Database
        Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'log'
    }
    It 'should not log print statements' {
        $logFilePath | Should Not Contain 'MyPrint'
    }
    It 'should log errors' {
        $logFilePath | Should Contain ([regex]::Escape('##vso[task.logissue type=error;]System.Data.SqlClient.SqlException (0x80131904): MyError'))
        $logFilePath | Should Contain ([regex]::Escape('##vso[task.logissue type=error;]Database migration failed. MyError'))
    }
    AfterAll {
        Remove-Datbase
    }
}

Describe 'long running scripts' -Tag 'LongRunning' {
    BeforeAll {
        New-Database
        $result = Update-DatabaseWithDbUp -ConnectionString $connectionString -ScriptPath "$here\sql\flat" -Filter 'longrunning'
    }
    It 'should complete successfully' {
        $result | Should Be $true
    }
    AfterAll {
        Remove-Datbase
    }
}

Describe 'installing DbUp' -Tag 'LongRunning' {
    BeforeAll {
        $nuget = Get-Command "nuget.exe" -ErrorAction SilentlyContinue
        $nuget | Should Be $null # To run these tests, you are not allowed to have nuget.exe in your path.
        Mock Get-TempDir { return 'TestDrive:\Temp' }
        $oldPath = $env:Path
    }
    Describe 'when NuGet is not present' {
        BeforeAll {
            $path = Install-DbUpAndGetDllPath
        }
        It 'should install DbUp' {
            $path.EndsWith('\DbUp.dll') | Should Be $true
        }
        It 'should remove the downloaded nuget.exe' {
            Test-Path 'TestDrive:\Temp\DatabaseMigration\nuget.exe' | Should Be $false
        }
    }
    Describe 'when NuGet is present in PATH' {
        BeforeAll {
            $localNugetDirPath = "$TestDrive\NuGet"
            New-Item $localNugetDirPath -Type Directory | Out-Null
            $localNugetPath = Join-Path $localNugetDirPath 'nuget.exe'
            Invoke-WebRequest https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile $localNugetPath -UseBasicParsing
            $env:Path = "$($env:Path)$localNugetDirPath;"
            Mock Invoke-WebRequest { throw 'Invoke-WebRequest should not be called!' }
            $path = Install-DbUpAndGetDllPath
        }
        It 'should install DbUp' {
            $path.EndsWith('\DbUp.dll') | Should Be $true
        }
        It 'should not download NuGet' {
            Assert-MockCalled Invoke-WebRequest -Times 0 -Exactly
        }
    }
    AfterAll {
        $env:Path = $oldPath
    }
}
