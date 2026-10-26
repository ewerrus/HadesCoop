@echo off
chcp 65001 >nul
rem Установка HadesCoop (текст в игре на русском). Этот файл должен лежать в папке Hades (рядом с Content и x64).
cd /d "%~dp0"
if not exist "x64\Hades.exe" (
	echo Этот файл нужно положить в папку игры Hades, рядом с папками Content и x64.
	echo Steam: ПКМ по Hades - Управление - Посмотреть локальные файлы.
	goto :fail
)
if not exist "Content\Mods\HadesCoop\native\SDL2.dll" (
	echo Не найдена папка Content\Mods\HadesCoop. Скопируй в папку игры всё содержимое GameFolder.
	goto :fail
)
tasklist /fi "imagename eq Hades.exe" | find /i "Hades.exe" >nul && (
	echo Закрой игру и запусти установку ещё раз.
	goto :fail
)

echo [1/3] Мост SDL2.dll (оригинал сохраняется как SDL2_orig.dll)
if not exist "x64\SDL2_orig.dll" (
	ren "x64\SDL2.dll" SDL2_orig.dll || goto :fail
)
copy /y "Content\Mods\HadesCoop\native\SDL2.dll" "x64\SDL2.dll" >nul || goto :fail

echo [2/3] Язык текста в игре: русский
> "Content\Mods\HadesCoop\HadesCoopLang.lua" (
	echo -- HadesCoop: language of the on-screen text. Written by the installer.
	echo ModUtil.Mod.Register^( "HadesCoop" ^)
	echo HadesCoop.Language = "ru"
) || goto :fail

echo [3/3] Подключение мода к скриптам игры (modimporter)
cd /d "%~dp0Content"
(echo.& echo.) | "%~dp0Content\modimporter.exe" >nul || goto :fail

echo.
echo Готово. Запускай Hades как обычно через Steam.
pause
exit /b 0

:fail
echo.
echo Установка не завершена.
pause
exit /b 1
