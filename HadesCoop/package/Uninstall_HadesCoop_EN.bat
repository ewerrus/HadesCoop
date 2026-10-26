@echo off
rem Removes HadesCoop: restores the original SDL2.dll and game scripts. ModUtil stays.
cd /d "%~dp0"
if not exist "x64\Hades.exe" (
	echo Run this file from the Hades game folder.
	goto :fail
)
tasklist /fi "imagename eq Hades.exe" | find /i "Hades.exe" >nul && (
	echo Close the game and run the uninstaller again.
	goto :fail
)

if exist "x64\SDL2_orig.dll" (
	del /f "x64\SDL2.dll" || goto :fail
	ren "x64\SDL2_orig.dll" SDL2.dll || goto :fail
	echo Original SDL2.dll restored.
)
if exist "Content\Mods\HadesCoop" (
	rmdir /s /q "Content\Mods\HadesCoop" || goto :fail
)
cd /d "%~dp0Content"
if exist modimporter.exe (
	(echo.& echo.) | "%~dp0Content\modimporter.exe" >nul
)
echo HadesCoop removed.
pause
exit /b 0

:fail
echo Uninstall was not completed.
pause
exit /b 1
