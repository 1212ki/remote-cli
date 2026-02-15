@echo off
setlocal

set "NO_ATTACH="
if /i "%~1"=="--no-attach" (
  set "NO_ATTACH=1"
  shift /1
)

set "DISTRO=Ubuntu-24.04"
if not "%~1"=="" set "DISTRO=%~1"

set "WIN_DIR=%CD%"
rem Same issue as above if current dir is a drive root like "C:\".
if "%WIN_DIR:~-1%"=="\" set "WIN_DIR=%WIN_DIR%."

set "LINUX_DIR="
for /f "delims=" %%i in ('wsl -d %DISTRO% -- wslpath -a "%WIN_DIR%"') do set "LINUX_DIR=%%i"
if not defined LINUX_DIR (
  echo Failed to resolve current directory in WSL.
  exit /b 1
)

rem Keep Codex + MCP state under the Windows home mount (writable in restricted sandboxes)
if "%CODEX_HOME%"=="" set "CODEX_HOME=/mnt/c/Users/%USERNAME%/.codex"
if "%NPM_CACHE%"=="" set "NPM_CACHE=/mnt/c/Users/%USERNAME%/.npm-cache"

set "EXTRA_ENV="
if defined NO_ATTACH set "EXTRA_ENV=CODEX_NO_ATTACH=1 "

rem NOTE: %~dp0 ends with a trailing backslash. When passed as a quoted argument,
rem it can break Windows argv parsing (backslash before closing quote). Append "."
rem so the string doesn't end with "\".
set "WIN_SCRIPT_DIR=%~dp0."
set "LINUX_SCRIPT_DIR="
for /f "delims=" %%i in ('wsl -d %DISTRO% -- wslpath -a "%WIN_SCRIPT_DIR%"') do set "LINUX_SCRIPT_DIR=%%i"
if not defined LINUX_SCRIPT_DIR (
  echo Failed to resolve script directory in WSL.
  exit /b 1
)

wsl -d %DISTRO% -- bash -lc "%EXTRA_ENV%CODEX_HOME=%CODEX_HOME% NPM_CACHE=%NPM_CACHE% bash '%LINUX_SCRIPT_DIR%/tmux-session-select.sh' --prefix codex --mode create_or_attach --workdir '%LINUX_DIR%'"

endlocal
