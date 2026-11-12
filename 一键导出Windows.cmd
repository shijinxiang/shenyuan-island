@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0工具\打包发布\一键导出Windows.ps1"
if errorlevel 1 (
  echo 导出失败，请查看上方提示。
) else (
  echo 导出完成，文件位于 发布\Windows。
)
pause
