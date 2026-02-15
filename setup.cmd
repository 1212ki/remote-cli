@echo off
setlocal
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
endlocal
