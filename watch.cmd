@echo off
setlocal
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0watch.ps1" %*
endlocal
