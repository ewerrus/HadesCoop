@echo off
rem Launch Hades and save HadesCoop mod output (Lua print) to a file.
rem Put this file in the Hades folder (next to Content and x64). Steam must be running.
cd /d "%~dp0x64"
rem steam_appid.txt keeps Steam from relaunching the game (that would lose the log)
if not exist steam_appid.txt echo 1145360> steam_appid.txt
rem Tells the mod that stdout is redirected and safe to print to
set HADESCOOP_LOG=1
Hades.exe > "%~dp0Content\Mods\HadesCoop\coop_log.txt" 2>&1
