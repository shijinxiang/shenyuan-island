@echo off
chcp 65001 >nul
set GODOT_AI_DISABLE_TELEMETRY=true
set "PATH=%USERPROFILE%\.local\bin;%PATH%"
start "" "%~dp0..\Godot_4.7.2\Godot_v4.7.2-stable_win64.exe" --editor --path "%~dp0..\..\游戏"
