@echo off
title Stream Deck App
echo ========================================================
echo   STREAM DECK CROSS-PLATFORM (FLUTTER)
echo ========================================================
set JAVA_HOME=C:\extra\jdk-17\jdk-17.0.12+7
set ANDROID_HOME=C:\extra\android-sdk
set PATH=C:\flutter\bin;C:\extra\android-sdk\platform-tools;C:\extra\jdk-17\jdk-17.0.12+7\bin;%PATH%
flutter run
pause
