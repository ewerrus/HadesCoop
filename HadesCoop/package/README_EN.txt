HadesCoop 0.31 — two-player co-op for Hades (the first game)
=============================================================

The second player controls their own hero with a second gamepad: their own
attacks, dash, cast, boons, weapon, health and a HUD in the bottom-right
corner. Works in runs and in the House of Hades, and player 2's build is
saved together with the run.

REQUIREMENTS
- Hades on Steam, latest version (patch 38290). If the game updates, the
  bridge disables itself and the game starts without co-op.
- Two gamepads (the second one is for player 2).
- Windows 10/11, the regular 64-bit game launched from Steam.

INSTALLATION
1. Open the game folder: Steam — right-click Hades — Manage — Browse local
   files. It contains the Content and x64 folders.
2. Copy EVERYTHING from the GameFolder folder there (replace files).
3. Close the game and run Install_HadesCoop_EN.bat from the game folder.
   (Install_HadesCoop.bat installs the same mod with Russian on-screen text.)
4. Start Hades as usual.

It's a good idea to back up your saves first:
  Documents\Saved Games\Hades

If Steam verifies or updates the game files, just run Install_HadesCoop_EN.bat
again.

HOW TO PLAY
- The first time you enter the House of Hades after launching the game, a
  mode menu appears:
    Single player     — no second player;
    Co-op: alternate  — room rewards go to the players in turns;
    Co-op: double     — each player gets their own reward (boons, Daedalus
                        Hammer, Hermes, Pom of Power); the doors open once
                        both are picked up.
- To open the menu again: player 2 holds Back (View) for about a second
  while in the House.
- The choice is stored in your save and applies from the next room.
- If player 2 falls, they come back in the next room with part of their
  health. The run ends when player 1 dies.
- The Mirror of Night is shared (it comes from the save); Death Defiance
  charges are separate for each player.

ONLINE (experimental, barely tested)
Player 2 can play over the network with their own gamepad:
- The host (who owns the game) launches Hades with HostOnline.bat from the
  game folder instead of Steam (Steam itself must be running). UDP port
  26150 must be open, or both players must be in the same VPN network
  (Radmin VPN, ZeroTier).
- The guest doesn't need the game: give them the OnlineGuest folder with
  HadesCoopGuest.exe and its instructions. The guest watches the game
  through the host's stream (Discord, Steam).

UNINSTALLING
Close the game and run Uninstall_HadesCoop_EN.bat from the game folder: it
restores the original SDL2.dll, returns the game scripts to normal and
deletes the mod folder. ModUtil stays (other mods use it, and on its own it
changes nothing).

KNOWN LIMITATIONS
- The mod is a work in progress: crashes and oddities are possible,
  especially in boss fights (bosses don't yet pick targets well between
  two players).
- There is no co-op option in the main menu — the mode is chosen in the
  House.
- Your antivirus may complain about SDL2.dll: it is a proxy library that
  connects the second gamepad to the game engine.

IF SOMETHING GOES WRONG
Send the author the file x64\HadesCoopNative.log from the game folder — it
shows what happened.

Included: ModUtil and modimporter (MIT license, see the Licenses folder).
