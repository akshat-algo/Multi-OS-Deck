@echo off
set PATH=C:\flutter\bin;C:\extra\android-sdk\platform-tools;%PATH%

echo [1/3] Setting up USB port forwarding...
adb reverse tcp:8443 tcp:8443

echo [2/3] Checking Windows Companion Server...
netstat -ano | findstr 8443 >nul
if %errorlevel% neq 0 (
    echo Starting Companion Server in background...
    start /min cmd /c "c:\extra\android_dec\bin\deck_server.exe"
    timeout /t 2 /nobreak >nul
)

echo [3/3] Opening Stream Deck on mobile phone...
adb shell am start -n com.streamdeck.stream_deck/.MainActivity
