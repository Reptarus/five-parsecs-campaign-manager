#### Battle-phase audit sprint (Jul 30-31 2026) — rules now APPLIED, not just displayed

The recurring defect was one shape: **a value rolled, stored, displayed, and
consumed by nothing.** Read `docs/sop/README.md` anti-regressions before
touching these. All are test-pinned; do not "simplify" them back.

| Rule | Was | Now |
|---|---|---|
| Enemy weapon codes (p.104) | `"2 A"` read as *count 2, column A* — Specialist table unreachable | number = basic column, letter = Specialist column |
| AI Blade rule (p.104 + errata) | never implemented | Rampaging always, Aggressive unless CS +0, never for animals |
| Rival attack types (pp.91-92) | reached one label | Ambush/Brought Friends/Assault/Raid all applied |
| Invasion (p.92) | Notable-Sight skip only | +1 enemy, 6-round hold clock, no Win condition |
| Deployment conditions (p.88) | `apply_condition()` had ZERO callers | crew cap, round-one behaviour, Bitter Struggle panic — applied by `BattleSetupRules`. `apply_condition()` itself was DELETED Aug 6 2026: it was a competing second implementation whose key names nothing read |
| Red/Black Zone (p.150) | display-only | count REPLACED at 7+Numbers, 3 Specialists, Roving Threats |
| Reaction Roll (p.113) | rolled TWICE, results disagreed | one pool roll, best-fit assign, Feral rule |
| p.119 rival removal | read `is_unique`, a key nothing writes | reads `was_unique_individual`/`was_lieutenant` |
| p.119 patron failure | logged only | failed accepted job removes the Patron |
| `units_downed` / `first_casualty_by` / `unique_kills` | no producer | derived / asked on the results form |
| Soulless Bot upgrades (p.17) | book allowed at 1.5x | errata forbids entirely |
| `AdvancementSystem._is_bot()` | checked a method that does not exist | reads the `is_bot` PROPERTY |

**Two traps worth remembering.** `fled_early` means the **p.123 XP rule**
("flees in the first 2 rounds") — NOT the p.91 Rival item-loss window ("before
4 rounds"); they are different windows and conflating them denies XP the book
pays. And "Enemy Morale +1" (p.88 Bitter Struggle) means the Panic range goes
**DOWN** — Compendium p.49's Leadership table settles the direction.

---

*Extracted from `CLAUDE.md` on 2026-08-06 to keep the always-loaded file small. The durable rules from this audit remain inline in CLAUDE.md; this file is the full narrative record.*
