Five Parsecs Campaign Manager — Internal Testing Build
======================================================
Version: 0.9.7-dev
Date: April 17, 2026
Engine: Godot 4.6-stable (Windows x86_64)

Build Notes (April 17 update):
- Fixed battle auto-resolve infinite loop (battles now resolve correctly)
- Fixed screen saves being incorrectly bypassed in combat resolution
- 125/125 battle system tests passing

RUNNING THE APP
---------------
1. Extract all files to the same folder
2. Double-click FiveParsecs.exe to launch
3. FiveParsecs.pck must be in the same folder as the .exe

Note: FiveParsecs.console.exe is a console wrapper that shows
debug output — use FiveParsecs.exe for normal testing.

WHAT TO TEST
------------
- Main Menu: Campaign Creation, Load Game, Planetfall, Tactics, Bug Hunt, Battle Simulator
- Campaign Creation: 7-step wizard (Config > Captain > Crew > Equipment > Ship > World > Review)
- Campaign Turns: 9-phase loop (Story > Travel > Upkeep > Mission > Post-Mission > Advancement > Trading > Character > Retirement)
- Planetfall: 18-step colony building turn flow
- Tactics: Army builder with species lists
- Settings: Accessibility options (colorblind modes, font size, reduced motion)

KNOWN LIMITATIONS
-----------------
- No app icon on the .exe yet (pending official artwork from Modiphius)
- Steam features inactive (placeholder App ID)
- DLC purchases show "offline mode" — this is expected without store backend
- Some placeholder art (colored initials for character portraits)

FEEDBACK
--------
Please note any crashes, UI issues, or unclear workflows.
Contact: elijahrhyne@gmail.com
