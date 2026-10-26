@echo off
rem Installs the HadesCoop native bridge (proxy SDL2.dll).
rem Run from the Hades folder (next to x64). The original SDL2.dll is kept as SDL2_orig.dll.
cd /d "%~dp0x64"
if not exist SDL2_orig.dll (
	ren SDL2.dll SDL2_orig.dll || goto :error
)
copy /y "%~dp0Content\Mods\HadesCoop\native\SDL2.dll" SDL2.dll >nul || goto :error
echo HadesCoop native bridge installed.
exit /b 0
:error
echo Failed. Is the game running?
exit /b 1
