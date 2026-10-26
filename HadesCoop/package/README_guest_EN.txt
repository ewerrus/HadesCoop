HadesCoop: online co-op, program for the guest (player 2)

1. Connect a gamepad (Xbox or any pad Windows sees as XInput).
2. Run HadesCoopGuest.exe and enter the host's address (IP from Radmin VPN /
   ZeroTier, or the host's external IP if UDP port 26150 is forwarded).
3. The line "Host responds, ping ... ms" means the connection works.
   (The program speaks English unless Windows is in Russian; force it with --en.)
4. Watch the game through the host's stream (Discord, Steam, etc.).

Test without a gamepad: HadesCoopGuest.exe <address> 26150 --test
(player 2 will run in circles and attack).
