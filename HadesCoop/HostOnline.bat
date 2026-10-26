@echo off
rem HadesCoop online host: launches Hades with the log and waits for the guest's gamepad
rem on UDP port 26150 (HadesCoopGuest.exe on the friend's PC sends it there).
rem Put this file in the Hades folder (next to Content and x64). Steam must be running.
cd /d "%~dp0x64"
if not exist steam_appid.txt echo 1145360> steam_appid.txt
set HADESCOOP_LOG=1
set HADESCOOP_HOST_PORT=26150
Hades.exe > "%~dp0Content\Mods\HadesCoop\coop_log.txt" 2>&1
