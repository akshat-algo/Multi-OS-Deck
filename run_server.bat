@echo off
title Stream Deck Windows Companion Server
echo ========================================================
echo   STREAM DECK WINDOWS COMPANION SERVER
echo ========================================================
set PATH=C:\flutter\bin;%PATH%
dart run bin\deck_server.dart
pause
