## Project Status (table below is April 2026 unless a row says otherwise)

> **⚠ READ THIS BEFORE TRUSTING ANY ROW.** These are IMPLEMENTATION counts, and
> the Jul-Aug 2026 audits proved implementation is NOT delivery. "100% mechanics
> compliance" was true and simultaneously Quests were unplayable end to end, four
> Compendium chapters were unreachable in campaign play, and the p.137 salvage
> table had never rolled. A mechanic counts as present here if the code exists —
> not if the player can reach it. Treat every row as a lead to verify, never as
> evidence a feature works. See the Aug 6 delivery audit above.

| Metric | Value |
|--------|-------|
| Version | **0.9.7-dev** |
| Game Mechanics Compliance | **100% IMPLEMENTED** (170/170) — see the warning above; implemented ≠ delivered |
| Core Rules Systems | 11/11 verified |
| QA Rules Accuracy Audit | **925/925 values verified** (0 UNVERIFIED) — data accuracy only, says nothing about reachability |
| Wiring lints (Aug 6 2026) | `signal_wiring` / `tscn_connections` / `autoload_lookups` / `data_ownership` all **CLEAN**; `orphan_assets` orphans **0** (41 test-only files remain as a tracked backlog) |
| Test suite (Aug 6 2026) | **2254/2254** unit cases, 194 suites · `verify_battle_ui` 79/79 · `verify_post_battle` 46/46 |
| Campaign Turn Phases | 9/9 fully wired |
| Campaign Creation | 7-phase coordinator system |
| Bug Hunt Gamemode | Phases 1-7 complete (38 files) |
| Planetfall Gamemode (Session 54-57) | §1-4 COMPLETE, 63 files, 18-step turn flow runtime-verified, MainMenu button wired, save/load round-trip PASS |
| Tactics Gamemode (Session 55-57) | ALL 7 PHASES implemented, 59 files, 108 costs verified, 9 runtime bugs fixed, 5/7 scenarios PASS |
| Store/Paywall System (Phase 24) | Tri-platform (Steam/Android/iOS) |
| Fabricated Data Purge | Complete — MoraleSystem deleted, equipment/loot/advancement rewritten |
| Equipment Effects Pipeline (Session 47) | 12 phases: trait fixes, armor saves, single-use removal, protective devices, consumables, gun mods, utility devices, on-board items, Compendium traits |
| PostBattle Orchestrator (Session 47) | CampaignPhaseManager rewired to 14-step decomposed PostBattlePhase (was using old 5-step stub) |
| New World Arrival UI (Session 47) | World trait display, rival follow results, forge license mechanic, travel event mutations |
| Character Events (Session 51) | 30 D100 events fully wired — status_effects persistence, UI JSON lookup, turn countdown, 6 enforcement gates, dashboard pills, item mutation |
| Strange Characters (Session 52) | 16/16 species gameplay wired — Unity Agent, Bot armor saves, Hulker restriction, Primitive limits, Empath bonus, implant capacity |
| Upkeep Failure (Session 52) | Sick Bay exclusion, crew lockout enforced, sell-for-upkeep, dismiss crew, ship seizure |
| Battle Reconciliation (Session 48d) | CampaignTurnController is live path, BattleTransitionUI bypassed, tier in PreBattleUI, rich result (20+ fields) |
| Terrain Generator (Session 50) | 8-phase overhaul: shape placement fixes, 10 world traits, scatter visible, legend, rules badges, seeded RNG, planet→theme |
| Event Queue System | CrewTaskEventDialog (26 event types, state mutations wired) |
| Story Points (Session 43) | Fully integrated — earning (turn+battle), 5 spend types, XP picker, dashboard sync, Stars of the Story |
| Difficulty System | 5 Core Rules modes + 12 Compendium toggles + Progressive Difficulty (2 options) |
| Legal Stack (Session 40b) | EULA screen, privacy policy, consent manager, data export/delete, GitHub Pages docs |
| Compendium Library (Session 40b) | 10 categories, 340+ items, game-icons.net icon SOP |
| Modiphius Partnership | Ask list created (`docs/MODIPHIUS_ASK_LIST.md`) — 7 legal blockers, 6 publishing blockers |
| UX Design Checklist | **59/81** done (7 partial, 15 blocked/post-launch) |
| Tutorial/Onboarding | First-run + dashboard tutorials, TutorialOverlay (L95, Deep Space theme) |
| Accessibility Settings | Colorblind (4 modes) + Reduced Motion + Font Size (Small/Normal/Large) |
| Compile Errors | 0 |
| GDScript Files | ~900 (excl. addons — 10 dead files deleted Session 40, 14 legal files added Session 40b) |

---

---

*Extracted from `CLAUDE.md` on 2026-08-06 to keep the always-loaded file small. The durable rules from this audit remain inline in CLAUDE.md; this file is the full narrative record.*
