# Runs HadesCoop offline Lua tests with the game's own lua52.dll (Lua 5.2).
# Usage: pwsh run_tests.ps1 [-GameDir Z:\SteamLibrary\steamapps\common\Hades]
param( [string]$GameDir = 'Z:\SteamLibrary\steamapps\common\Hades' )

$dll = Join-Path $env:TEMP 'lua52.dll'
Copy-Item (Join-Path $GameDir 'x64\lua52.dll') $dll -Force -ErrorAction SilentlyContinue
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class HadesCoopLua {
 const string D = "$($dll -replace '\\','\\')";
 [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr luaL_newstate();
 [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern void luaL_openlibs(IntPtr L);
 [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern int luaL_loadstring(IntPtr L, byte[] s);
 [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern int lua_pcallk(IntPtr L, int n, int r, int e, IntPtr c, IntPtr k);
 [DllImport(D, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr lua_tolstring(IntPtr L, int i, IntPtr len);
}
"@

$root = Split-Path $PSScriptRoot -Parent
$modPath = (Join-Path $root 'HadesCoop.lua') -replace '\\', '/'
$testPath = (Join-Path $PSScriptRoot 'damage_test.lua') -replace '\\', '/'
# print -> collected output; Lua strings are byte strings, decode as UTF-8 afterwards
$prelude = "HADESCOOP_PATH = '$modPath'; local out = {}; print = function(...) local t = {} for i = 1, select('#', ...) do t[#t+1] = tostring((select(i, ...))) end out[#out+1] = table.concat(t, ' ') end; local ok, err = pcall(dofile, '$testPath'); out[#out+1] = ok and 'EXIT OK' or ('ERROR: ' .. tostring(err)); return table.concat(out, '\n')"

$L = [HadesCoopLua]::luaL_newstate()
[HadesCoopLua]::luaL_openlibs($L)
[void][HadesCoopLua]::luaL_loadstring($L, [Text.Encoding]::UTF8.GetBytes($prelude) + [byte]0)
[void][HadesCoopLua]::lua_pcallk($L, 0, 1, 0, [IntPtr]::Zero, [IntPtr]::Zero)
$ptr = [HadesCoopLua]::lua_tolstring($L, -1, [IntPtr]::Zero)
$len = 0; while ([Runtime.InteropServices.Marshal]::ReadByte($ptr, $len) -ne 0) { $len++ }
$bytes = New-Object byte[] $len
[Runtime.InteropServices.Marshal]::Copy($ptr, $bytes, 0, $len)
$text = [Text.Encoding]::UTF8.GetString($bytes)
$text
if ($text -notmatch 'ALL TESTS PASSED') { exit 1 }
