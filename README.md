# HadesCoop

Кооператив на двоих для Hades (первая часть): второй игрок со своим геймпадом,
своими дарами, оружием, здоровьем и HUD. Локально и (экспериментально) по сети.

Two-player co-op mod for Hades (the first game). Player instructions:
[README_EN.txt](HadesCoop/package/README_EN.txt).

## Устройство

- `HadesCoop/HadesCoop.lua` — Lua-часть мода (ModUtil), подключается modimporter'ом
  через `modfile.txt`. `PlayerUnits.sjson` добавляет юнит `_PlayerUnit2`.
- `HadesCoop/HadesCoopLang.lua` — язык текста на экране (`ru`/`en`), его пишет установщик.
- `native/hadescoop_sdl.c` — прокси `SDL2.dll` (оригинал → `SDL2_orig.dll`): второй
  геймпад, создание второго PlayerUnit, патчи движка, сетевой ввод (UDP 26150).
  Рассчитан на EngineWin64s.dll сборки 38290; на другой сборке отключается.
- `native/guest.c` — `HadesCoopGuest.exe`, программа гостя для онлайна.
- `native/tools/` — тестовые программы для моста.

## Сборка

```sh
native/build.sh            # w64devkit gcc → native/build/SDL2.dll, HadesCoopGuest.exe
```

```powershell
pwsh -ExecutionPolicy Bypass -File HadesCoop/tests/run_tests.ps1      # офлайн-тесты Lua
pwsh -ExecutionPolicy Bypass -File HadesCoop/package/make_package.ps1 # архив в dist/
```

`make_package.ps1` берёт ModUtil из папки игры, а modimporter — из `dl/mi/` (не в репозитории).
Готовые архивы — в Releases.
