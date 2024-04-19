Import-Module -Name Get-MediaInfo
.\Update-HandbrakeCLI.ps1 # Update HandbrakeCLI before processing.

$GoogleDriveRoot = (Get-PSDrive | Where-Object { $_.Description -eq "Google Drive" }).Root
$SourcePath = Join-Path -Path $GoogleDriveRoot -ChildPath "My Drive\iTunesH265Media\TV Shows"
$DestinationPath = Join-Path -Path $GoogleDriveRoot -ChildPath "My Drive\iTunesH265MediaConverted"

$TempPath = Join-Path -Path $PSScriptRoot -ChildPath "temp"
$HandBrakeExe = Join-Path -Path $PSScriptRoot -ChildPath "HandBrakeCLI\HandBrakeCLI.exe"

# Original H264 profile
#$PresetFile = Join-Path -Path $PSScriptRoot -ChildPath "\HandbrakePreset.json"
#$PresetName = "CustomFast1080p30"

# Newer H265/HEVC profile - comment out these lines if you need to use the previous profile.
$PresetFile = Join-Path -Path $PSScriptRoot -ChildPath "H265HandbrakePreset.json"
$PresetName = "Apple1080pHEVCq38"

# Set the times that processing can occur. Outside of these hours the script will sleep.
$ActivePeriodStartTime = Get-Date -Hour 18 -Minute 0 -Second 0 -Millisecond 0
$ActivePeriodEndTime = Get-Date -Hour 8 -Minute 0 -Second 0 -Millisecond 0



# Automatically saves logs to the Scripts share for future reference.
$Timestamp = $(Get-Date -Format "yyyyMMdd_hhmmss")
$LogFile = Join-Path -Path $PSScriptRoot -ChildPath "logs\MegaBatch_$($env:computername)_$Timestamp.log"
$LogCSVFile = Join-Path -Path $PSScriptRoot -ChildPath "logs\MegaBatch_stats_$($env:computername).csv"


function Write-LogMessage {
    param([String]$Message)
  
    $Date = (Get-Date).ToString()
    $LogLine = "[$Date] $Message"
  
    Write-Host $LogLine
    Add-Content $LogFile $LogLine
}

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

Write-Host "Getting list of files to process..."
$filecount = 0
# Get all files ending in m4v and then add to that list all the files ending in mp4
$FileList = Get-ChildItem -Path $SourcePath -File -Filter "*.m4v" -Recurse
$FileList += Get-ChildItem -Path $SourcePath -File -Filter "*.mp4" -Recurse

# My main video conversion pc is called RENDERBOT. On that PC the script processes each file a standard sorted order
# on other computers we randomises the sort order so that the other computers aren't likely to be working on the same file
# over time there will be a greater chance of clashes. 
# TODO: Add a smarter system of avoiding duplicated work.
if ($env:computername -eq "RENDERBOT") {
    Write-LogMessage "Sorting by Ascending FullName"
    $FileList = $FileList | Sort-Object -Property FullName #-Descending
}
else {
    Write-LogMessage "Using RANDOM sort order."
    $FileList = $FileList | Sort-Object { Get-Random } 
}

# write out a nice header with space allowed for the progress bar which appears at the top of the window.
Write-Host ""
Write-Host ""
Write-Host "*******************************************************************************"
Write-Host "  Starting Handbrake Batch Encoding"
Write-Host "   MegaBatcher by Paul Turpie"
Write-Host "   $($FileList.Count) files to be processed"
Write-Host "*******************************************************************************"

$totalFiles = $FileList.Count
$FileList | ForEach-Object {
    $filecount++
    Write-LogMessage ( "Next file is " + $_.FullName)
    $FileToProcess = $_ # Unnecessary to copy to new variable name but keeps code similar to the Process-HandbrakeBatcher script.
    $SourceFile = $FileToProcess.FullName

    if (Test-Path $SourceFile) {
        $ConvertedFile = (Join-Path -Path $TempPath -ChildPath ($FileToProcess.Name))
    
        $MediaInfo = Get-MediaInfo -Path $SourceFile  # check the videos current format.
        # If it isn't already HEVC/H265 then Handbrake it.
        if ( $MediaInfo.Format -ne 'HEVC') {
            
            Write-Progress -Id 0 -Activity "Handbrake Batch Video Conversion in Progress" -Status "Processed $filecount of $totalFiles" -PercentComplete ($filecount / $totalFiles * 100)
            Write-Host "-------------------------------------------------------------------------------"
            Write-Host "  Processing - $SourceFile"
            Write-Host "      to     - $ConvertedFile"
            Write-Host "  Processed $filecount files"
            Write-Host "          $($FileList.Count - $filecount) files remaining"
            Write-Host "-------------------------------------------------------------------------------"
    
            $startTime = (Get-Date)
            # If we're not running on RENDERBOT only run during active hours
            if ($env:computername -ne "RENDERBOT") {
                # Is it the active time yet?
                $ActivePeriodStartTime = Get-Date -Hour 18 -Minute 0 -Second 0 -Millisecond 0
                $ActivePeriodEndTime = Get-Date -Hour 8 -Minute 0 -Second 0 -Millisecond 0
                If (-not (($startTime.TimeOfDay -gt $ActivePeriodStartTime.TimeOfDay) -or ($startTime.TimeOfDay -lt $ActivePeriodEndTime.TimeOfDay))) {
                    # Sleep until ready.
                    $SleepLength = New-TimeSpan -Start (get-date) -End $ActivePeriodStartTime
                    Write-Host "Current time is outside of active hours. Processing will begin at $($ActivePeriodStartTime.Hour):$($ActivePeriodStartTime.Minute.ToString().PadLeft(2, '0'))"
                    #Write-Host "DEBUG Active time ="
                    #Write-Host $ActivePeriodStartTime
                    #Write-Host "DEBUG SleepLength ="
                    #Write-Host $SleepLength
                    
                    Write-Host "Sleeping for $($SleepLength.Hours) hours and $($SleepLength.Minutes) minutes"
                    Write-Progress -Id 1 -Activity "   Sleeping"`
                        -Status "snoozing"`
                        -PercentComplete 0
                    Start-Sleep -Seconds $SleepLength.TotalSeconds
                    Write-Host "!!! Sleep has finished, it's time to start working !!!"
                }
            }
    
            Write-LogMessage "- Starting Handbrake"
            #&$HandBrakeExe --preset-import-file $PresetFile -Z $PresetName -i "$SourceFile" -o "$ConvertedFile" 2> $null | Get-HandbrakeProgress
            &$HandBrakeExe --preset-import-file $PresetFile -Z $PresetName -i "$SourceFile" -o "$ConvertedFile" 2>($ConvertedFile + ".log") | Get-HandbrakeProgress
            Write-LogMessage "- Handbrake Finished"
            
            $endTime = (Get-Date)
            $ElapsedTime = $endTime - $startTime
    
            $SourceFileSize = (Get-Item -path $SourceFile).Length
            $ConvertedFileSize = (Get-Item -path $ConvertedFile).Length
            
            $FileSizeDifference = $ConvertedFileSize / $SourceFileSize * 100
            Write-LogMessage ("Filename         : $SourceFile")
            Write-LogMessage ("  Original filesize: $([math]::Round($SourceFileSize/1MB)) MB")
            Write-LogMessage ("  New H265 filesize: $([math]::Round($ConvertedFileSize/1MB)) MB")
            Write-LogMessage ("  Saved            : $([math]::Round(($SourceFileSize - $ConvertedFileSize)/1MB)) MB")
            Write-LogMessage ("  Percentage       : $([math]::Round($FileSizeDifference,2)) %")
            Write-LogMessage ('  Duration         : {0:hh} hrs {0:mm} min {0:ss} sec' -f $ElapsedTime)
            Write-Host
    
            $exportData = [PSCustomObject]@{
                OriginalSize      = ($SourceFileSize / 1MB)
                NewSize           = ($ConvertedFileSize / 1MB)
                SavedSpaceMB      = ($SourceFileSize - $ConvertedFileSize) / 1MB
                SavedSpacePercent = $FileSizeDifference
                TimeTaken         = '{0:hh}:{0:mm}:{0:ss}' -f $ElapsedTime
                Name              = $SourceFile
            }
            Export-Csv -InputObject $exportData -Path $LogCSVFile -Append
    
            Write-LogMessage "  Moving files"
            $DestinationFile = $SourceFile.Replace("iTunesH265Media", "iTunesH265MediaConverted")
            $DestinationPath = (Get-ChildItem -Path $SourceFile).DirectoryName.Replace("iTunesH265Media", "iTunesH265MediaConverted")
            if (!(Test-Path $DestinationPath)) {
                New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
            }
            Move-Item -Path $ConvertedFile -Destination $DestinationFile -Force # Yes this looks back to front, but we are now replacing the original. iTunesH265MediaConverted
            Write-LogMessage "  Deleting Original file"
            if (Test-Path $DestinationFile) {
                # Only delete the original if the new one exists. Incase there was an error.
                Remove-Item -Path $SourceFile
                Write-LogMessage "   Original file Deleted"
            }
            else {
                Write-LogMessage "   ERROR Original file not Deleted as the destination file wasn't found."
            }
            
            Write-LogMessage "---DONE---"
        }
        else {
            Write-LogMessage "*** Already HEVC - $SourceFile"
            Write-LogMessage "  Moving already converted files to new location."
            $DestinationFile = $SourceFile.Replace("iTunesH265Media", "iTunesH265MediaConverted")
            $DestinationPath = (Get-ChildItem -Path $SourceFile).DirectoryName.Replace("iTunesH265Media", "iTunesH265MediaConverted")
            if (!(Test-Path $DestinationPath)) {
                New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
            }
            Move-Item -Path $SourceFile -Destination $DestinationFile -Force # Yes this looks back to front, but we are now replacing the original. iTunesH265MediaConverted
            Write-LogMessage "---DONE---"    
        }
    
    }
    else {
        Write-Host "  File not found, it must have been processed by another computer."
        Write-Host
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
Write-Host "  Completed Handbrake Batch Encoding"
Write-Host "   MegaBatcher by Paul Turpie"
Write-Host "   $($totalFiles) files were processed"
Write-Host "*******************************************************************************"

Pause