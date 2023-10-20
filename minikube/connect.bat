@echo off

call ..\check_env.bat
pushd "%UE_ENGINE_ROOT%"

set ADDRESS="127.0.0.1"
for /f "usebackq delims=" %%A in (`kubectl get gs -n agones-gameserver -o jsonpath^="{.items[*].status.ports[0].port}"`) do set PORT=%%A

echo "connecto to Minikube %ADDRESS%:%PORT%"

start LyraStarterGame\Binaries\Win64\LyraClient.exe %ADDRESS%:%PORT% -WINDOWED -ResX=800 -ResY=450 -WinX=100 -WinY=100

popd
pause
