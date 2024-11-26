#(Get-Item "c:\Scripts\HandBrakeBatcher\Queue\4AFC20E8F05F38A1EF0F383CE3D4C4723CF13BC64B63E790F82D9E62C4DCC676").LastWriteTime=("3 August 2019 17:10:00")

$QueueFiles = Get-ChildItem -Path "c:\Scripts\HandBrakeBatcher\Queue\"

$QueueFiles | ForEach-Object {
    #$lastAccess = (Get-Item -Path $_.VersionInfo.FileName).LastWriteTime
    #$lastAccess.AddDays(1)
    (Get-Item -path  $QueueFiles[0].VersionInfo.FileName).LastAccessTime=("23 August 2024 17:10:00")
}