.\Update-HandbrakeCLI.ps1 # Update HandbrakeCLI before processing.

$QueuePath = "C:\Scripts\HandBrakeBatcher\Queue"
$LogPath = "C:\Scripts\HandBrakeBatcher\Logs"
$DestinationPath = "D:\Conversions"
$HandBrakeExe = "C:\Scripts\HandBrakeBatcher\HandBrakeCLI\HandBrakeCLI.exe"

# Original H264 profile
#$PresetFile = "C:\Scripts\HandBrakeBatcher\HandbrakePreset.json"
#$PresetName = "CustomFast1080p30"

# Newer H265/HEVC profile
$PresetFile = "C:\Scripts\HandBrakeBatcher\H265HandbrakePreset.json"
$PresetName = "Apple1080pHEVCq38"

Function Get-HandbrakeProgress {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $InputObject
    )
    begin {
        [string]$status = ''
        [double]$percent = 0
        [double]$fps = 0
        [string]$ETA = ''
    }
    process {
        $Host.PrivateData.ProgressBackgroundColor = 'Cyan' 
        $Host.PrivateData.ProgressForegroundColor = 'Black'
    
        $data = $InputObject -split ' '
    
        If (![String]::IsNullOrEmpty("$($data[0])")) {
            $status = ($data[0]).Split(':')[0]
        }
        If (![String]::IsNullOrEmpty("$($data[5])")) {
            $percent = $data[5]
        }
        If (![String]::IsNullOrEmpty("$($data[10])")) {
            $fps = $data[10]
        }
        If (![String]::IsNullOrEmpty("$($data[13])")) {
            $ETA = ($data[13]).Split(')')[0]
        }
    
        Write-Progress -Id 1 -Activity "   Currently $status $SourceFile"`
            -Status "ETA: $ETA   Complete: $percent%    $fps fps"`
            -PercentComplete $percent
    }
}


$filecount = 0
$FileList = Get-ChildItem -Path $QueuePath | Sort-Object LastWriteTime


Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host "*******************************************************************************"
Write-Host "  Starting Handbrake Batch Encoding"
Write-Host "   Process-HandbrakeBatcher by Paul Turpie"
Write-Host "   $($FileList.Count) files to be processed"
Write-Host "*******************************************************************************"

while ($null -ne $FileList) {
    $FileToProcess = Get-ChildItem -LiteralPath (Get-Content $FileList[0].FullName)
    $totalFiles = $filecount + $FileList.Count
    $filecount++

    $SourceFile = $FileToProcess.FullName
    $DestinationFile = (Join-Path -Path $DestinationPath -ChildPath ($FileToProcess.BaseName)) + ".mp4"

    Write-Progress -Id 0 -Activity "Handbrake Batch Video Conversion in Progress" -Status "Processed $filecount of $totalFiles" -PercentComplete ($filecount / $totalFiles * 100)
    Write-Host "-------------------------------------------------------------------------------"
    Write-Host "  Queue file: " $FileList[0]
    Write-Host "  Processing - $SourceFile"
    Write-Host "   to        - $DestinationFile"
    Write-Host "Processed $filecount files"
    Write-Host "          $($FileList.Count - 1) files remaining"
    Write-Host "-------------------------------------------------------------------------------"

    &$HandBrakeExe --preset-import-file $PresetFile -Z $PresetName -i "$SourceFile" -o "$DestinationFile" 2>(Join-Path -Path $LogPath -ChildPath "Error.log") | Get-HandbrakeProgress

    Remove-Item $FileList[0].FullName
    # Refresh the FileList incase more files have been queued.
    $FileList = Get-ChildItem -Path $QueuePath | Sort-Object LastWriteTime
}

Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host "*******************************************************************************"
Write-Host "  Completed Handbrake Batch Encoding"
Write-Host "   Process-HandbrakeBatcher by Paul Turpie"
Write-Host "   $($totalFiles) files were processed"
Write-Host "*******************************************************************************"

Pause