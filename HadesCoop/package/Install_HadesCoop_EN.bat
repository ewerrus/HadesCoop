@echo off
rem Installs HadesCoop with English on-screen text. This file must be in the Hades folder (next to Content and x64).
cd /d "%~dp0"
if not exist "x64\Hades.exe" (
	echo Put this file into the Hades game folder, next to the Content and x64 folders.
	echo Steam: right-click Hades - Manage - Browse local files.
	goto :fail
)
if not exist "Content\Mods\HadesCoop\native\SDL2.dll" (
	echo Content\Mods\HadesCoop not found. Copy everything from GameFolder into the game folder.
	goto :fail
)
tasklist /fi "imagename eq Hades.exe" | find /i "Hades.exe" >nul && (
	echo Close the game and run the installer again.
	goto :fail
)

echo [1/3] SDL2.dll bridge (the original is kept as SDL2_orig.dll)
if not exist "x64\SDL2_orig.dll" (
	ren "x64\SDL2.dll" SDL2_orig.dll || goto :fail
)
copy /y "Content\Mods\HadesCoop\native\SDL2.dll" "x64\SDL2.dll" >nul || goto :fail

echo [2/3] On-screen text language: English
> "Content\Mods\HadesCoop\HadesCoopLang.lua" (
	echo -- HadesCoop: language of the on-screen text. Written by the installer.
	echo ModUtil.Mod.Register^( "HadesCoop" ^)
	echo HadesCoop.Language = "en"
) || goto :fail

echo [3/3] Hooking the mod into the game scripts (modimporter)
cd /d "%~dp0Content"
(echo.& echo.) | "%~dp0Content\modimporter.exe" >nul || goto :fail

echo.
echo Done. Start Hades from Steam as usual.
pause
exit /b 0

:fail
echo.
echo Installation was not completed.
pause
exit /b 1
