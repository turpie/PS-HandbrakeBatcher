param(
    [Parameter(ValueFromRemainingArguments = $true)]
    $FilePath
)
$QueuePath = "C:\Scripts\HandBrakeBatcher\Queue"

$FilePath | ForEach-Object{
    $FileToQueue = $_
    Write-Host "Queueing:" $FileToQueue
    #$FileToQueue | Out-File -FilePath (Join-Path -Path $QueuePath -ChildPath (Split-Path -Path $FileToQueue -Leaf))
    # Filenames were containing wildcards that Out-File complained about, using GUID for filename instead.
    $FileToQueue | Out-File -FilePath (Join-Path -Path $QueuePath -ChildPath (New-Guid))
}

#Pause 