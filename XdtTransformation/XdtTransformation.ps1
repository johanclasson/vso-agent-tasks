param([string]$Root, [string]$Configuration)

$Pattern = "*.$Configuration.*"
gci $Root -Filter $Pattern -Recurse | %{
    # Transform
    $target = $_.FullName -replace ".$Configuration.","."
    $transform = $_.FullName
    Invoke-Expression "$(gi .\ctt.exe) s:$target t:$transform d:$target pw v"
    if ($LASTEXITCODE -ne 0){
        Write-Error "Something bad happened ($LASTEXITCODE)"
        exit -1
    }

    # Delete tranforms
    $removePattern = $_.FullName -replace ".$Configuration.",".*."
    rm $removePattern
}
exit 0