@echo off

pushd "%~dp0"
call ..\check_env.bat
powershell.exe -ExecutionPolicy Bypass -File "./build.ps1" %1
pause
