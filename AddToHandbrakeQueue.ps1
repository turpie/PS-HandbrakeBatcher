param(
    [Parameter(ValueFromRemainingArguments = $true)]
    $FilePath
)
# The script is designed to be called from the context menu of a file or folder. It will queue the file or all video files in the folder for processing by Handbrake. 


$QueuePath = "C:\Scripts\HandBrakeBatcher\Queue"

$FilePath

function Queue-File {
    param (
        #filename to queue
        [string]$FileToQueue
    )
    Write-Host "Queueing:" $FileToQueue
    #$FileToQueue | Out-File -FilePath (Join-Path -Path $QueuePath -ChildPath (Split-Path -Path $FileToQueue -Leaf))
    # Filenames were containing wildcards that Out-File complained about, using hash of filename instead.
    $HashedFilename = (Get-FileHash -InputStream ([IO.MemoryStream]::new([byte[]][char[]]$FileToQueue)) -Algorithm SHA256).Hash
    $FileToQueue | Out-File -FilePath (Join-Path -Path $QueuePath -ChildPath $HashedFilename)
    
}

$videoExtensions = @(".mp4", ".mkv", ".avi", ".mov", ".wmv")      
$FilePath | ForEach-Object{
    # if the file is a directory, queue all files in the directory
    if (Test-Path -Path $_ -PathType Container) {
        # only queue video files
        Get-ChildItem -Path $_ -Recurse -File | Where-Object { $videoExtensions -contains $_.Extension } | ForEach-Object {
            Queue-File -FileToQueue $_.FullName
        }
    }
    else {
        if ($videoExtensions -contains (Get-Item $_).Extension) {
            Queue-File -FileToQueue $_
        }
    }
} 
