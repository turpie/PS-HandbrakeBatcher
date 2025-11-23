param(
    [ValidateSet("Sleep", "HighLow", "Low", "High")]
    [string[]]$CPUMode = "Low",
    [string]$QueuePath = "C:\Scripts\HandBrakeBatcher\Queue",
    [string]$QueueRejectsPath = "C:\Scripts\HandBrakeBatcher\QueueRejects",
    [string]$LogPath = "C:\Scripts\HandBrakeBatcher\Logs",
    [string]$DestinationPath = "D:\Conversions",
    [string]$HandBrakeExe = "C:\Scripts\HandBrakeBatcher\HandBrakeCLI\HandBrakeCLI.exe",
    [string]$mkvmergeExe = "C:\Scripts\HandBrakeBatcher\mkvtoolnix\mkvmerge.exe",
    [string]$PresetFileLowCPU = "C:\Scripts\HandBrakeBatcher\H265HandbrakePresetLowCPU.json",
    [string]$PresetFileHighCPU = "C:\Scripts\HandBrakeBatcher\H265HandbrakePresetHighCPU.json",
    [string]$PresetName = "Apple1080pHEVCq38",
    [switch]$DaemonMode = $true
)

. $PSScriptRoot\Update-HandbrakeCLI.ps1 # Update HandbrakeCLI before processing.

Import-Module -Name Get-MediaInfo

function Start-SleepUntil($waketime) {
    $currentTime = Get-Date
    $snoozeTime = New-TimeSpan -Start $currentTime -End $waketime
    Write-Host "$($currentTime.TolongTimeString()) - Sleeping until" $processingStartTime
 
    while ($waketime -gt $currentTime) {
        $timeRemaing = New-TimeSpan -Start $currentTime -End $waketime
        $percent = ($snoozeTime.TotalSeconds - $timeRemaing.TotalSeconds) / $snoozeTime.TotalSeconds * 100
        $ProgressArguments = @{
            Activity         = "Sleeping"
            Status           = "Sleeping for $($timeRemaing.Hours) Hours $($timeRemaing.Minutes) Minutes $($timeRemaing.Seconds) Seconds "
            SecondsRemaining = $timeRemaing.TotalSeconds 
            PercentComplete  = $percent
        }
        Write-Progress @ProgressArguments
        [System.Threading.Thread]::Sleep(500)
        $currentTime = Get-Date
    }
    Write-Progress -Activity "Sleeping" -Status "Waking up... " -SecondsRemaining 0 -Completed
}
function Get-HandbrakeProgress {
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
    
        if (![String]::IsNullOrEmpty("$($data[0])")) {
            $status = ($data[0]).Split(':')[0]
        }
        if (![String]::IsNullOrEmpty("$($data[5])")) {
            $percent = $data[5]
        }
        if (![String]::IsNullOrEmpty("$($data[10])")) {
            $fps = $data[10]
        }
        if (![String]::IsNullOrEmpty("$($data[13])")) {
            $ETA = ($data[13]).Split(')')[0]
        }
    
        Write-Progress -Id 1 -Activity "   Currently $status $SourceFile"`
            -Status "ETA: $ETA   Complete: $percent%    $fps fps"`
            -PercentComplete $percent
    }
}


# Main processing loop
do {
    $filecount = 0
    $FileList = Get-ChildItem -Path $QueuePath | Sort-Object LastWriteTime

    if ($FileList.Count -eq 0) {
        if ($DaemonMode) {
            Write-Host "$(Get-Date -Format "HH:mm:ss"): No files found in the queue. Waiting for new files..."
            Start-Sleep -Seconds 60
            continue
        }
        else {
            break
        }
    }


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

        # Check current time and run the Night profile for higher performance
        $currentTime = Get-Date
        $currentPreset = $PresetFileHighCPU
        switch ($CPUMode) {
            "Low" { $currentPreset = $PresetFileLowCPU }
            "High" { $currentPreset = $PresetFileHighCPU }
            "HighLow" {
                if (($currentTime.Hour -lt 23) -and ($currentTime.Hour -ge 6)) {
                    $currentPreset = $PresetFileLowCPU 
                }
            }    
            "Sleep" {  
                if (($currentTime.Hour -lt 23) -and ($currentTime.Hour -ge 6)) {
                    $processingStartTime = Get-Date -Hour 23 -Minute 00 -Second 0
                    Start-SleepUntil ($processingStartTime)
                }    
            }
        }

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
        if (Test-Path -Path $DestinationFile) {
            $MediaInfo = Get-MediaInfo -Path $DestinationFile
            if ( $MediaInfo.Duration -gt 0) {
                # Destination File exists and seems to be a valid video file, so delete the queue file.
                Add-Content -Path (Join-Path -Path $LogPath -ChildPath "Completed.log") -Value (Get-Content -Path $FileList[0].FullName)
            }
            else {
                # Destination file seems invalid so delete it and keep queue file to try again later.
                Remove-Item $DestinationFile
            }
        }

        ####################################################################
        # Clean up subtitles to avoid issues with PGS subtitles 
        $cleanedVideo = (Join-Path -Path $PSScriptRoot -ChildPath "temp\SubtitleFixed.mkv")

        # Get track info
        $SubTitleIdentification = &$mkvmergeExe --identify "$SourceFile"

        # Check if there are *any* PGS (HDMV PGS) tracks
        $pgsTracks = foreach ($line in $SubTitleIdentification) {
            if ($line -match 'Track ID (\d+): subtitles \(HDMV PGS\)') {
                $matches[1]
            }
        }
        # If PGS tracks found, remux to remove them
        if ($pgsTracks.Count -gt 0) {
            Write-Host "PGS subtitles found: $($pgsTracks -join ', ')"

            # Find subtitle tracks that are NOT PGS
            $keepSubIDs = foreach ($line in $SubTitleIdentification) {
                if ($line -match 'Track ID (\d+): subtitles \((?!HDMV PGS).+\)') {
                    $matches[1]
                }
            }

            # Build subtitle track argument
            if ($keepSubIDs.Count -gt 0) {
                $subTrackArg = "--subtitle-tracks " + ($keepSubIDs -join ",")
            }
            else {
                $subTrackArg = "--no-subtitles"
            }

            # Remux
            &$mkvmergeExe -o "$cleanedVideo" $subTrackArg "$SourceFile"

            # Use the cleaned video as source for Handbrake
            $SourceFile = $cleanedVideo
        }
        ####################################################################

        &$HandBrakeExe --preset-import-file $currentPreset -Z $PresetName -i $SourceFile -o "$DestinationFile" 2>(Join-Path -Path $LogPath -ChildPath "Error.log") | Get-HandbrakeProgress
        Write-Progress -Id 1 -Activity "   Currently $status $SourceFile"`
            -Status "Completed processing $SourceFile"`
            -PercentComplete 100 `
            -Completed

        #TODO Validate the destination file before removing queuefile
        #      maybe move queuefile to a new directory
        if (Test-Path -Path $DestinationFile) {
            $MediaInfo = Get-MediaInfo -Path $DestinationFile
            if ( $MediaInfo.Duration -gt 0) {
                # Destination File exists and seems to be a valid video file, so delete the queue file.
                Add-Content -Path (Join-Path -Path $LogPath -ChildPath "Completed.log") -Value (Get-Content -Path $FileList[0].FullName)
                Write-Host "Processing completed, removing queue file."
                Remove-Item $FileList[0].FullName
            }
            else {
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
        }
        else {
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
    if (-not $DaemonMode) {
        break
    }

    Write-Host "Waiting for new files..."
    Start-Sleep -Seconds 60
} while ($DaemonMode)

Pause