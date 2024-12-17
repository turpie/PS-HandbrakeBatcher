if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7."

    # Check if pwsh is available
    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        Write-Host "PowerShell 7 is not installed. Please install it from https://aka.ms/powershell."
        exit 1
    }

    Write-Host "Relaunching in PowerShell 7..."
    $scriptPath = $MyInvocation.MyCommand.Definition
    Start-Process -NoNewWindow -Wait -FilePath "pwsh" -ArgumentList "-File", $scriptPath
    exit
}


<# 
    TODO: add delete code
        check for missing source video file

 #>




Import-Module PwshSpectreConsole # Module for console UI
$QueuePath = "C:\Scripts\HandBrakeBatcher\Queue"
$LogPath = "C:\Scripts\HandBrakeBatcher\Logs"

$filecount = 0
$FileList = Get-ChildItem -Path $QueuePath | Sort-Object LastWriteTime

$QueueData = New-Object -TypeName System.Collections.ArrayList

$FileList | ForEach-Object {
    $FileToProcess = Get-ChildItem -LiteralPath (Get-Content $_.FullName)
    $QueueItemDetail = [pscustomobject]@{
        '*' = ""
        Name      = $FileToProcess.Name
        QueueFile = $_.FullName
    }
    $QueueData.Add( $QueueItemDetail)
}
#$QueueData 

$layout = New-SpectreLayout -Name "root" -Rows @(
    # Row 1
    (
        New-SpectreLayout -Name "header" -MinimumSize 5 -Ratio 1 -Data ("empty")
    ),
    # Row 2
    (
        New-SpectreLayout -Name "content" -Ratio 10 -Columns @(
            (
                New-SpectreLayout -Name "filelist" -Ratio 2 -Data "empty"
            ),
            (
                New-SpectreLayout -Name "preview" -Ratio 4 -Data "empty"
            )
        )
    )
    # Row 3
    (
        New-SpectreLayout -Name "commands" -MinimumSize 5 -Ratio 1 -Data ("empty")
    )
)
# Functions for rendering the content of each panel
function Get-TitlePanel {
    return "HandBrake Batcher - Queue Manager [gray]$(Get-Date)[/]" | Format-SpectreAligned -HorizontalAlignment Center -VerticalAlignment Middle | Format-SpectrePanel -Expand
}

function Get-FileListPanel {
    param (
        $Files,
        $SelectedFile
    )
    $fileList = $Files | ForEach-Object {
        $name = (Get-ChildItem -LiteralPath (Get-Content $_.FullName)).Name

        if ($_.Name -eq $SelectedFile.Name) {
            $name = "[Turquoise2]$($name)[/]"
        }
        return $name
    } | Out-String
    return Format-SpectrePanel -Header "[white]File List[/]" -Data $fileList.Trim() -Expand
}

function Get-PreviewPanel {
    param (
        $SelectedFile
    )
    $item = Get-Item -Path $SelectedFile.FullName
    $result = ""
    if ($item -is [System.IO.DirectoryInfo]) {
        $result = "[grey]$($SelectedFile.Name) is a directory.[/]"
    } else {
        try {
            $sourceItem = Get-ChildItem -LiteralPath (Get-Content $SelectedFile.FullName)
            $name = $sourceItem.Name
            $sourceSize = [int]($sourceItem.Length / 1MB)
            $content = `
"$name
$sourceSize MB
$($sourceItem.FullName)
$item
"
            $result = "[grey]$($content | Get-SpectreEscapedText)[/]"
        } catch {
            $result = "[red]Error reading file content: $($_.Exception.Message | Get-SpectreEscapedText)[/]"
        }
    }
    return $result | Format-SpectrePanel -Header "[white]Preview[/]" -Expand
}
function Get-CommandPanel {
    param (
        $Debug
    )
    return "$Debug Type '↓', '↑' to navigate the file list, 'u' or 'd' to change position, 'X' to delete. 'W' to write new queue order" | Format-SpectreAligned -HorizontalAlignment Center -VerticalAlignment Middle | Format-SpectrePanel -Expand
}


function Get-LastKeyPressed {
    $lastKeyPressed = $null
    while ([Console]::KeyAvailable) {
        $lastKeyPressed = [Console]::ReadKey($true)
    }
    return $lastKeyPressed
}

# Start live rendering the layout
# Type "↓", "↓", "↓" to navigate the file list, and press "Enter" to open a file in Notepad
Invoke-SpectreLive -Data $layout -ScriptBlock {
    param (
        [Spectre.Console.LiveDisplayContext] $Context
    )

    # State
    $fileList = $FileList 
    $selectedFile = $fileList[0]

    while ($true) {
        # Handle input
        $lastKeyPressed = Get-LastKeyPressed
        if ($lastKeyPressed -ne $null) {
            if ($lastKeyPressed.Key -eq "DownArrow") {
                $selectedFile = $fileList[($fileList.IndexOf($selectedFile) + 1) % $fileList.Count]
            } elseif ($lastKeyPressed.Key -eq "UpArrow") {
                $selectedFile = $fileList[($fileList.IndexOf($selectedFile) - 1 + $fileList.Count) % $fileList.Count]
            } elseif ($lastKeyPressed.Key -eq "D") {
                # Move selected item Down the list
                $selectIndex = $fileList.IndexOf($selectedFile)
                if($selectIndex -lt ($fileList.Length -1) ){
                    $temp = $fileList[$selectIndex + 1]
                    $fileList[$selectIndex + 1]= $fileList[$selectIndex]
                    $fileList[$selectIndex]= $temp
                }
            } elseif ($lastKeyPressed.Key -eq "U") {
                # Move selected item Up the list
                $selectIndex = $fileList.IndexOf($selectedFile)
                if($selectIndex -gt 0 ){
                    $temp = $fileList[$selectIndex - 1]
                    $fileList[$selectIndex - 1]= $fileList[$selectIndex]
                    $fileList[$selectIndex]= $temp
                }
            } elseif ($lastKeyPressed.Key -eq "W") {
                # Write the new queue order
                $QueueTime = Get-Date
                $fileList | ForEach-Object {
                    #$lastAccess = (Get-Item -Path $_.VersionInfo.FileName).LastWriteTime
                    $QueueTime= $QueueTime.AddMinutes(1)
                    (Get-Item -path  $_.FullName).LastWriteTime =$QueueTime
                }
                return
            } elseif ($lastKeyPressed.Key -eq "Enter") {
                if ($selectedFile -is [System.IO.DirectoryInfo] -or $selectedFile.Name -eq "..") {
                    $fileList = @(@{Name = ".."; Fullname = ".."}) + (Get-ChildItem -Path $selectedFile.FullName)
                    $selectedFile = $fileList[0]
                } else {
                    notepad $selectedFile.FullName
                    return
                }
            } elseif ($lastKeyPressed.Key -eq "Escape") {
                return
            }
        }

        # Generate new data
        $titlePanel = Get-TitlePanel
        $fileListPanel = Get-FileListPanel -Files $fileList -SelectedFile $selectedFile
        $previewPanel = Get-PreviewPanel -SelectedFile $selectedFile
        $commandPanel = Get-CommandPanel -Debug $lastKeyPressed.Key

        # Update layout
        $layout["header"].Update($titlePanel) | Out-Null
        $layout["filelist"].Update($fileListPanel) | Out-Null
        $layout["preview"].Update($previewPanel) | Out-Null
        $layout["commands"].Update($commandPanel) | Out-Null

        # Draw changes
        $Context.Refresh()
        Start-Sleep -Milliseconds 200
    }
}