#!/bin/sh
# Сборка прокси SDL2.dll (w64devkit gcc). Использование: ./build.sh [путь к gcc bin]
set -e
cd "$(dirname "$0")"
BIN="${1:-/c/Users/pankr/AppData/Local/Temp/hcoop/w64devkit/bin}"
HOOKS="SDL_GameControllerOpen SDL_GameControllerClose SDL_GameControllerGetAxis SDL_GameControllerGetButton SDL_JoystickGetButton SDL_PollEvent SDL_PeepEvents"

# Все экспорты оригинала пробрасываются в SDL2_orig.dll, кроме перехваченных
{
	echo "LIBRARY SDL2.dll"
	echo "EXPORTS"
	while read -r name; do
		case " $HOOKS " in
			*" $name "*) echo "    $name" ;;
			*) echo "    $name = SDL2_orig.$name" ;;
		esac
	done < tools/sdl2_exports.txt
} > SDL2.def

mkdir -p build
"$BIN/gcc" -shared -O2 -Wall -o build/SDL2.dll hadescoop_sdl.c SDL2.def -static-libgcc -lws2_32
echo "built build/SDL2.dll"
"$BIN/gcc" -O2 -Wall -o build/HadesCoopGuest.exe guest.c -static -lws2_32 -lwinmm
echo "built build/HadesCoopGuest.exe"
