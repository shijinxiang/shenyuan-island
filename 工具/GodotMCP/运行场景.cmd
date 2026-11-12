@echo off
chcp 65001 >nul
start "" "%~dp0..\Godot_4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0..\..\游戏"
