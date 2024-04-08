param(
    [Parameter(ValueFromRemainingArguments = $true)]
    $FilePath
)
$QueuePath = "C:\Scripts\HandBrakeBatcher\Queue"

$FilePath | ForEach-Object{
    $FileToQueue = $_
    Write-Host "Queueing:" $FileToQueue
    #$FileToQueue | Out-File -FilePath (Join-Path -Path $QueuePath -ChildPath (Split-Path -Path $FileToQueue -Leaf))
    # Filenames were containing wildcards that Out-File complained about, using hash of filename instead.
    $HashedFilename = (Get-FileHash -InputStream ([IO.MemoryStream]::new([byte[]][char[]]$FileToQueue)) -Algorithm SHA256).Hash
    $FileToQueue | Out-File -FilePath (Join-Path -Path $QueuePath -ChildPath $HashedFilename)
}

Pause 