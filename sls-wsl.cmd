@echo off
setlocal
set "DISTRO=Ubuntu-24.04"
if not "%~1"=="" set "DISTRO=%~1"
wsl -d %DISTRO% -- bash -lc "tmux ls"
endlocal
