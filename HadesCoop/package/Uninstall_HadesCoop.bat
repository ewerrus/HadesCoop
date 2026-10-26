@echo off
chcp 65001 >nul
rem Удаление HadesCoop: возвращает оригинальный SDL2.dll и скрипты игры. ModUtil остаётся.
cd /d "%~dp0"
if not exist "x64\Hades.exe" (
	echo Этот файл нужно запускать из папки игры Hades.
	goto :fail
)
tasklist /fi "imagename eq Hades.exe" | find /i "Hades.exe" >nul && (
	echo Закрой игру и запусти удаление ещё раз.
	goto :fail
)

if exist "x64\SDL2_orig.dll" (
	del /f "x64\SDL2.dll" || goto :fail
	ren "x64\SDL2_orig.dll" SDL2.dll || goto :fail
	echo Оригинальный SDL2.dll возвращён.
)
if exist "Content\Mods\HadesCoop" (
	rmdir /s /q "Content\Mods\HadesCoop" || goto :fail
)
cd /d "%~dp0Content"
if exist modimporter.exe (
	(echo.& echo.) | "%~dp0Content\modimporter.exe" >nul
)
echo HadesCoop удалён.
pause
exit /b 0

:fail
echo Удаление не завершено.
pause
exit /b 1
