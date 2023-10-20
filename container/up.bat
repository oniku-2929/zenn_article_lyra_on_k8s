@echo off

pushd "%~dp0"
call ..\check_env.bat
powershell.exe -ExecutionPolicy Bypass -File "./up.ps1" %1
popd

pause
