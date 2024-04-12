$HandBrakeExe = "C:\Scripts\HandBrakeBatcher\HandBrakeCLI\HandBrakeCLI.exe"
$HandbrakeReleaseURI = "https://api.github.com/repos/HandBrake/HandBrake/releases/latest"
$tempFile = "HandBrakeCLI.zip"

# If the script is running in Powershell versions prior to v7, then disable the progress bar as it downloads very slow.
if ($PSVersionTable.PSVersion -lt [System.Version]"7.0.0") {
    $ProgressPreference = 'SilentlyContinue'
}

Write-Host "Checking that HandbrakeCLI up-to-date ......"


$localVersion = [System.Version]((&$HandBrakeExe --version)[0]).Split(" ")[1]
Write-Host "Currently installed HandbrakeCLI version is $localVersion"

$remoteResult = Invoke-RestMethod -Uri $HandbrakeReleaseURI
$remoteVersion = [System.Version]$remoteResult.name
Write-Host "Remote Github HandbrakeCLI version is $remoteVersion"

if ($localVersion -lt $remoteVersion) {
    Write-Host "HandbrakeCLI is out of date. Getting $remoteVersion"
    #Backup the old version, and rename to include the version number in it's filename
    Move-Item -Path $HandBrakeExe -Destination ($HandBrakeExe.Replace("CLI.exe", "CLI-" + ([string]$localVersion) + ".exe"))

    # Find the download URL.
    $downloadURL = ($remoteResult.assets | Where-Object name -Like "*CLI*win-x86_64.zip").browser_download_url
    Invoke-WebRequest -Uri $downloadURL -OutFile $tempFile
    Expand-Archive -Path $tempFile -Force

    $localVersion = [System.Version]((&$HandBrakeExe --version)[0]).Split(" ")[1]
    Write-Host "HandbrakeCLI has been updated to $localVersion"
}
else {
    Write-Host "HandbrakeCLI is up to date."
}