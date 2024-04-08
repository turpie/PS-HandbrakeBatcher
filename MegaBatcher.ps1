Import-Module -Name Get-MediaInfo
.\Update-HandbrakeCLI.ps1 # Update HandbrakeCLI before processing.

$SourcePath = "G:\My Drive\iTunesH265Media\TV Shows"

$TempPath = "C:\Scripts\HandBrakeBatcher\Temp"
$HandBrakeExe = "C:\Scripts\HandBrakeBatcher\HandBrakeCLI\HandBrakeCLI.exe"

# Original H264 profile
#$PresetFile = "C:\Scripts\HandBrakeBatcher\HandbrakePreset.json"
#$PresetName = "CustomFast1080p30"

# Newer H265/HEVC profile - comment out these lines if you need to use the previous profile.
$PresetFile = "C:\Scripts\HandBrakeBatcher\H265HandbrakePreset.json"
$PresetName = "Apple1080pHEVCq38"

# Set the times that processing can occur. Outside of these hours the script will sleep.
$ActivePeriodStartTime = Get-Date -Hour 18 -Minute 0 -Second 0 -Millisecond 0
$ActivePeriodEndTime = Get-Date -Hour 8 -Minute 0 -Second 0 -Millisecond 0



# Automatically saves logs to the Scripts share for future reference.
$Timestamp = $(Get-Date -Format "yyyyMMdd_hhmmss")
$LogFile = Join-Path -Path $PSScriptRoot -ChildPath "logs\MegaBatch_$Timestamp.log"
$LogCSVFile = Join-Path -Path $PSScriptRoot -ChildPath "logs\MegaBatch_stats.csv"

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
$FileList = Get-ChildItem -Path $SourcePath -File -Filter "*.m4v" -Recurse
$FileList += Get-ChildItem -Path $SourcePath -File -Filter "*.mp4" -Recurse
$FileList = $FileList | Sort-Object {Get-Random} # Randomises the order so it can be used at the same time as Renderbot
#$FileList = $FileList | Sort-Object #-Descending

Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host ""
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
    $_.FullName
    $FileToProcess = $_ # Unnecessary to copy to new variable name but keeps code similar to Process script.
    $SourceFile = $FileToProcess.FullName
    $DestinationFile = (Join-Path -Path $TempPath -ChildPath ($FileToProcess.Name))

    $MediaInfo = Get-MediaInfo -Path $SourceFile  # check the videos current format.
    # If it isn't already HEVC/H265 then Handbrake it.
    if ( $MediaInfo.Format -ne 'HEVC') {
        
        Write-Progress -Id 0 -Activity "Handbrake Batch Video Conversion in Progress" -Status "Processed $filecount of $totalFiles" -PercentComplete ($filecount / $totalFiles * 100)
        Write-Host "-------------------------------------------------------------------------------"
        Write-Host "  Processing - $SourceFile"
        Write-Host "      to     - $DestinationFile"
        Write-Host "  Processed $filecount files"
        Write-Host "          $($FileList.Count - $filecount) files remaining"
        Write-Host "-------------------------------------------------------------------------------"

        # Is it the active time yet?
        $startTime = (Get-Date)
        If (-not (($startTime.TimeOfDay -gt $ActivePeriodStartTime.TimeOfDay) -or ($startTime.TimeOfDay -lt $ActivePeriodEndTime.TimeOfDay))) {
            # Sleep until ready.
            $SleepLength = New-TimeSpan -Start (get-date) -End $ActivePeriodStartTime
            Write-Host "Current time is outside of active hours. Processing will begin at $($ActivePeriodStartTime.Hour):$($ActivePeriodStartTime.Minute)"
            Write-Host "Sleeping for $($SleepLength.Hours) hours and $($SleepLength.Minutes)"
            Start-Sleep -Seconds $SleepLength.TotalSeconds
            Write-Host "!!! Sleep has finished, it's time to start working !!!"
        }

        #&$HandBrakeExe --preset-import-file $PresetFile -Z $PresetName -i "$SourceFile" -o "$DestinationFile" 2> $null | Get-HandbrakeProgress
        &$HandBrakeExe --preset-import-file $PresetFile -Z $PresetName -i "$SourceFile" -o "$DestinationFile" 2>($DestinationFile + ".log") | Get-HandbrakeProgress
        
        $endTime = (Get-Date)
        $ElapsedTime = $endTime - $startTime

        $SourceFileSize = (Get-Item -path $SourceFile).Length
        $DestinationFileSize = (Get-Item -path $DestinationFile).Length
        
        $FileSizeDifference = $DestinationFileSize / $SourceFileSize * 100
        Write-LogMessage ("Filename         : $SourceFile")
        Write-LogMessage ("Original filesize: $([math]::Round($SourceFileSize/1MB)) MB")
        Write-LogMessage ("New H265 filesize: $([math]::Round($DestinationFileSize/1MB)) MB")
        Write-LogMessage ("Saved            : $([math]::Round(($SourceFileSize - $DestinationFileSize)/1MB)) MB")
        Write-LogMessage ("Percentage       : $([math]::Round($FileSizeDifference,2)) %")
        Write-LogMessage ('Duration         : {0:hh} hrs {0:mm} min {0:ss} sec' -f $ElapsedTime)
        Write-Host

        $exportData = [PSCustomObject]@{
            OriginalSize      = ($SourceFileSize / 1MB)
            NewSize           = ($DestinationFileSize / 1MB)
            SavedSpaceMB      = ($SourceFileSize - $DestinationFileSize) / 1MB
            SavedSpacePercent = $FileSizeDifference
            TimeTaken         = '{0:hh}:{0:mm}:{0:ss}' -f $ElapsedTime
            Name              = $SourceFile
        }
        Export-Csv -InputObject $exportData -Path $LogCSVFile -Append

        Write-Host "moving files"
        Move-Item -Path $DestinationFile -Destination $SourceFile -Force # Yes this looks back to front, but we are now replacing the original.
        Write-Host "---DONE---"
    }
    else {
        Write-Host "*** Already HEVC - $SourceFile"
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