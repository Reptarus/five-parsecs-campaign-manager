# Five Parsecs from Home — Campaign Manager

**Status:** QA Sprint Fixes Complete — ready for verification QA run
**Urgency:** High
**Last win:** QA Sprint Fix Plan complete (Mar 16) — 18/22 bugs fixed + 4 UX + 3 optimizations across 22 files, zero compile errors
**Blocked by:** Verification QA run to confirm all fixes; IRL play session not yet scheduled
**Next:** Run MCP-automated QA verification (campaign creation + world phase + battle), then schedule IRL test session

## Notes
- **Engine**: Godot 4.6-stable, pure GDScript, ~900 source files
- **Game mechanics compliance**: 100% (170/170 mechanics verified)
- **Campaign turn phases**: 9/9 fully wired (STORY -> TRAVEL -> UPKEEP -> MISSION -> POST_MISSION -> ADVANCEMENT -> TRADING -> CHARACTER -> RETIREMENT)
- **Battle system**: Tabletop companion model (text instructions for physical play), 3-tier tracking (LOG_ONLY / ASSISTED / FULL_ORACLE), 26 companion panels
- **DLC system**: 3 packs (Trailblazer / Freelancer / Fixer), 35 ContentFlags, tri-platform store (Steam/Android/iOS)
- **Bug Hunt gamemode**: Complete standalone military variant, 38 files, 3-stage campaign turn
- **MCP UI testing**: 71+ bugs found and fixed across 12+ automated sessions
- **QA Sprint (Mar 16)**: 22 bugs found via full QA playthrough, 18 fixed in 7 sprints (P0 signal chain, ship values, terrain overhaul, captain flag, world gen params, patron formula, name randomizer)
- **Zero compile errors** across all ~900 scripts
- **Repository**: https://github.com/Reptarus/five-parsecs-campaign-manager
- This project has a real finish line — don't let it linger in "almost done" state
- Persistent test campaign data from prior sessions is OUTDATED (ship hull/debt values changed)
