$ErrorActionPreference = "Stop"

function Remove-ItemRecursiveIfExists($Path) {
    if ((Test-Path $Path)) {
        Write-Host "Removing $Path..."
        Remove-Item $Path -Recurse -Force
    }
}

Remove-ItemRecursiveIfExists -Path .\ps_modules\VstsTaskSdk
New-Item .\ps_modules -ItemType Directory | Out-Null
Write-Host "Downloading VstsTaskSdk..."
Save-Module -Name VstsTaskSdk -Path .\ps_modules\

'DbUpMigration\task' |
    ForEach-Object {
        Remove-ItemRecursiveIfExists -Path .\$_\ps_modules
        New-Item .\$_\ps_modules -ItemType Directory | Out-Null
        Write-Host "Copying .\$_\ps_modules\VstsTaskSdk..."
        Copy-Item -Recurse .\ps_modules\VstsTaskSdk\0.11.0 ".\$_\ps_modules\VstsTaskSdk"
    }
