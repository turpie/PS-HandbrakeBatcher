.\Update-HandbrakeCLI.ps1 # Update HandbrakeCLI before processing.

Import-Module -Name Get-MediaInfo

$QueuePath = "C:\Scripts\HandBrakeBatcher\Queue"
$QueueRejectsPath = "C:\Scripts\HandBrakeBatcher\QueueRejects"
$LogPath = "C:\Scripts\HandBrakeBatcher\Logs"
$DestinationPath = "D:\Conversions"
$HandBrakeExe = "C:\Scripts\HandBrakeBatcher\HandBrakeCLI\HandBrakeCLI.exe"

# Original H264 profile
#$PresetFile = "C:\Scripts\HandBrakeBatcher\HandbrakePreset.json"
#$PresetName = "CustomFast1080p30"

# Newer H265/HEVC profile
$PresetFile = "C:\Scripts\HandBrakeBatcher\H265HandbrakePreset.json"
$PresetFileNight = "C:\Scripts\HandBrakeBatcher\H265HandbrakePresetNight.json"
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
Write-Host "   Process-HandbrakeBatcher by Paul Turpie" $PSCommandPath
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
    #TODO Validate the destination file before removing queuefile
    #      maybe move queuefile to a new directory
    if(Test-Path -Path $DestinationFile) {
        $MediaInfo = Get-MediaInfo -Path $DestinationFile
        if( $MediaInfo.Duration -gt 0){
            # Destination File exists and seems to be a valid video file, so delete the queue file.
            Add-Content -Path (Join-Path -Path $LogPath -ChildPath "Completed.log") -Value (Get-Content -Path $FileList[0].FullName)
        }else{
            # Destination file seems invalid so delete it and keep queue file to try again later.
            Remove-Item $DestinationFile
        }
    }
    # Check current time and run the Night profile for higher performance
    $currentTime = Get-Date
    if(($currentTime.Hour -ge 23) -or ($currentTime.Hour -le 7)){
        &$HandBrakeExe --preset-import-file $PresetFileNight -Z $PresetName -i "$SourceFile" -o "$DestinationFile" 2>(Join-Path -Path $LogPath -ChildPath "Error.log") | Get-HandbrakeProgress

    }else {
        &$HandBrakeExe --preset-import-file $PresetFile -Z $PresetName -i "$SourceFile" -o "$DestinationFile" 2>(Join-Path -Path $LogPath -ChildPath "Error.log") | Get-HandbrakeProgress
    }

    #TODO Validate the destination file before removing queuefile
    #      maybe move queuefile to a new directory
    if(Test-Path -Path $DestinationFile) {
        $MediaInfo = Get-MediaInfo -Path $DestinationFile
        if( $MediaInfo.Duration -gt 0){
            # Destination File exists and seems to be a valid video file, so delete the queue file.
            Add-Content -Path (Join-Path -Path $LogPath -ChildPath "Completed.log") -Value (Get-Content -Path $FileList[0].FullName)
            Write-Host "Processing completed, removing queue file."
            Remove-Item $FileList[0].FullName
        }else{
            # Destination file seems invalid so delete it and keep queue file to try again later.
            Write-Host "Destination file seems invalid so delete it and keep queue file to try again later."
            Write-Host "  DestinationFile name=" $DestinationFile
            Write-Host "  Queue filename: " $FileList[0].FullName
            Write-Host "  Original Lastwritetime:" (Get-Item -Path $FileList[0].FullName).LastWriteTime
            Remove-Item $DestinationFile
            (Get-Item -Path $FileList[0].FullName).LastWriteTime = Get-Date
            Write-Host "  New Lastwritetime:" (Get-Item -Path $FileList[0].FullName).LastWriteTime
            Move-Item -Path $FileList[0].FullName -Destination $QueueRejectsPath
        }
    }else{
        Write-Host "************* where did the destination file go!!!!!!!!!!!!!!!!!!!! *************"
        Write-Host "  DestinationFile name=" $DestinationFile
        Write-Host "  Queue filename: " $FileList[0].FullName
        Write-Host "  Original Lastwritetime:" (Get-Item -Path $FileList[0].FullName).LastWriteTime
        (Get-Item -Path $FileList[0].FullName).LastWriteTime = Get-Date
        Write-Host "  New Lastwritetime:" (Get-Item -Path $FileList[0].FullName).LastWriteTime
        Move-Item -Path $FileList[0].FullName -Destination $QueueRejectsPath
}
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