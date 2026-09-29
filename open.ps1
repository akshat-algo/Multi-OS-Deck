Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   STREAM DECK WINDOWS COMPANION & MOBILE LAUNCHER  " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Check if companion server is already listening on port 8443
$isListening = $false
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $ar = $tcp.BeginConnect("127.0.0.1", 8443, $null, $null)
    if ($ar.AsyncWaitHandle.WaitOne(200, $false)) {
        $tcp.EndConnect($ar)
        $isListening = $true
    }
    $tcp.Close()
} catch {}

if (-not $isListening) {
    Write-Host "[+] Launching Native Companion Server..." -ForegroundColor Yellow
    $exePath = "c:\extra\android_dec\bin\deck_server.exe"
    if (Test-Path $exePath) {
        Start-Process -FilePath $exePath -WindowStyle Minimized
    } else {
        Start-Process -FilePath "C:\flutter\bin\dart.bat" -ArgumentList "run", "bin\deck_server.dart" -WorkingDirectory "c:\extra\android_dec" -WindowStyle Minimized
    }
    Start-Sleep -Milliseconds 600
} else {
    Write-Host "[+] Companion Server is already active on port 8443" -ForegroundColor Green
}

# 2. Reverse port forward via ADB
$adbPath = "C:\extra\android-sdk\platform-tools\adb.exe"
if (Test-Path $adbPath) {
    Write-Host "[+] Forwarding port 8443 via ADB reverse proxy..." -ForegroundColor Cyan
    & $adbPath reverse tcp:8443 tcp:8443
    
    # Wake up screen if asleep
    & $adbPath shell input keyevent KEYCODE_WAKEUP
    
    # 3. Open app on phone
    Write-Host "[+] Opening Stream Deck on mobile phone..." -ForegroundColor Green
    & $adbPath shell am start -n com.streamdeck.stream_deck/.MainActivity
} else {
    Write-Host "ADB not found at $adbPath" -ForegroundColor Red
}

Write-Host "=== Stream Deck is ready and paired! ===" -ForegroundColor Green
