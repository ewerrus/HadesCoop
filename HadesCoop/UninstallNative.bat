@echo off
rem Removes the HadesCoop native bridge and restores the original SDL2.dll.
cd /d "%~dp0x64"
if not exist SDL2_orig.dll (
	echo Nothing to restore: SDL2_orig.dll not found.
	exit /b 0
)
del /f SDL2.dll || goto :error
ren SDL2_orig.dll SDL2.dll || goto :error
echo Original SDL2.dll restored.
exit /b 0
:error
echo Failed. Is the game running?
exit /b 1
