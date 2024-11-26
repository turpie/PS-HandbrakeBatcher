$SourcePath = "G:\My Drive\iTunesH265MediaConverted\Movies"
$DestPath = "D:\iTunes Media\Movies"
$LogCSVFile = Join-Path -Path $PSScriptRoot -ChildPath "logs\MoveH265_stats_$($env:computername).csv"

$SourceListing = Get-ChildItem -Path $SourcePath -File -Filter "*.m4v" -Recurse
#$DestFiles = Get-ChildItem -Path $DestPath -File -Filter "*.m4v" -Recurse

$SourceListing | ForEach-Object{
    $SrcFile = $_
    $DestFileName = $SrcFile.FullName.Replace($SourcePath,$DestPath)
    $DestFile = Get-Item -Path $DestFileName
    if(Test-Path -Path $DestFile){
        Write-Host "$DestFile exists" ($DestFile.Length / 1MB)
        Write-Host "$SrcFile exists" ($SrcFile.Length / 1MB)
        if($SrcFile.Length -lt $DestFile.Length){
            Write-Host " YES Src is smaller than Dest"
            Move-Item -Path $SrcFile.FullName -Destination $DestFile.FullName -Force

            $exportData = [PSCustomObject]@{
                OriginalSize      = ($DestFile.Length / 1MB)
                NewSize           = ($SrcFile.Length / 1MB)
                SavedSpaceMB      = ($DestFile.Length - $SrcFile.Length) / 1MB
                SavedSpacePercent = $SrcFile.Length / $DestFile.Length *100
                Name              = $SrcFile
            }
            Export-Csv -InputObject $exportData -Path $LogCSVFile -Append
        }else{
            Write-Host " NO Src is bigger than Dest"
        }
    }else{
        Write-Host "Couldn't find $DestFile; what did you do with it?"
    }
}
