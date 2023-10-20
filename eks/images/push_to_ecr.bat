@echo off

pushd "%~dp0"
call ..\..\check_env.bat
powershell.exe -ExecutionPolicy Bypass -File "./push_to_ecr.ps1" %1
popd
pause
