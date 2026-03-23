# Five Parsecs from Home — Campaign Manager

**Status:** Data Verification Complete — all game data verified against rulebooks, ready for runtime QA
**Urgency:** Medium
**Last win:** Phase 48 Full Book Verification (Mar 23) — ~900/925 values verified against Core Rules + Compendium source text, 190+ fixes applied, 145+ fabricated values removed, zero compile errors
**Blocked by:** Runtime QA playthrough to verify all data fixes work in gameplay; IRL play session
**Next:** Run MCP-automated QA verification (campaign creation + world phase + battle), then schedule IRL test session

## Notes
- **Engine**: Godot 4.6-stable, pure GDScript, ~900 source files
- **Game mechanics compliance**: 100% (170/170 mechanics verified)
- **Data accuracy**: ~900/925 values verified against Core Rules + Compendium (97%)
- **Campaign turn phases**: 9/9 fully wired (STORY -> TRAVEL -> UPKEEP -> MISSION -> POST_MISSION -> ADVANCEMENT -> TRADING -> CHARACTER -> RETIREMENT)
- **Battle system**: Tabletop companion model (text instructions for physical play), 3-tier tracking (LOG_ONLY / ASSISTED / FULL_ORACLE), 26 companion panels
- **DLC system**: 3 packs (Trailblazer / Freelancer / Fixer), 35 ContentFlags, tri-platform store (Steam/Android/iOS)
- **Bug Hunt gamemode**: Complete standalone military variant, 38 files, 3-stage campaign turn
- **MCP UI testing**: 71+ bugs found and fixed across 12+ automated sessions
- **Data verification (Phases 46-48)**: All 12 data domains cross-referenced against core_rulebook.txt + compendium_source.txt. Motivation table 13 errors fixed, 3 missing Strange Characters added, 5 fabricated weapons removed, 4 Compendium tables rewritten from scratch, salvage rules rewritten, starting credits/upkeep conflicts resolved
- **Zero compile errors** across all ~900 scripts
- **Repository**: https://github.com/Reptarus/five-parsecs-campaign-manager
- This project has a real finish line — don't let it linger in "almost done" state
