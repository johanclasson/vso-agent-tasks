param(
    [string]$Root,
    [string]$Configuration,
    [string]$CttPath = ".\ctt.exe")

$ErrorActionPreference = 'Stop'

$Pattern = "*.$Configuration.*"
gci $Root -Filter $Pattern -Recurse | %{
    # Transform
    $target = $_.FullName -replace ".$Configuration.","."
    $transform = $_.FullName
    $ctt = gi $CttPath
    Invoke-Expression "$ctt s:""$target"" t:""$transform"" d:""$target"" pw v"
    if ($LASTEXITCODE -ne 0){
        Write-Error "Something bad happened ($LASTEXITCODE)"
        exit -1
    }

    # Delete transforms
    $removePattern = $_.FullName -replace ".$Configuration.",".*."
    rm $removePattern
}
exit 0
