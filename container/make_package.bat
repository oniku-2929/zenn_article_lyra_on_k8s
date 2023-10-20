@echo off

pushd "%~dp0"
call ..\check_env.bat
popd

set CONFIG=%1

pushd "%UE_ENGINE_ROOT%"

Engine\Build\BatchFiles\RunUAT.bat BuildCookRun -project="LyraStarterGame\LyraStarterGame.uproject" -noP4 -platform=Linux ^
-server -noclient -serverconfig=%CONFIG% -cook -stage -archive -archivedirectory="LyraStarterGame\Package\%CONFIG%" ^
-package -build -pak -prereqs -compressed -target=LyraServer -utf8output

popd

pause
