# Builds the distributable HadesCoop folder and zip in <workspace>\dist.
# Usage: pwsh make_package.ps1 [-GameDir Z:\SteamLibrary\steamapps\common\Hades]
param( [string]$GameDir = 'Z:\SteamLibrary\steamapps\common\Hades' )
$ErrorActionPreference = 'Stop'

$mod = Split-Path $PSScriptRoot -Parent
$root = Split-Path $mod -Parent
$version = ( Select-String -Path "$mod\HadesCoop.lua" -Pattern '^HadesCoop.Version = "(.+)"' ).Matches[0].Groups[1].Value
$name = "HadesCoop_v$version"
$out = Join-Path $root "dist\$name"
if( Test-Path $out ) { Remove-Item $out -Recurse -Force -Confirm:$false }

$game = "$out\GameFolder"
$modOut = "$game\Content\Mods\HadesCoop"
New-Item -ItemType Directory -Force "$modOut\native", "$game\Content\Mods\ModUtil", "$out\OnlineGuest", "$out\Licenses" | Out-Null

$utf8 = New-Object Text.UTF8Encoding $false
$utf8Bom = New-Object Text.UTF8Encoding $true
function Write-Crlf( $source, $target, $encoding )
{
	$text = [IO.File]::ReadAllText( $source ).TrimStart( [char]0xFEFF ).Replace( "`r`n", "`n" ).Replace( "`n", "`r`n" )
	[IO.File]::WriteAllText( $target, $text, $encoding )
}

# Mod: debug panel and engine probe off for players
$lua = [IO.File]::ReadAllText( "$mod\HadesCoop.lua" )
$lua = $lua.Replace( "`tShowProbe = true,", "`tShowProbe = false," ).Replace( "`tShowPanel = true,", "`tShowPanel = false," )
[IO.File]::WriteAllText( "$modOut\HadesCoop.lua", $lua, $utf8 )
Copy-Item "$mod\HadesCoopLang.lua", "$mod\modfile.txt", "$mod\PlayerUnits.sjson" $modOut
Copy-Item "$root\native\build\SDL2.dll" "$modOut\native"
Copy-Item "$GameDir\Content\Mods\ModUtil\*" "$game\Content\Mods\ModUtil"
Copy-Item "$root\dl\mi\modimporter.exe" "$game\Content"

foreach( $bat in 'Install_HadesCoop.bat', 'Install_HadesCoop_EN.bat', 'Uninstall_HadesCoop.bat', 'Uninstall_HadesCoop_EN.bat' )
{
	Write-Crlf "$PSScriptRoot\$bat" "$game\$bat" $utf8
}
Write-Crlf "$mod\HostOnline.bat" "$game\HostOnline.bat" $utf8
Write-Crlf "$PSScriptRoot\README.txt" "$out\README.txt" $utf8Bom
Write-Crlf "$PSScriptRoot\README_EN.txt" "$out\README_EN.txt" $utf8Bom

Copy-Item "$root\native\build\HadesCoopGuest.exe" "$out\OnlineGuest"
Write-Crlf "$mod\online\README_guest.txt" "$out\OnlineGuest\README_guest.txt" $utf8Bom
Write-Crlf "$PSScriptRoot\README_guest_EN.txt" "$out\OnlineGuest\README_guest_EN.txt" $utf8Bom

Copy-Item "$root\dl\mipy\LICENSE" "$out\Licenses\modimporter_LICENSE.txt"
Copy-Item "$GameDir\Content\Mods\ModUtil\LICENSE" "$out\Licenses\ModUtil_LICENSE.txt"

$zip = "$out.zip"
Compress-Archive -Path $out -DestinationPath $zip -Force
"built $zip"
