@echo off

call ..\check_env.bat
pushd "%UE_ENGINE_ROOT%"

set ADDRESS="127.0.0.1"
set PORT="7777"

echo "connecto to Compose Container %ADDRESS%:%PORT%"

start LyraStarterGame\Binaries\Win64\LyraClient.exe %ADDRESS%:%PORT% -WINDOWED -ResX=800 -ResY=450 -WinX=100 -WinY=100

popd
pause
