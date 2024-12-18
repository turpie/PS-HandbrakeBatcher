# Function to copy a shortcut to the SendTo directory
function Copy-ShortcutToSendTo {
    param (
        [string]$ShortcutPath
    )

    # Get the current user's SendTo directory
    $sendToDir = [System.IO.Path]::Combine($env:APPDATA, 'Microsoft\Windows\SendTo')

    if (-Not (Test-Path -Path $sendToDir)) {
        Write-Host "SendTo directory does not exist."
        return
    }

    # Define the destination path
    $destinationPath = [System.IO.Path]::Combine($sendToDir, [System.IO.Path]::GetFileName($ShortcutPath))

    # Copy the shortcut to the SendTo directory
    try {
        Copy-Item -Path $ShortcutPath -Destination $destinationPath -Force
        Write-Host "Shortcut copied to $sendToDir"
    } catch {
        Write-Host "Failed to copy shortcut: $_"
    }
}

# Example usage
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$shortcutPath = Join-Path -Path $scriptDir -ChildPath 'Add to Handbrake Queue.lnk'
Copy-ShortcutToSendTo -ShortcutPath $shortcutPath