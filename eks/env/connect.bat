@echo off

call ..\..\check_env.bat
pushd "%UE_ENGINE_ROOT%"

aws eks update-kubeconfig --name lyra-on-eks
for /f "usebackq delims=" %%A in (`kubectl get gs -n agones-gameserver -o jsonpath^="{.items[0].status.address}"`) do set ADDRESS=%%A
for /f "usebackq delims=" %%A in (`kubectl get gs -n agones-gameserver -o jsonpath^="{.items[0].status.ports[0].port}"`) do set PORT=%%A

echo "connecto to EKS %ADDRESS%:%PORT%"

start LyraStarterGame\Binaries\Win64\LyraClient.exe %ADDRESS%:%PORT% -WINDOWED -ResX=800 -ResY=450 -WinX=100 -WinY=100

popd
pause
