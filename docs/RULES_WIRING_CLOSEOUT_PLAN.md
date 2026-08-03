# Rules Wiring — Closeout Plan

**Ground truth Aug 3 2026: 73 open / 7 partial / 62 fixed of 143 rows.**
Branch `campaign-editor-and-fixits`. Companion to `RULES_WIRING_AUDIT_2026-08.md`
(the ledger); this file is the *route*, the ledger is the *record*.

---

## 0. Re-measure before you trust any count

The header count has drifted twice, in both directions. Never plan off it — count
the rows:

```powershell
py -c "
import pathlib, collections
rows=[]
for l in pathlib.Path('docs/RULES_WIRING_AUDIT_2026-08.md').read_text(encoding='utf-8').split(chr(10)):
    if not l.startswith('| '): continue
    c=[x.strip() for x in l.strip().strip('|').split('|')]
    if len(c)<5 or c[0] in ('Domain','Area') or set(c[0])<=set('- '): continue
    rows.append((c[0], c[-1]))
print(collections.Counter(s.split()[0].rstrip(chr(8212)) for _,s in rows))
print(collections.Counter(d for d,s in rows if s.startswith('OPEN')))
"
```

A status cell can read `OPEN — VERDICT CONFIRMED …`, so matching on the literal
`| OPEN |` undercounts. Match on `startswith('OPEN')`.

**Also re-verify a row before you work it.** Two of two spot-checks today were
stale — Patron Time Frame (L93) and the p.123 XP keys (L80) had both shipped
weeks earlier under a different row's commit. Rows written before the July/August
sprints describe a codebase that no longer exists. Reading the row is not
verification; reading the code is.

---

## 1. The shape of what is left

| Domain | Open | Reachable without DLC? |
|---|---|---|
| factions-world-compendium | 20 | No — Compendium expansion |
| missions-elites-zones | 20 | Partly (Red/Black Zone yes; Salvage/Stealth/Elite no) |
| economy-trade-equipment | 13 | **Yes, every turn** |
| post-battle | 6 | **Yes, every battle** |
| battle-setup | 5 | **Yes, every battle** |
| patrons-rivals-quests | 4 | **Yes** |
| turn-upkeep-travel | 4 | **Yes, every turn** |
| battle-resolution | 1 | Yes |

**The headline: 40 of 73 are DLC or endgame content.** Factions (20) are invisible
without the expansion; most of missions-elites-zones is Salvage / Stealth /
Street Fight / Elite enemies, all DLC-gated. A tablet tester playing a standard
campaign for an evening cannot reach any of them.

**The core loop is ~33 rows**, and **6 of those are blocked** on another
session's uncommitted work (§4). So the realistic near-term target is **27 rows**,
not 73.

Size mix across all 73: 9 large, 28 medium, 26 small, 10 one-line.

---

## 2. Sequencing principles

1. **Will a tablet tester hit this in one sitting?** Not finding count, not
   domain tidiness. This has been the rule all sprint and it still is.
2. **Fix producers before consumers, and expect a chain.** Today's injury work
   exposed three further layers, each invisible until the one above it worked —
   a pipeline with a dead source looks exactly like one with no consumers.
3. **A visible switch that does nothing is worse than a missing feature.** Where
   a block is being deferred, hide its toggle in the same commit (§6).

---

## 3. Phases

### Phase A — Ledger hygiene · no code · ½ session

Cheapest possible reduction: some rows are the same finding written twice from
two domains' points of view. Confirmed duplicate pairs:

| Pair | Finding |
|---|---|
| L54 ≡ L92 | Spending credits for +1 on crew tasks / 3-credit extra Trade roll |
| L59 ≡ L20 | Affiliated Patron jobs → faction Loyalty |
| L18 ≡ L109 | Faction generation (existence vs quantity/types) |
| L28 ≡ L110 | Fringe World Strife arrival check vs Instability tracking |
| L137 ≡ L138 | The fabricated shop economy (prices vs the market system) |

Merge each into one row, and re-verify any row whose text predates the July
sprints. Expect this phase alone to remove 5-8 rows without touching code.

---

### Phase B — One damage vocabulary · 1 session · **START HERE**

There are **four spellings of "this item is broken"**, and three of them no gate
honours. This is the single highest ratio of reach to effort left on the board,
and it is cheap *only because* the injury work just built the producer and the
repair path.

| Key | Written by | Read by |
|---|---|---|
| `item_damaged` status marker | Injury Table (p.122), Character Events, travel Accident | **Repair Your Kit (p.78)** |
| `damaged: true` on the item | Campaign Event 45-48 (p.127) | **Assign Equipment `[DAMAGED]`, Purchase Items sell-block** |
| `needs_repair` + `quality:"damaged"` | `LootTableResolver` (loot 26-45) | a `(damaged)` label, nothing else |
| `requires_repair` | post-battle loot entries | a `(damaged)` label, nothing else |

Loot rolls 26-45 are **20% of every loot result** and the book says those items
"cannot be used until Repaired". Today they are fully usable, fully sellable, and
Repair Your Kit cannot see them.

Closes **L35** (damaged loot needs Repair), **L136** (the sell restriction that
is inert because nothing writes the key), and most of **L38** (Loot Table single
source of truth). Verify at the *consumer*: a damaged loot item must show
`[DAMAGED]`, refuse to sell, and be findable by the repair task.

---

### Phase C — Post-battle core loop · 1-2 sessions · 4 of 6 blocked

**Unblocked now:**
- **L143 — the Ability Increase Table is spent, not rolled (p.123).** Step 9 of
  the wizard says "Roll for advancement" and prints `Rolled 5 - …` that changes
  nothing; the real XP-spend UI is buried on the character sheet. A tester sees
  this lie after *every single battle*. Highest-visibility row in the phase.
- **L84 — Medical school / Bot technician injury rerolls (p.125).** 20 XP and
  10 XP buy nothing. Newly worth doing: as of today there is a real Injury Table
  with real consequences to reroll against, so the benefit is finally meaningful.

**Blocked** (see §4): L75 Precursor double-roll, L83 + L170 Character Events,
L169 Campaign Events.

---

### Phase D — Turn / upkeep / world · 1 session

- **L177** — Train banks XP that sits unspent (p.77 says resolve immediately);
  Find a Patron offers an EXISTING Patron rather than a new one.
- **L176** — a character whose last Sick Bay turn ticks off walks straight into
  Crew Tasks the same turn. One extra task per recovery, every recovery.
- **L175** — fleeing an Invasion is consequence-free: you keep every Rival and
  Patron from the world you fled, so fleeing is strictly better than staying.
- **L96** — `crew_retired` never archives to LegacySystem (one-line).
- Partials to finish here: **L88** step 3 Freelancer License, **L54/L92** the
  3-credit extra Trade roll, **L173** the 12 world traits that have a resolver
  and need only a call site.

---

### Phase E — Battle setup residuals · ½ session

Small, and all in files already owned this sprint (`EnemyGenerator`,
`CampaignTurnController`).

- **L44** Guardian-AI Unique must attach to a figure (27 of 100 Unique results).
- **L47** the Deployment Conditions panel renders blank for every battle and its
  buttons act on nothing — a tester sees this immediately.
- **L158** Notable Sights: the app tells you a Person of Interest is 11" away and
  worth +1 story point, and reaching them awards nothing.
- **L46** Environmental hazard, **L159** Slippery ground reminder,
  **L146** the fabricated elevation / over-range to-hit modifiers.

---

### Phase F — Patrons / rivals · ½ session + one design call

- **L162** — a Rival ambush fights the Patron job's enemy type on the Patron
  objective table and still collects that job's Danger Pay. Wrong column again;
  same family as the two fixed yesterday.
- **L163** — Hold the Field against a Rival whose figures all Bail on Morale and
  the p.119 removal roll never happens, so you can never shake that Rival.
- **L139 — the design call.** "Find a Patron" is supposed to *gate whether a job
  offer exists at all* (p.77). Today offers appear every turn regardless, so the
  crew task is pointless and the offer list bloats to 6-12 jobs. This is the same
  cadence question flagged with **Busy** (p.84) and should be decided once, for
  both, before either is wired. The book never states a per-turn offer rate — it
  needs a judgement call, not a page citation.
- **L50** Private Transport — blocked (§4), one early-return away.

---

### Phase G — Red & Black Zone · 1-2 sessions

Nine rows (**L60, L63, L64, L65, L66, L67, L68, L119, L164, L166**). Endgame, but
**reachable in a standard campaign with no DLC** — 10+ turns and a license. A
long tablet session will not reach it; a returning tester with a saved campaign
will. The player is currently *told* about Threat Conditions, Time Constraints
and improved rewards that do not exist, which is the placebo-switch problem in
miniature.

---

### Phase H — Expanded Missions · ½ session

**L167** renders `OVERVIEW: `, `SPECIFIC OBJECTIVE: `, `TIME CONSTRAINT: ` with
nothing after the colon — a visible defect on the job-details panel. **L165**
promises two objectives and lists one. **L140** applies Patron-only special
conditions to Opportunity missions. All small; two are cosmetic bugs a tester
will report on sight, so they punch above their size.

---

### Phases I-K — DLC blocks · deferred for the tablet test

| Phase | Rows | Why deferred |
|---|---|---|
| I — Salvage / Stealth / Street Fight | L61, L69, L70, L71, L141 | The panels never instantiate; every battle is Conventional. Needs the mission-type plumbing first, then five rows of rules. |
| J — Elite-Level Enemies | L62 | One large row: Elite Composition, Captain, Leadership Panic table, Better Loot, Elite Rivals. |
| K — Factions + Fringe World Strife | 20 rows | The largest single block. A brand-new campaign has zero factions for its entire life, so nothing downstream can be observed. Must start at generation (L18/L109) — every other faction row is gated on it. |
| K2 — The 12 Compendium difficulty toggles | L30 | Each is a full rule variant needing its own book verification. |

**Order within K if it is ever taken up:** generation → Loyalty → Faction Jobs →
Activities → Events → Destruction. Doing any of the later ones first produces
code that cannot be exercised.

---

## 4. Blocked, and the unblock condition

Six items sit in files held by the parallel **Story Track** session (36
uncommitted files). Committing by explicit path has kept the trees disjoint all
sprint; that discipline holds until they land.

| Row | File held |
|---|---|
| L75 Precursor double-roll | `PostBattlePhase.gd`, `CharacterEventEffects.gd` |
| L83 Character Events 11-12 / 20-23 / 63-66 / 72-75 | `CharacterEventEffects.gd` |
| L170 Character Events 52-55 / 24-26 / 42-45 / 67-68 | `CharacterEventEffects.gd` |
| L169 Campaign Events 79-81 / 98-100 / 57-59 / 82-84 | `CampaignEventEffects.gd` |
| L112 Gather the Loot — one roll per battle | `LootProcessor.gd` |
| L50 (partial) Private Transport | `RivalEncounterCheck.gd` |

**Unblock = that session commits.** Until then, do not edit those five files —
and note that L83/L169/L170 are three rows in two files, so they should be done
as one pass the moment it clears.

---

## 5. Residuals that are NOT rules gaps

Recorded so nobody re-opens them as findings:

- **Auto-resolve cannot produce `first_casualty_by` / `unique_kills`.** The
  played path asks the player (that is the fix that landed); a simulated fight
  has no notion of whose shot landed first. An auto-resolved battle under-pays by
  up to 2 XP. Deriving it would be fabricating battle detail.
- **`fled_early_crew` has no producer** (L124, already marked CORRECTED). The app
  tracks bail-outs for enemies only. The read side is correct the moment a
  producer lands.
- **Busy (p.84) is a cadence question, not a missing flag.** Wiring
  `offers_new_job_on_success()` as written is a provable no-op. Bundle with L139.
- **Elite Rank perks (p.65) need player-choice UI** the creation wizard has no
  concept of: `extra_starting_characters` widens the candidate pool rather than
  adding crew, and the XP is "assigned to any characters you like".

---

## 6. Definition of done for the tablet test

**Not 73 → 0.** The honest target is:

1. **Core-loop bucket to zero** — Phases B, C, D, E, F, H (~27 rows once the
   blocked six clear). These are what a tester touches in one evening.
2. **Phase G (Red/Black Zone) to zero** if a returning tester will load a
   long-running save. Otherwise defer *with the UI honest* — see 3.
3. **Every deferred block's toggle hidden or labelled.** Factions, Elite Enemies,
   Stealth/Salvage/Street, Terrain Generation and the 12 difficulty toggles are
   currently **visible switches that change nothing**. Hiding them is hours of
   work against weeks of implementation, and it converts "this app is broken"
   into "this isn't in yet" — the single highest-value thing on this page for a
   test session.

A tester who never sees a dead switch will report real bugs instead of
cataloguing placebos.

---

## 7. Rough ordering

| # | Phase | Effort | Rows |
|---|---|---|---|
| 1 | A — ledger hygiene | ½ session | −5 to −8 (no code) |
| 2 | B — one damage vocabulary | 1 session | 3 |
| 3 | E — battle setup residuals | ½ session | 6 |
| 4 | D — turn / upkeep / world | 1 session | 4 + 3 partials |
| 5 | C — post-battle (unblocked half) | 1 session | 2 |
| 6 | H — Expanded Missions | ½ session | 3 |
| 7 | F — patrons / rivals (+ the cadence call) | ½ session | 3 |
| 8 | **§6.3 — hide the dead toggles** | ½ session | 0 rows, highest test value |
| 9 | C — post-battle (blocked half), when the tree clears | 1 session | 4 |
| 10 | G — Red & Black Zone | 1-2 sessions | 10 |
| — | I / J / K | post-tablet | 26 |

Phases 1-8 are the pre-tablet run: roughly **5 sessions to a core loop with no
known rules gaps and no lying UI.**
