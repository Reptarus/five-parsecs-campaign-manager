# Core Rules + Compendium wiring audit — Aug 2 2026

Eight parallel auditors, one per subsystem, each required to quote the book, cite `file:line`, and state the player-visible consequence. Bug Hunt, Planetfall and Tactics were out of scope by request.

**152 findings**: 88 NEVER-FIRES, 21 WRONG-VALUE, 13 FABRICATED, 30 PARTIAL.

**Status Aug 3 (late): 64 open / 71 fixed / 7 partial-or-blocked (+1 CORRECTED) of 143.**
Counts are MEASURED, not maintained by hand — the header has drifted twice, in both
directions. Re-count before trusting it; the command is in
`docs/RULES_WIRING_CLOSEOUT_PLAN.md` §0, which is also the route through what is left.
Note a status cell can read `OPEN — VERDICT CONFIRMED …`, so matching the literal
`| OPEN |` undercounts.

`NEVER-FIRES` = implemented, often with book-exact data, but no code path reaches it.
`FABRICATED` = not in either book; project policy is removal.

Status column is for tracking fixes: OPEN / FIXED (commit) / BLOCKED (reason) / CUT (needs user approval).

## NEVER-FIRES (88)

| Domain | Rule | Fix size | Player-visible effect | Status |
|---|---|---|---|---|
| factions-world-compendium | Faction generation — Compendium p.110 "Generating Factions" | medium | A brand-new Standard campaign has ZERO factions for its entire life. With "Expanded Factions" ticked in the setup wizard the player sees nothing: no faction list, no faction jobs, no Loya... | OPEN |
| factions-world-compendium | Faction Jobs — Compendium p.111 | medium | The captain's free, per-turn Faction job check never happens. No Faction job ever appears in the World Phase job-offer list, so the whole faction-employment loop (and the Loyalty it feeds... | OPEN |
| factions-world-compendium | Affiliated Patron jobs — Compendium p.112 | small | No Patron job is ever flagged as faction-affiliated. `is_affiliated` is permanently false at RivalPatronResolver.gd:93, so the harder "a roll of a 6 earns +1 Loyalty" branch (FactionSyste... | OPEN |
| factions-world-compendium | Gaining Loyalty — Compendium p.112 | small | Winning a faction mission grants 0 Loyalty. Loyalty with every faction is permanently 0, which in turn makes Faction Favors (D6 <= Loyalty), the "Befriending the leadership" story point, ... | OPEN |
| factions-world-compendium | The Benefits of Loyalty (Faction Favors) — Compendium p.112 | large | The captain can never call in a faction favor. All six book favors — cancelling a Loan enforcement roll, Credits equal to the die roll, a free Patron/Salvage job, a free trial crew member... | OPEN |
| factions-world-compendium | Starting Loyalty on the home world — Compendium p.112 | small | A crew that starts the campaign on the faction world begins at Loyalty 0 with everyone instead of Loyalty 1 with a chosen faction — losing the one guaranteed early Faction Favor attempt t... | OPEN |
| factions-world-compendium | Faction Activity table effects — Compendium p.113 (Office party / Plans within plans / Day to day operations) | medium | Three of the eleven activity rows (rolls 76-00, 25% of the D100 table) produce literally nothing: an Office party pays 0 credits regardless of Loyalty, Plans within plans offers no Quest,... | OPEN |
| factions-world-compendium | Faction Destruction — Compendium p.115 | medium | Factions are immortal. A faction ground down by repeated Struggles and Undermines sits at Power 1 / Influence 1 forever and keeps acting, so the whole rise-and-fall arc of the faction sub... | OPEN |
| factions-world-compendium | Invasion!? — Check for Factions fleeing — Compendium p.114 (turn sequence Step 1.2) | medium | When a world is invaded, nothing happens to its factions: none flee with -1/-1, none are destroyed, and none of the Power 5+ defenders contribute their +1 to Galactic War Progress — so th... | OPEN |
| factions-world-compendium | Fringe World Strife effects on Factions — Compendium p.114 | one-line | Even in a campaign where a Crackdown or Economic Collapse were rolled, factions keep acting normally and lose no Influence, and a Civil War does not send them to ground. The three cross-r... | OPEN |
| factions-world-compendium | Fringe World Strife — arrival check — Compendium p.148 | medium | Fringe World Strife never activates in any campaign, even with the DLC owned and the option ticked in the setup wizard. No world is ever Unstable; the Instability track and all ten Chaos ... | OPEN |
| factions-world-compendium | Check for Instability step placement — Compendium p.10 Updated Campaign Turn Sequence | small | Even after the two preceding findings are fixed, Instability would be checked at the wrong point in the turn — before the battle rather than after it — so 'completed a Patron job this cam... | OPEN |
| factions-world-compendium | The 12 Difficulty Toggles — Compendium pp.32-34 | large | Ticking any of the 12 toggles in Settings changes nothing in play, and they do not appear in the campaign-creation wizard at all. Money is Tight does not change upkeep or the D6 credit ro... | OPEN |
| factions-world-compendium | Progressive Difficulty Options 1 and 2 — Compendium pp.30-31 | large | With Progressive Difficulty Option 1 enabled and the campaign at Turn 20, the player still faces the base rolled enemy count with zero respawns instead of +2 basic +1 specialist +1 Lieute... | PARTIAL 0eead4056 (Option 1 Strength + instructions live; Option 2 toggle unlocks pending) |
| economy-trade-equipment | Trade Table entries that send you to another table (Core Rules p.79-80) | small | 24 of 100 Trade Table results (rolls 1-3, 7-9, 45-48, 79-81, 82-86, 87-91) show a description dialog and award nothing at all. Every crew member sent to Trade has a ~1-in-4 chance of comi... | FIXED e2e56b985 |
| economy-trade-equipment | On-board Items (Core Rules pp.57-58) — 19 items with campaign-turn effects | large | Every on-board item in the Stash is inert. A Purifier never produces its 1 credit per campaign turn; Lucky Dice / Loaded Dice never gamble; Repair Bot and Spare Parts add no +1 to the Rep... | OPEN |
| economy-trade-equipment | Gun Mods and Gun Sights (Core Rules p.53) | large | Looting or buying a Unity Battle Sight, Cyber-configurable Nano-Sludge, Upgrade Kit, Shock Attachment, Stabilizer, Hot Shot Pack, Assault Blade, Bipod, Beam Light, Laser Sight, Quality Si... | OPEN |
| economy-trade-equipment | Damaged loot requires Repair before use (Core Rules p.131 + Repair Your Kit p.78) | medium | Loot rolls 26-45 (20% of every loot result) hand the player two supposedly-broken items that carry no [DAMAGED] tag in the Assign Equipment screen and can be issued and used immediately a... | OPEN |
| economy-trade-equipment | Merchant school — reroll one Trade roll per campaign turn (Core Rules p.125) | medium | Paying 10 XP/credits for Merchant school buys nothing: the crew member gets no reroll on the Trade Table when they Trade. The one button that does exist (in the Trading phase) rerolls a m... | OPEN |
| economy-trade-equipment | Rewards Subtable — Ship Parts / Military Ship Part discount (Core Rules p.134) | medium | Rolling 71-90 on the Rewards Subtable (20% of Rewards results, i.e. 4% of all Loot Table rolls) produces a line of text and no benefit — the promised 1D6 or 1D6+2 credit discount is never... | OPEN |
| economy-trade-equipment | Loot Table resolution — single source of truth | small | None directly — dead code. It matters only as a maintenance hazard: a future fix applied here (or to the JSON it reads) would appear to work while the live path (LootTableResolver) stayed... | OPEN |
| battle-setup | Number of Opponents — campaign difficulty modifiers (Easy -1 at 5+, Challenging reroll 1-2, Hardcore/Insanity +1) | small | A Hardcore campaign fights the same number of enemies as a Normal one — the +1 enemy the player chose Hardcore for never appears. A Challenging campaign never rerolls the 1s and 2s, so it... | FIXED 24c657af4 |
| battle-setup | Number of Opponents — crew in the field below standard size | medium | A crew that goes into battle two or more figures short — after casualties, Sick Bay, a Small Encounter sit-out, or the player deliberately leaving people on the ship — still faces the ful... | FIXED 24c657af4 |
| battle-setup | Determine the Objective — the final battle of a Quest is always Fight Off and adds +1 enemy | small | The climactic final battle of a Quest is generated as an ordinary fight: the objective is rolled at random off the D10 Quest table instead of being forced to Fight Off, and the enemy forc... | FIXED 2c44839f0 |
| battle-setup | Seizing the Initiative — opponent-type modifiers | medium | Fighting Punks, Brat Gang, Roid-gangers, Security Bots, Abandoned, Converted Acquisition or Haywire Robots, the player silently loses the +1 they are owed and needs 10+ instead of 9+ on 2... | FIXED 2d052d2de (Careless/Alert as modifiers; Prediction/Unpredictable as absolutes on the enemy record) |
| battle-setup | Choose Your Battle — Continue a Quest is a selectable job option | large | A player who resolves Rumors into a Quest (ResolveRumorsComponent.gd:168-190 does store one) has no way to fight it. There is no 'Continue a Quest' battle option, and every quest-flavoure... | FIXED 2c44839f0 |
| battle-setup | Unique Individuals — a Guardian-AI Unique must be attached to a figure in the enemy force | small | Roughly a third of the Unique Individual table has Guardian AI (Enemy Bruiser 1-6, Mutant Bruiser 57-61, Gene Dog 86-91, Sand Runner 92-96, Mk II Security Bot 97-100 — 27 of 100 results).... | OPEN |
| battle-setup | Defend objective — force the enemy AI to Aggressive and add +1 enemy | small | On a Quest Defend objective (D10 5-6, so 20% of Quest missions) the player fights one fewer enemy than the rules require, and a Cautious/Defensive/Tactical force keeps its cautious AI — s... | FIXED 3aa8d0b88 |
| battle-setup | Battle Events (optional) — Environmental hazard | small | Low severity for a companion app — the event's text does reach the player, who resolves the rolls on the table. The concrete loss is that the app offers a dice-rolling assist for every ot... | OPEN |
| battle-setup | Determine Deployment Conditions — present the rolled condition in the battle UI | small | The dedicated Deployment Conditions panel in the tactical battle screen renders blank/placeholder for every battle, and its Acknowledge/Details buttons act on nothing. The player who goes... | FIXED bf3f797c3 — the panel had roll_condition() and display_condition() and NOTHING called either. The condition was never missing; CampaignTurnController stamps it and it simply never reached the one screen built to show it. Rehydrated by id, not re-rolled. |
| patrons-rivals-quests | Quest finale: "Next time you pursue a Quest mission, it will be the finale… add +1 to the number of opponents… roll the die twice, pick the better score, and add +1… Crew completed the final stage of a Quest +1 XP" (Core Rules pp.120, 123) | medium | A Quest can never end. Reaching 7+ on the p.120 progress roll writes a flag the app never reads again: the finale battle never gets its extra enemy, never pays the double-roll +1 (so a fi... | FIXED 2c44839f0 |
| patrons-rivals-quests | Quest missions exist as a battle type — "Continue a Quest / If you have an active Quest" (Core Rules p.85 Select Your Job) | medium | After the Resolve Rumors step hands the player a Quest, nothing in the app ever lets them go on it. The Quest objective table (p.89: Move Through/Search/Defend/Acquire/Fight Off), the Que... | FIXED 2c44839f0 |
| patrons-rivals-quests | Benefits, Hazards and Conditions subtables — all 30 entries (Core Rules pp.83-84) | large | Every Patron job plays identically. A 'Dangerous Job' hazard fields the same number of enemies as a 'Security Team' benefit; a 'Small Squad' job still lets you deploy 6; a 'Vengeful' patr... | PARTIAL fab705684+cfbd4f91f (19 of 21 rows applied; Private Transport needs RivalEncounterCheck — another session's file — and Busy has an accessor with no caller) |
| patrons-rivals-quests | Danger Pay 10+: "+3 credits and roll twice, picking the higher die when rolling for mission pay after the battle" (Core Rules p.83) | small | A Corporation job that rolls 10+ on Danger Pay advertises "roll twice for mission pay" in the job details, then pays a single 1D6. Average mission pay on those jobs is ~3.5 instead of ~4.... | FIXED fab705684 |
| patrons-rivals-quests | "When you travel to a new planet, all Patrons become unavailable, unless they are Persistent" (Core Rules p.119 Step 2) | small | Patrons accumulate forever and follow you across the galaxy. Each one adds +1 to the p.77 Find a Patron roll (CrewTaskComponent.gd:506-508) and generates 1-3 more job offers every single ... | FIXED 592a67212 (the travel purge existed; nothing ever SET is_persistent, so the Benefit could spare nobody) |
| patrons-rivals-quests | Time Frame Table — "the number of campaign turns within which you must finish the job. If the job isn't done when the time runs out, it counts as a failure" (Core Rules p.83); "a Patron job will fail if the time to complete it has expired" (p.85) | large | 'This campaign turn' means nothing — the player can decline every job and the same Patron re-offers fresh work next turn with no penalty. The Secretive Group's +1 Time Frame bonus (its on... | FIXED fab705684 (offers persist on the campaign and lapse; Vengeful fires on a lapse) |
| patrons-rivals-quests | Spending credits for +1 on crew tasks — Find a Patron (p.77), Track (p.78), Repair Your Kit (p.78), extra Trade rolls (p.78) | medium | Credits cannot buy anything in the World step. A player sitting on 20 credits cannot pay to find a Patron, cannot pay to track down the Rival hunting them, and cannot buy spare parts to s... | PARTIAL 8210675ca (+1-per-credit done; 3-credit extra Trade roll open) |
| patrons-rivals-quests | Interested Parties: "During Quest missions, when rolling for the number of opponents, reroll any die scoring 1 once" (Core Rules p.99) | small | Quest battles against Interested Parties are easier than the book intends — a die showing 1 stands, so the enemy force can be as small as 1-2 figures where the book guarantees a reroll. M... | FIXED 24c657af4 |
| patrons-rivals-quests | Vigilantes — "Persistent: If encountered as Rivals, all rolls to remove them from Rival status are at -1" (Core Rules p.99) | small | Vigilante Rivals are exactly as easy to shake off as any other (50% on a 4+ instead of the intended 33% on an effective 5+). The one enemy in the book designed to be a long-term nuisance ... | FIXED 5eeee2c39 |
| patrons-rivals-quests | Renegade Soldiers — "Grudge: If encountered as Rivals, they bring one additional figure" (Core Rules p.99) | small | A Renegade Soldier Rival brings the same force as any other Rival — one fewer enemy than the book specifies on every Rival battle against them, for the whole campaign. | FIXED 5eeee2c39 |
| patrons-rivals-quests | Bounty Hunters — "Intrigue: Roll 2D6 and add +1 if you killed a Lieutenant and/or Unique Individual. On a 9+, you obtain a Quest Rumor" (Core Rules p.99) | small | Beating Bounty Hunters — including killing their Lieutenant — never yields the Quest Rumor the book promises. Since Quest Rumors are the only way to start a Quest (p.85), one of the game'... | FIXED 5eeee2c39 |
| patrons-rivals-quests | Affiliated patron jobs — `battle_result["is_affiliated_patron_job"]` (Compendium p.114 faction loyalty on a patron job) | small | Faction loyalty from patron jobs always uses the non-affiliated (lower) branch, so factions never build loyalty faster from jobs that should count double. Low impact for a standard non-DL... | OPEN |
| missions-elites-zones | Black Jobs — the mission itself (access, D10 'Your Day in Hell' objective, Roving Threats opposition, all rewards) | medium | Player meets the 10-Red-Zone-turn requirement, clicks "Accept Black Zone Mission", pays the travel cost — and then fights an ordinary randomly-generated battle. No Roving Threats opponent... | OPEN |
| missions-elites-zones | Mission Selection — Stealth / Street Fight / Salvage battle types (and therefore the whole Stealth, Street Fight and Salvage chapters) | medium | Buying the Fixer's Guidebook DLC and enabling Stealth Missions / Street Fights / Salvage Jobs changes nothing. Every battle in every campaign is a Conventional battle. The player never se... | FIXED 6c8e7b513 — every layer already existed and agreed on the key; the only caller of all three generators was the zero-instantiation phases/WorldPhase.gd. Also needed `type` added to the WorldPhaseController hand-off, which drops ~20 keys and never carried it. Unblocks L69/L70/L71/L141. |
| missions-elites-zones | Elite-Level Enemies — Elite Composition, Specialist/Lieutenant/Captain upgrades, Unique Individual 7+, Leadership Panic table, Better Loot, Patron Pay, Quest Rewards, Brutal Fight, Elite-level Rivals | large | The 'Elite Enemies' DLC toggle is a placebo switch. Enemy forces are always built from the Core Rules p.93 thresholds (1-2 none / 3-6 one Specialist / 7+ two). No Captain ever appears, Sp... | OPEN |
| missions-elites-zones | Red Job — Threat Condition (D6 rolled before every Red Zone mission) | small | Every Red Zone battle is fought with no Threat Condition. The player is told one exists but is never given the roll or the result, so a Red Job never gets Pitch Black 6" visibility, never... | OPEN |
| missions-elites-zones | Red Job — Time Constraint (D6 at end of Round 6) | medium | A Red Zone battle runs to its natural end with no round-6 event. The player never gets the reinforcement waves, never gets the escalating Count-down clock, and never gets the 'Evac now!' ... | OPEN |
| missions-elites-zones | Red Job Improved Rewards — additional Loot Table roll on a Win | one-line | Winning a Red Zone battle gives exactly 1 Loot roll, the same as any ordinary win. The advertised Red Zone reward the UI promises at MissionPrepComponent.gd:372-374 ("extra Loot roll on W... | OPEN |
| missions-elites-zones | Black Job victory reward — 3 rolls on the Loot Table | one-line | Even if the Black Zone mission gap (finding 1) is fixed, a Black Zone victory yields 1 Loot roll instead of 3 — the player loses two of the three promised Loot Table items, while the jour... | OPEN |
| missions-elites-zones | Black Job advantage — three free rolls on the Weapon Table | small | Accepting a Black Job grants zero free weapons. The player goes into the game's hardest fight with exactly the gear they already owned, losing three free Weapon Table items the book hands... | OPEN |
| missions-elites-zones | Black Job advantage — immunity from Rival interference | small | On a Black Zone campaign turn a Rival can still roll to track the crew down and hijack the turn with a Rival battle, which the book explicitly forbids — the player loses their Black Job (... | OPEN |
| missions-elites-zones | Salvage Jobs — Finding a Salvage Job (crew action + 1D6 availability table) | medium | There is no way to look for a Salvage job. The D6 availability table, the 2-credit Fee outcome and the Illegal-job outcome never occur, so a Salvage mission can never enter a campaign thr... | OPEN |
| missions-elites-zones | Salvage Jobs — Illegal Jobs post-game consequence | medium | Illegal salvage jobs never occur, and even if one did the panel would treat it as legal. The player is never fined, never has to forfeit Salvage, and never gains an Enforcer Rival — the e... | OPEN |
| missions-elites-zones | Salvage — the Scrapper trade (post-battle Step 4) and salvage-as-currency | large | Salvage units collected in a mission evaporate at the end of the battle — they are never tallied at Get Paid, never buy anything from a Scrapper, and never offset ship-repair/module/bot-u... | OPEN |
| missions-elites-zones | Compendium DLC battle-setup instructions (AI Variations, Difficulty Toggles, Escalating Battles, Dramatic Combat, Grid-based Movement) reaching the battle screen | medium | With the Freelancer's Handbook enabled, the battle screen's COMPENDIUM DIFFICULTY RULES, ESCALATING BATTLES, DRAMATIC COMBAT and GRID-BASED MOVEMENT setup sections never render, and the p... | FIXED 0eead4056 |
| missions-elites-zones | Bestiary / Elite enemy reference data is loaded but never consulted | one-line | No direct gameplay effect today (Bestiary.json duplicates the Core Rules encounter tables that enemy_types.json already supplies), but ~25KB of JSON is parsed on every EnemyGenerator cons... | OPEN |
| post-battle | Step 10 — Advanced Training: application fee, 2D6 4+ approval, course cost, and course record (p.124) | medium | In the post-battle wizard the player picks Pilot Training, presses Roll, sees "2D6 Roll: 9 - Training APPROVED!" and the log line "Kaya completed pilot training" — and nothing happens. No... | FIXED c942fec91 |
| post-battle | Step 13 — Character Event: Precursor "roll twice and pick either score" (p.126) | small | Any crew with a Precursor: whenever the randomly-selected character for step 13 is that Precursor, the Character Event is silently dropped — no XP, no story point, no rumor, no status eff... | OPEN |
| post-battle | Step 8 — Injury Table roll 16, Miraculous escape (p.122) | small | Rolling exactly 16 on the Injury Table — the single best non-XP outcome in the game — does literally nothing: the character gains no Luck point and keeps every item they were carrying. Th... | FIXED ca68e01b6 |
| post-battle | Step 8 — Injury Table roll 96-100, School of hard knocks: "Earn 1 XP" (p.122) | one-line | A crew member who rolls 96-100 after being downed gets nothing. The book's consolation prize for a bad battle is silently withheld every time. | FIXED ca68e01b6 |
| post-battle | Step 8 — Injury Table equipment consequences (rolls 1-5 and 17-30; Bot 1-5 and 16-30) (p.122) | medium | Equipment never degrades from injuries. A Gruesome Fate kills the character but leaves their gear pristine in the stash; a 17-30 Equipment Loss result damages nothing, so the Repair crew ... | FIXED bffe2c8d1 — the equipment flags were computed and stored on every injury and read by NOTHING. 20 of 100 on each table. Gruesome fate (damaged, repairable) and Miraculous escape (permanently lost) shared one flag and are different outcomes; split. Damage writes the {type: item_damaged, damaged_item} marker Repair Your Kit reads, so p.78 finally has something to repair. |
| post-battle | Step 5 — Battlefield Finds table entries 1-15, 16-25, 36-45, 46-60, 61-75 (p.121) | large | On the backend path five of the eight table entries (60% of the D100 range) award nothing — no weapon from the slain enemy, no consumable dosage, no starship part credit, no 1D3 debris cr... | FIXED (this commit) |
| post-battle | Step 9 — XP: "First character to inflict a casualty +1" and "Killed Unique Individual +1" (p.123) | medium | Playing the battle out in the app costs you XP relative to the book: the crew member who drew first blood and the one who killed the enemy Unique Individual each receive 2 or 3 XP instead... | FIXED (row was stale) — BattleResultsInputForm asks for both, as crew_id and as a LIST of crew_ids, matching the consumer shapes exactly; TacticalBattleUI builds that form as "the reachable record-what-happened path for a PLAYED battle at ANY tier". RESIDUAL, narrow: the AUTO-RESOLVE path cannot produce either (nothing derives first blood from a simulated fight), so an auto-resolved battle still under-pays by up to 2 XP. Tracked in the closeout plan, not as a live rules gap. |
| post-battle | Step 2 — Patron Status: One-time Contract exception, and Patrons lapse on travel unless Persistent (p.119) | medium | Patrons accumulate forever. Every completed job — including one-shot contracts that should evaporate — adds a permanent contact, and flying to a new world does not shed the old world's Pa... | FIXED fab705684+592a67212 |
| post-battle | Step 12 — Campaign Event 1-3 (Friendly Doc) and 45-48 (Equipment Malfunction) (pp.126-127) | small | The Friendly Doc event never shortens anyone's Sick Bay stay; the crew member is released on exactly the same turn as before. The Equipment Malfunction event never damages anything in the... | FIXED d945a3ecb + b14974c37 — Equipment Malfunction targets the STASH per p.127 (`damaged: true`, a flag Assign Equipment and Purchase Items already read with no producer) and Repair Your Kit now searches the stash as well as carried gear, since p.78 draws no line. Friendly Doc wrote `injury_recovery_turns`, which the countdown ignores — it decrements injuries[] and clears the bay when that is empty — so the stay never shortened. |
| post-battle | Step 13 — Character Events 11-12 (Time to Move On), 20-23 (Scrap with Crewmate), 63-66 (Hurt on Ship), 72-75 (Gift) (pp.128-130) | medium | Four Character Events (roughly 15 points of the D100 range) are pure flavour text. Nobody leaves the crew, nobody brawls, nobody goes to Sick Bay from ship maintenance, and the gift never... | FIXED — 11-12 Time to Move On (the 1D6-vs-recovery roll never happened, so nobody ever left Sick Bay), 20-23 Scrap (the Feeler and K'Erin clauses were wired and the FIGHT was not), 63-66 Hurt on Ship (already fixed), 72-75 Gift (the Loot roll never happened). Exposed that ctx.injure_specific_crew wrote nothing at all — a permanently-false has_method guard plus an `is_wounded` set that aborts on a Dictionary. |
| post-battle | Step 10 course benefits — Medical school and Bot technician injury rerolls (p.125) | large | Paying 20 XP for Medical school buys nothing — casualties still roll once on the Injury Table. Paying 10 XP for Bot technician buys nothing — Bots still roll once, and Bot upgrades cost f... | OPEN |
| post-battle | Step 13 — "If an event is completely inapplicable, simply add +1 XP to the character" (p.126) | one-line | When a Character Event cannot apply — a K'Erin drawing "All this endless violence is depressing you", an Engineer drawing "They don't make them like they used to", or any event whose titl... | FIXED (this commit) |
| turn-upkeep-travel | Ship Debt — payments, interest, and seizure (World Step 1) | medium | A crew that financed its ship at campaign creation (real saves carry ship.debt 12-36) pays 0 interest forever. The debt figure on the Ship screen never moves, never crosses 75, and the sh... | FIXED fc0f2d2c9 |
| turn-upkeep-travel | Pay for Medical Care — 4 credits removes 1 campaign turn of recovery | medium | An injured crew member always sits out the full injury-table recovery. A player with 40 credits and a character facing 4 turns in Sick Bay has no way to buy them back into the crew; the m... | FIXED fc0f2d2c9 |
| turn-upkeep-travel | New World Arrival Steps 1-3 — Check for Rivals, Dismiss Patrons, Check for Licensing Requirements | large | Every Rival you have ever made follows you to every new world forever — the Rival list only grows, which inflates the p.85 'roll a D6 vs number of Rivals' check into a near-certain forced... | PARTIAL fc0f2d2c9 (steps 1-2 done; step 3 Freelancer License open) |
| turn-upkeep-travel | Starship Travel Events Table — all 16 D100 results | large | Traveling is mechanically free of risk and free of reward. Asteroids never damage the hull, Navigation Trouble never costs a story point, Raided never starts the pirate battle (or takes y... | FIXED (all 16 events) |
| turn-upkeep-travel | Upkeep shortfall — one crew member refuses jobs per credit short | small | Failing to pay Upkeep costs nothing. The player is shown a dialog naming the crew who 'refuse to work this turn', then those exact characters appear enabled in the Crew Tasks list and can... | FIXED 95c35bdd0 |
| turn-upkeep-travel | Recruit crew task — a new character actually joins | one-line | Sending one or two crew to Recruit prints 'Automatic recruit (crew below 6)' or 'Roll 4 -> 6 vs 6' in the results panel and the crew roster is unchanged. A crew reduced to 3 members by ca... | FIXED 95c35bdd0 |
| turn-upkeep-travel | Spending credits for +1 on crew tasks (Find a Patron, Track, Repair) and the 3-credit extra Trade roll | medium | There is no way to spend a single credit to improve a Patron search, a Rival hunt, or a Repair, and no way to buy the extra 3-credit Trade Table roll. The book's main credit sink during t... | PARTIAL 8210675ca (+1-per-credit done; the 3-credit extra Trade roll still open) |
| turn-upkeep-travel | Patron job Time Frame — job fails if not completed in time | medium | A Patron job stamped 'This campaign turn' can be shelved for twenty turns and then completed for full pay. Patron jobs never expire, never count as failures, and never trigger the p.84 'V... | FIXED fab705684 + cfbd4f91f (row was stale) — Time Frame was wired with the rest of the p.83 job data: offers persist on the campaign with a real deadline_turn, JobOfferComponent expires them at turn start, and Vengeful (p.84) fires on the lapse. Duplicate of the BHC row at L50. |
| turn-upkeep-travel | Ship wreck — accumulated Hull damage destroys the ship | small | A ship reduced to 0 Hull Points is not a wreck — it is merely grounded, and the free 1-point-per-turn repair at rollover (CampaignPhaseManager.gd:673) floats it again next turn. The crew ... | FIXED 95c35bdd0 |
| turn-upkeep-travel | Emergency Take-off (p.60) — 3D6 hull damage for insisting on travel while damaged | small | The live Travel button is simply DISABLED while the hull is damaged, so the player never gets the book's choice; get_emergency_takeoff_damage() is called only from the dead TravelPhase.gd. Also the only in-space producer for the p.59 wreck branch. | FIXED |
| turn-upkeep-travel | progress_data["crew_retired"] — campaign archival on crew retirement | one-line | A campaign that ends because the crew retired (rather than by victory or by reaching 20 turns) is never archived to LegacySystem — the crew, story points and turn count are silently dropp... | OPEN |
| turn-upkeep-travel | 6 | World Traits now PARTIAL — 12 traits need a call site |
| battle-setup | 8 | deployment conditions, seize initiative |
| post-battle | 11 | Crippling Wound, injury equipment loss |
| patrons-rivals-quests | 12 | Time Frame never expires; the 30 p.83 BHC subtable entries |
| economy-trade-equipment | 13 | gun mods, on-board items, Merchant reroll |
| factions-world-compendium | 20 | DLC-gated; a tester without the DLC never sees any of it |
| missions-elites-zones | 20 | Black Jobs, Red Zone conditions, Elite enemies |

## WRONG-VALUE (21)

| Domain | Rule | Fix size | Player-visible effect | Status |
|---|---|---|---|---|
| factions-world-compendium | Faction generation quantity/types — Compendium p.110 | small | If faction init is ever wired as-is, the player gets 8-16 factions named "United Federation", "Skull Raiders", "Quantum Hive" etc. instead of the book's 2-4 Merchant cartels / Criminal en... | OPEN |
| factions-world-compendium | Instability tracking — Compendium p.148 | medium | Were the arrival gate fixed, a Chaos event would fire on roughly half of ALL World Phases forever (a fresh 4+ D6 each turn) instead of once every two-to-three turns of built-up Instabilit... | OPEN |
| factions-world-compendium | Compendium page citations shown to the player | one-line | A player who ticks 'Expanded Factions' in the campaign wizard and turns to Compendium pp.148-153 to read the rules lands in the Fringe World Strife and Loans chapters and finds nothing ab... | OPEN |
| economy-trade-equipment | Post-Battle Step 7 "Gather the Loot" — one roll per battle | medium | Every battle yields TWO independent Loot Table results instead of one — one silently added by the backend, one the player rolls in the wizard. A Quest finale yields six items instead of t... | OPEN |
| economy-trade-equipment | Loot Table three-roll procedure — category, subtable, then the exact item by D100 (Core Rules pp.131-133) | medium | Loot item frequencies are wrong across the board. Grenade loot is 50/50 Frakk/Dazzle instead of the printed 60/40. Within melee loot a Blade drops to 12.5% from 20% while a Suppression Ma... | OPEN |
| economy-trade-equipment | The p.28-29 tables referenced by the Trade Table (Low-Tech Weapon Table, Gear Table, Gadget Table) | medium | Trade Table 1-3 "A personal weapon", which should be a Handgun/Scrap Pistol/Colony Rifle/Shotgun/Blade etc., instead returns a Power Claw, Suppression Maul, Glare Sword, Ripper Sword or B... | FIXED e2e56b985 |
| battle-setup | Number of Opponents — Insanity adds +1 to the final number faced | one-line | On Insanity — the hardest mode in the book — every battle fields one fewer enemy than the rules require. Combined with the danger_level defect above the +1 could not fire regardless, so f... | FIXED 24c657af4 |
| battle-setup | Determine Deployment Conditions — consult the column matching the mission type; the table is ignored during an Invasion battle | small | Two concrete wrong outcomes. (1) Every Rival battle rolls deployment conditions on the Opportunity/Patron column instead of the Rival column, so the odds are badly skewed — 'No Condition'... | FIXED 565ddc4b5 (read mission_source not source; Invasion skip added) |
| battle-setup | Determine the Enemy — roll the Enemy Encounter Category on the column matching the mission (Opportunity / Patron / Quest / Unknown Rival) | medium | A Rival that tracks you down is generated off the Opportunity or Patron column, so 20-25% of Rival battles are against Roving Threats — a category the book excludes from Rival fights outr... | FIXED 565ddc4b5 (the silent tables.get("patron") fallback sent a quarter of Rival battles against wildlife) |
| patrons-rivals-quests | Danger Pay is a PATRON-job payment only — "If you did a Patron job, add the Pay bonus to the Danger Pay" (Core Rules p.120 Step 4) | one-line | Opportunity missions — the default 'nothing else presented itself' battle — pay an extra 1 to 3 credits of Danger Pay they are not entitled to. On a single-digit credit economy where Upke... | FIXED 878057d6a (gated at the offer builder AND the payment step) |
| missions-elites-zones | Red Job Improved Rewards — Quest credit payout | small | Finishing a Quest in a Red Zone pays slightly more than the book allows — best-of-4 averages ~5.24 vs the book's best-of-3 ~4.96, i.e. roughly +0.3 credits per Red Zone quest conclusion, ... | OPEN |
| post-battle | Step 13 — Character Event: exactly ONE roll, for ONE randomly selected character (p.126) | medium | A six-person crew resolves SEVEN character events per campaign turn instead of one — six applied by the player plus one applied silently by the backend. XP, story points, quest rumors, Ri... | FIXED ca68e01b6 |
| post-battle | Step 5 — Battlefield Finds: "Roll D100 ONCE on the table below, and add the resulting find to your inventory" (p.121) | small | Two Battlefield Finds are resolved per battle. The player sees the backend's find in the log (which may hand out a Quest Rumor or +1 credit) and then rolls a second, different find that i... | FIXED ca68e01b6 |
| post-battle | Step 5 — Battlefield Finds 76-90, Vital info: automatic Corporate Patron (p.121) | small | A 76-90 Battlefield Find against a normal enemy hands the crew a Quest Rumor instead of a free Corporate Patron. The player loses a standing job source on that world and instead gets prog... | FIXED (this commit) |
| post-battle | Step 13 — Character Event eligibility: "Any character is eligible, as long as they are part of your crew, even if they are in Sick Bay" (p.126) | one-line | A crew member in Sick Bay can never draw a Character Event, which is precisely backwards for the several table entries written for them — "You are starting to wonder if it is time to move... | FIXED (this commit) |
| post-battle | Step 9 — "Any character that flees the battlefield in the first 2 rounds of the battle receives no XP" (p.123) | small | It is all-or-nothing. If the flag is set, the whole crew — including the four members who fought to the end — earns zero XP for the battle. If it is not set, a character who Bailed on rou... | CORRECTED — finding was half right: fled_early means a WHOLE-CREW withdrawal, so zeroing all is correct there. Real gap is per-character bail tracking, which no producer emits. Read side wired for fled_early_crew. |
| post-battle | Step 8 — the injury the player is shown is not the injury that is applied (p.121) | medium | The player rolls their casualty's injury, sees "Rolled 88 - KNOCKED_OUT", clicks past it — and the character is actually dead, or in Sick Bay for 6 turns, because the backend rolled somet... | FIXED ca68e01b6 |
| turn-upkeep-travel | Commercial passage does not roll Starship Travel Events | one-line | A shipless crew buying passage on a liner is shown 'Asteroids — your ship takes Hull damage' and 'Drive trouble — your ship is grounded' events about a ship they do not own. (The mechanic... | FIXED 95c35bdd0 |
| battle-resolution | Weapon Ratings table (p.50) — Range / Shots / Damage / Traits | medium | The in-battle Weapon Table reference card gives wrong stats for most weapons. A player firing a Plasma Rifle is told 18" 1 shot Damage 2 when the book says 20" 2 shots Damage 1 — half the... | FIXED 91398d133 — the CARD was wrong in 6 of 10 rows (Plasma Rifle had wrong shots, damage AND traits) and WeaponTableSystem kept an 89-line fabricated FALLBACK table (~30 wrong profiles, invented traits Burn/Overheat/Stabilize/Silent, invented weapons) that fed WeaponTableDisplay and EnemyGenerationWizard on any JSON load failure. Its Suppression Maul matched the COMPENDIUM Game Options table, not the Core Rules. data/equipment_database.json verified byte-correct for all 32 book weapons; fallback deleted, failure is now loud |
| battle-resolution | To Hit (p.44) — 1D6 + Combat Skill vs the target number | one-line | Every ranged shot rolled through the in-battle Quick Roll tool is easier by the shooter's full Combat Skill. Combat Skill +1, target in the open at 12" with a 24" rifle: the book needs a ... | FIXED 4b7102dd0 — and found a LIVE BUG: Combat Skill was applied TWICE (subtracted from the threshold AND added to the roll), so +2 skill shot at an effective +4 |
| battle-resolution | Brawling — the 2" bonus move is earned only by ELIMINATING the opponent (p.45) | one-line | Every won Brawl grants the crew member a free 2" repositioning move, even when the loser merely got Stunned and is still standing there. Over a battle this hands the player several inches... | FIXED 7edee08cd — resolve_brawl() reported no post-Brawl move at all, so the rule was unavailable. Now gated on the casualty count, never the winner field, and records that it cannot enter a new Brawl |

## FABRICATED (13)

| Domain | Rule | Fix size | Player-visible effect | Status |
|---|---|---|---|---|
| factions-world-compendium | exploration_value / exploration_progress — no such mechanic in the Compendium or Core Rules | small | Any UI bound to `exploration_progress` shows a world creeping toward '100% explored' after ten missions, a statistic that exists in neither rulebook and that no rule consumes — misleading... | OPEN |
| economy-trade-equipment | Selling items — 1 credit each, up to 3 per turn, no condition restriction (Core Rules p.125) | small | Today the restriction is inert (nothing writes the `damaged` key — see the damaged-loot finding), so it is invisible. The moment damage is wired correctly, a damaged Frag Vest or damaged ... | OPEN |
| economy-trade-equipment | Equipment prices and repair costs (Core Rules p.78 Repair, p.125 Purchase Items) | large | Opening Manual Select from the equipment panel shows a shop quoting 500–2500 credits per item, a 60%-of-value sell price, and a paid repair service with Quick/Quality tiers — none of whic... | OPEN |
| economy-trade-equipment | Trading/market economy (Core Rules p.125 Purchase Items; p.79 Trade Table) | small | No direct effect — the system never runs. The harm is that it is a large, convincing, wrong second source of truth for prices sitting next to the correct 1cr/3cr constants, and it is inst... | OPEN |
| patrons-rivals-quests | Find a Patron gates whether a job offer exists at all — "If the result is a 5 or higher, you've found a Patron to hire you for a job… If one job is offered, it will always be a random, existing Patron" (Core Rules p.77) | large | You never need to send anyone to Find a Patron: job offers appear every turn regardless, and once you have 4-5 Patrons (which never expire — see the travel finding) the list is 6-12 jobs ... | OPEN |
| missions-elites-zones | Expanded Missions — Special Conditions are Patron Jobs Only | one-line | An Opportunity mission can arrive carrying "No Psionics may be deployed", "No Armor may be deployed" or "No more than 3 crew may fire a weapon each round" — restrictions the book applies ... | OPEN |
| missions-elites-zones | Stealth Missions — Reinforcements after the alarm; Stealth-round enemy behaviour; spotting modifiers; sentry profile; completion rewards | medium | Currently invisible because the Stealth/Street panels never instantiate (finding 2). The moment those are wired, the companion will instruct the player with non-book numbers: too few rein... | OPEN |
| post-battle | Step 12 — Campaign Event: "Roll D100 on the Campaign Event Table. Apply the result immediately." (p.125) | small | The wizard's Campaign Event step shows "Rolled 73 - Minor positive event" — a result that is not in the rulebook and that does nothing. Meanwhile the actual Core Rules event (e.g. "Tax Ma... | FIXED 34520cb51 |
| post-battle | Step 9 — Character Upgrades: the Ability Increase Table is spent, not rolled (p.123) | medium | Step 9 of the wizard tells the player to "Roll for advancement" and prints results like "Rolled 5 - …" that change nothing. The actual, correct XP-spend UI is buried on the character shee... | FIXED 56714e6c2 — the D6 'advancement roll' awarding 'skill points' was a FABRICATION, not a broken feature: no such roll and no such currency exists. Deleted per policy and replaced with the real p.123 XP spend through CharacterAdvancementService. |
| post-battle | Step 1 — Resolve Rival Status: the two D6 checks (p.119) | small | The wizard's first step teaches the player a rule that does not exist and makes them roll it once per Rival, with no effect on anything. The real outcome (a new Rival on a 1, or a Rival r... | FIXED 34520cb51 |
| battle-resolution | In-battle rules reference (CheatSheetPanel) vs pp.44/46/40/51 — to-hit, Aim, damage resolution, armor saves, Stun, Suppression | medium | A player using the app's Reference tab at the table plays a different game. They roll 4+ flat instead of 3+/5+/6+; they add +1 for Aiming instead of rerolling 1s; they compare the weapon'... | FIXED bfa8afa67 — six sections rewritten; it taught a flat 4+ with no Combat Skill, Combat armor at 4+, a 'Powered 3+' that does not exist, and a morale system where no line matched the book |
| battle-resolution | To Hit modifiers (p.44) — the table has exactly three rows and no elevation or over-range modifier | small | A player who ticks "Elevated" on the shooting helper is handed a +1 that the rules never grant — a covered target at range drops from 6+ to 5+ purely for standing on a rooftop. Setting th... | OPEN — VERDICT CONFIRMED against the book. p.44 is EXACTLY three rows: within 6" and in the open 3+; within weapon range and in the open OR within 6" and in Cover 5+; within weapon range and in Cover 6+. Reprinted identically on the reference card and in Appendix XI. No elevation row, no generic over-range row. The ONLY legitimate to-hit modifiers are the *Heavy* trait (-1 if the firer moved), *Snap shot* (+1 within 6") and the **Bipod** gun mod (+1 at ranges over 8" when Aiming or firing from Cover, non-*Pistol* only) — an over-range bonus that is a MOD, not a table row. |
| battle-resolution | Suppression — no such mechanic exists in the Core Rules | small | The in-battle rules reference teaches the player a status effect that does not exist in Five Parsecs, complete with a movement restriction and a -1 firing penalty. A player following the ... | PARTIAL 951cf1969 + 859b28429 — VERDICT CONFIRMED, dead sites purged. Every "suppress*" hit in the Core Rules is the Suppression maul weapon, "Pain suppressor" or the "Emo-suppressed" background; the Compendium adds only "Suppressing fire" (Renegade Soldier +1 shot). Deleted: BaseBattleRules.SUPPRESSION_MODIFIER, FiveParsecsCombatData.SUPPRESSED_PENALTY, EnemyTacticalAI.SUPPRESSION_PATTERN. STILL OPEN (live sites): BattleCalculations.gd:137/160/207, BattleResolver.gd:190/212/688-689, CharacterQuickRollPanel.gd:583, BaseCharacterResource.is_suppressed()/can_suppress(), the CheatSheetPanel text, and the SUPPRESSED enum members in BOTH enum files (deprecate in place — deleting shifts ordinals and breaks save compat, per the DifficultyLevel precedent). NOTE: "Emo-suppressed" is a REAL background (Character.gd:665-671, p.15 no-Luck rule) — do not remove it. |

## PARTIAL (30)

| Domain | Rule | Fix size | Player-visible effect | Status |
|---|---|---|---|---|
| factions-world-compendium | Faction Activities timing and trigger — Compendium p.113 | small | Doing a job for a faction never triggers the guaranteed Faction Struggle that the book makes mandatory, so the power balance never shifts in response to the crew's own work. Faction activ... | OPEN |
| factions-world-compendium | Faction Events table — Compendium pp.114-115 (missing rows and dropped effects) | medium | 38 of 100 faction-event rolls are journal text with no mechanical effect: rolling 43-49 tells the player "Befriending the leadership — Add +1 Story Point" and awards no Story Point; 88-93... | OPEN |
| factions-world-compendium | Terrain Generation is an optional rule — Compendium p.9 setup sequence / p.94 | small | A player who does not own the Freelancer's Handbook, or who deliberately left Terrain Generation off, still gets the Compendium's random terrain layout imposed on every battle setup rathe... | OPEN |
| economy-trade-equipment | Consumables are drawn from the Stash and used as a Free Action (Core Rules p.54) | one-line | A Stim-pack, Booster Pills or Combat Serum bought during the Trading phase shows up in the in-battle "💊 Consumable" picker, but choosing it does nothing: use_stash_consumable returns {"us... | OPEN |
| economy-trade-equipment | 11. Purchase Items — pay 3 credits for a roll on the Military Weapon, Gear or Gadget Table (Core Rules p.125) | medium | During Trading, 3 credits can return a 1-credit Hand Gun, a Scrap Pistol or a Frag Vest, and the player never gets to pick which of the three tables to roll on. The printed weights are ig... | OPEN |
| battle-setup | Notable Sights — the item can be acquired by moving into contact with it, and its listed reward is gained | medium | The app tells the player a Person of Interest is 11" from the table centre and that reaching them is worth +1 story point, the player spends a crew member's whole round walking there — an... | FIXED bf3f797c3 + 7de930a2d — all eight reward types applied. Producer is a 'Reached the Notable Sight' check on the results form (asked, because the fight happens on the player's table); Loot-Cache rows raise extra_loot_rolls rather than rolling twice. |
| battle-setup | Deployment Conditions — Slippery ground | one-line | On a Slippery Ground battle (5% of Opportunity/Patron rolls, 10% of Rival) the player reads the condition once on the pre-battle screen and then gets no reminder anywhere in the round loo... | OPEN |
| patrons-rivals-quests | "If you just fought a battle that was part of a Quest, roll a D6" — quest progress is gated on the BATTLE being a Quest mission (Core Rules p.120 Step 3) | one-line | Once a Quest exists, EVERY battle advances it — an Opportunity mission, a Patron job, even a forced Rival showdown each roll for quest progress and hand out Quest Rumors on a 4-6. Combine... | FIXED 2c44839f0 |
| patrons-rivals-quests | "If you are not currently on a Quest, roll a D6… If the roll is equal or below the number of Rumors, remove all Rumors from your roster" (Core Rules p.85 Step 5) | small | Rumors are never spent. A crew with 4 Rumors keeps 4 Rumors forever and re-rolls the Quest trigger every single campaign turn (66% chance each turn), each success silently overwriting `pr... | FIXED 2c44839f0 |
| patrons-rivals-quests | "First, you must check that your Rivals give the opportunity to choose your battle!… This will prevent you from doing whatever you had wanted to do this campaign turn" (Core Rules p.85 Step 6) + "Once a Rival has been established, they will always be the same type" (p.92) | medium | When a Rival ambushes you, you fight the Patron job's enemy type on the Patron objective table with the Opportunity/Patron Notable-Sights column — and still collect that job's Danger Pay ... | OPEN |
| patrons-rivals-quests | "If you just fought against an existing Rival and Held the Field, roll a 1D6… On a 4 or better, they've had enough, and you can remove them from your Rivals list" (Core Rules p.119 Step 1) | small | Hold the Field against a Rival whose figures all Bail on Morale (a common outcome — p.118 morale can rout a force with zero kills) and the removal roll never happens: you cannot shake the... | OPEN |
| missions-elites-zones | Black Job victory reward — +1 XP for EVERY crew member, participants or not | small | A crew member in Sick Bay, on a crew task, or otherwise held back during a Black Zone victory gets 0 XP where the book gives them 1. With a 7+ member roster and typically 6 deployed, the ... | OPEN |
| missions-elites-zones | Expanded Missions — Objective overview (two-objective results) | medium | 40% of Expanded Missions rolls (61-100) tell the player "Two objectives, BOTH required" or "Two objectives, complete ONE" and then list a single objective with a single time constraint. T... | OPEN |
| missions-elites-zones | Black Job — 'Your Day in Hell' mission type is rolled once and recorded | small | The Black Zone briefing can show 'Destroy strong point' one moment and 'Penetrate the lines' the next if the panel refreshes, and the campaign journal never records which Black Job was at... | OPEN |
| missions-elites-zones | Expanded Missions — briefing headings for the rolled results | one-line | The job-details panel renders "OVERVIEW: ", "SPECIFIC OBJECTIVE: ", "TIME CONSTRAINT: ", "PATRON CONDITION: " and "EXTRACTION: " with nothing after the colon, immediately followed by an i... | FIXED 56714e6c2 — the rows in missions_expanded.json carry `id` and `instruction` and have NO `name` key, so every .get("name", "") was "". The instruction is the book's own self-labelled line; it is printed and the duplicate heading dropped. |
| post-battle | Step 8 — Injury Table roll 31-45, Crippling wound: surgery OR permanent stat loss (p.122) | medium | A Crippling Wound costs the player nothing but time — no 1D6-credit surgery bill and no -1 to Speed or Toughness. The worst survivable injury in the game is mechanically identical to a Se... | FIXED bffe2c8d1 — data/injury_results.json has carried surgery_cost_roll AND the stat_reduction block since it was written and neither had an ACCESSOR. The -1 to the higher of Speed/Toughness now applies and the 1D6 surgery is a pay-to-undo offer in the wizard: the backend resolves injuries before any UI exists to ask, so a choice that waits for a prompt is a choice that never happens. |
| post-battle | Step 12 — Campaign Events 79-81 (Renegotiate Debts), 98-100 (Great Story), 57-59 (New Captain), 82-84 (Rumors of War) (pp.127-128) | medium | Rolling 79-81 while carrying ship debt earns 2 credits instead of wiping 1D6+1 off the loan. Rolling 98-100 after a casualty gives a story point instead of the +1 Luck that character earn... | FIXED — 57-59 New Captain rolled the D6 and discarded it (no flag moved, no 3 XP, no departure), 79-81 Renegotiate Debts paid the debt-free bonus to crews in debt and never touched the loan, 82-84 Rumors of War had no producer for its +2 (now planet-scoped and cleared on travel), 98-100 Great Story never paid the +1 Luck the book puts first. |
| post-battle | Step 13 — Character Events 52-55 (Scars), 24-26 (Good Food), 42-45 (Heart to Heart), 67-68 (True Love) (pp.129) | small | Scars Tell the Story is +2 free XP for an uninjured character who should get nothing. Good Food is +1 free XP for a character in Sick Bay who should instead get a turn back. Heart to Hear... | FIXED — 52-55 Scars paid +2 XP unconditionally (the largest free XP source on the table), 24-26 Good Food paid XP to a character in Sick Bay who should have got a turn back instead and ignored the Engineer exclusion, 42-45 Heart to Heart paid one of the two characters the rule names, 67-68 True Love never paid the Motivation-specific 1D6 XP. |
| post-battle | Step 10 — Advanced Training payment: "The cost can be paid using unspent XP, credits or any combination thereof" (p.124) | medium | The book's own worked example is impossible in the app: a character with 8 XP and 12 credits cannot buy Pilot Training (cost 20). Training is XP-only, so it is unaffordable until very lat... | FIXED c942fec91 |
| turn-upkeep-travel | Repair Your Kit crew task — the item is actually repaired, and Engineer +1 | medium | The task always reports 'Item repaired' and the damaged item stays damaged forever, so a broken weapon is permanently broken. And an Engineer-species character — the one crew type the boo... | FIXED (this commit) |
| turn-upkeep-travel | World Traits Table — the 40 traits' mechanical effects | large | The world you land on is a paragraph of text. Fuel refinery does not make travel cost 3, Fuel shortage does not raise it, Lacks starship facilities does not cap repairs, Bureaucratic mess... | PARTIAL 4fe221f50 + a7449cea6 — WorldTraitEffects.gd is now the SSOT and data/world_traits.json carries a structured `effects` block for all 31 campaign-side traits (the 11 battlefield ones stay with FPCM_BattlefieldGenerator, pinned by a test in both directions). 19 traits have a LIVE consumer: fuel_refinery, fuel_shortage, bureaucratic_mess, travel_restricted, high_cost, technical_knowledge, easy_recruiting, opportunities, corporate_state (patron bonus only), restricted_education, expensive_education, heavily_enforced, rampant_crime, dangerous, vendetta_system, invasion_risk, imminent_invasion + military_outpost (invasion roll only), unity_safe_sector. STILL UNWIRED — the resolver exposes each of these, they need a call site: lacks_starship_facilities (repair credit cap), medical_science, bot_manufacturing, shipyards, adventurous_population, booming_economy, busy_markets, weapon_licensing, import_restrictions, free_trade_zone, interdiction, alien_species_restricted, war_progress_modifier (2 traits), corporate_state forced-type + blacklist |
| turn-upkeep-travel | Resolve Rumors — remove all Rumors from your roster when a Quest is received | small | Rumors are never spent. Once the player banks 5-6 Rumors the D6 succeeds essentially every campaign turn, and because the quest-active gate is also dead, the game hands out a brand-new Qu... | FIXED 2c44839f0 |
| turn-upkeep-travel | Fleeing an Invasion — you lose everyone you knew on that world, and the shipless/no-credits escape routes | medium | Escaping an invaded world is consequence-free: you keep every Rival and every Patron you built up there, so fleeing is strictly better than staying. And a crew stuck on an invaded world w... | OPEN |
| turn-upkeep-travel | Sick Bay exit — recovered characters cannot perform a task that campaign turn | small | A character whose last Sick Bay turn ticks off at rollover walks straight into the Crew Tasks screen and takes a full task the same turn — an extra Explore/Trade/Patron roll per recovery ... | FIXED 5927ecbe3 — p.76 makes leaving Sick Bay a TWO-step release and only the first existed. `recovered_this_turn` is stamped at the rollover release and read by CrewTaskComponent, cleared at the top of the next rollover so it lasts exactly one turn. |
| turn-upkeep-travel | Train task resolves a Character Upgrade immediately; Find a Patron offers an EXISTING Patron | medium | Training banks XP that sits unspent until the player happens to open the post-battle advancement screen, and the p.77 'resolve that immediately' beat never happens. And the Patron pool in... | OPEN |
| turn-upkeep-travel | Repeat Patron keeps the same Benefit; up to two characters on any one task | small | A loyal Patron you have worked for five times rolls a different Benefit (or none) every single job, so building a relationship with one employer has no payoff. And only one crew member ca... | FIXED 878057d6a (Benefit remembered per Patron; the two-per-task half was already right except a fabricated max_crew 1 on repair_kit) |
| battle-resolution | Saving Throws — Multiple Saving Throws (p.46) and innate Bot/Soulless armor plating | small | A Bot or Soulless crew member with no purchased armor gets NO saving throw in any auto-resolved battle, instead of the 6+ the book guarantees (5+ for Assault Bots) — they die roughly 17% ... | FIXED 4b7102dd0 — was min() ('best wins'), losing the -1 the book grants for stacking. Both printed examples now pass. Innate plating now covers all four species, not just Soulless |
| battle-resolution | Weapon Ratings — Shots (p.49): the number of attack dice you roll | small | On the standard (no-DLC) campaign, an Auto Rifle (2 shots), a Rattle Gun (3 shots) and a Hyper Blaster (3 shots) all fire exactly once per round in auto-resolve — identical to a 1-shot Co... | FIXED f6e85b238 — auto-resolve called resolve_ranged_attack() ONCE per attacker and never read Shots, so Rattle gun (3), Hyper blaster (3), Auto rifle/Shotgun/Plasma rifle/Needle rifle/Machine pistol/Shell gun/Hand flamer/Flak gun/Cling fire pistol (2 each) all fired a single shot. Now loops over Shots, same target (required by Focused, p.51), breaking early once the target is down |
| battle-resolution | Impact trait (p.51) — a second Stun marker on an already-Stunned target | small | The Suppression maul — the game's dedicated Impact weapon — is mechanically identical to any other Damage +1 melee weapon. Its ability to stack a Stunned enemy toward the 3-marker knockou... | FIXED b776e8726 — was unconditional causes_stun, so Impact stunned healthy targets; it only adds a SECOND marker to an already-Stunned figure |
| battle-resolution | Stunned — Move OR Combat Action, not both (p.40); marker removed after acting | small | In auto-resolved battles a Stunned figure — crew or enemy — suffers no penalty whatsoever: it moves and fires exactly like an unstunned one, and its Stun evaporates at the end of the roun... | FIXED f6e85b238 — stun was a BOOLEAN in auto-resolve, so markers could never accumulate and the p.40 '3 or more = knocked out and removed from play' could not fire at all. Markers now accumulate per hit and trigger removal, credited as a kill |


---

## ⛔ Sourcing trap found Aug 2: the Compendium contains a SECOND, CONFLICTING weapon table

**Before "correcting" any weapon value, check which SECTION of the Compendium you found it in.**

`docs/compendium.md` (~lines 5655-5714) prints a complete weapon table whose values contradict
the Core Rules table (`docs/core_rules.md` ~4020-4066):

| Weapon | **Core Rules (governs)** | Compendium *Game Options* |
|---|---|---|
| Suppression maul | Brawl, **1** dmg, *Melee, Impact* | Brawl, **2** dmg, *Melee, **Stun*** |
| Ripper sword | Brawl, **1**, *Melee* | Brawl, **2**, *Melee* |
| Shotgun | **12"**, **2** shots, 1, *Focused* | **8"**, **1** shot, 1, ***Critical*** |
| Shell gun | **30"**, **2**, 0, *Heavy, Area* | **18"**, **—**, 0, *Area* |
| Needle rifle | 18", **2**, 0, *Critical* | 18", **1**, 0, *Critical, **Piercing*** |
| Shatter axe | Brawl, **2**, *Melee* | Brawl, **3**, *Melee, Clumsy, **Shockwave*** |
| Marksman's rifle | 36", 1, 0, ***Heavy*** | 36", 1, 0, ***Critical*** |
| Scrap pistol | **9"**, 1, 0, *Pistol* | **7"**, 1, 0, *Pistol* |

That table sits under a `## Game Options` heading, followed by `## Designer notes`:

> "While many weapons have seen **minor tweaks**, of particular note are pistols... and melee
> weapons, which have received small boosts across the board. Area weapons no longer have
> inherent Shots on their profile, instead dealing damage only through the Area rule..."

**"Have seen tweaks" + placement under Game Options = an opt-in alternative weapon set, NOT
errata.** The Core Rules table governs standard 5PFH; `data/equipment_database.json` must match
it. Traits that exist only in the option set (**Overheat, Shockwave, Shrapnel, Burn**) must not
be attached to Core Rules weapons. If the alternative set is ever implemented it belongs behind
a toggle alongside the other Compendium Game Options, never as the default.

**A grep proving a value "is in the Compendium" is NOT sufficient sourcing.**

### This also means the audit quoted the wrong Area trait

- **Core Rules p.51 (implement this):** "Resolve all shots against the initial target. **They
  cannot be spread.** Then resolve **one bonus shot against every figure within 2"**."
- **Compendium *Game Options* (do NOT implement as default):** "Select a target point within
  range. Every figure within 2" of the target point are hit on an unmodified D6 roll of **4+**
  (**5+** if partially obscured from the blast)."

The Area finding in this document describes the Compendium version.

### Related discrepancy, unresolved

`data/elite_enemy_types.json:374` and `data/RulesReference/EliteEnemies.json:247` both state
**"Cop killer: Enforcers always become Rivals after a battle"**, while the Core Rules
(and `data/enemy_types.json:39`) state **"Cop killer: As Rivals, +2 to their numbers"**. These
are different rules. Likely the Elite-Enemies chapter legitimately restates it, but it has not
been verified against the Compendium page — check before touching either file.

## Verbatim book evidence for the battle-resolution domain

Extracted Aug 2 to save re-extraction; see the To Hit and Suppression rows above for the
headline results. Full brief (Stunned p.40, Brawling p.45, Aiming/Panic Fire p.46, all weapon
traits p.51, all six consumables p.54) was written during the session and its conclusions are
folded into the rows in this table.

---

## Handoff — state as of Aug 2 2026, end of the battle-resolution pass

**64 open / 79 resolved-or-partial of 143.** Branch `campaign-editor-and-fixits`.
Route and phasing: `docs/RULES_WIRING_CLOSEOUT_PLAN.md`. The short version — 40 of the
73 are DLC or endgame content no tablet tester can reach, so the near-term target is the
~33-row core loop, of which 6 are blocked on the Story Track session's files.

### Domain standings

| Domain | Open | Note |
|---|---|---|
| battle-resolution | **1** | only "dead duplicate calculators" — cleanup, no rules impact |
| turn-upkeep-travel | 7 | World Traits (40 effects) is the big one |
| battle-setup | 8 | deployment conditions, seize initiative |
| patrons-rivals-quests | 12 | Time Frame never expires; BHC subtables; Patron travel expiry |
| post-battle | 13 | Advanced Training, Crippling Wound, injury equipment loss |
| economy-trade-equipment | 15 | Trade Table 24 no-award rolls, gun mods, on-board items |
| factions-world-compendium | 20 | DLC-gated; a tester without the DLC never sees any of it |
| missions-elites-zones | 20 | Black Jobs, Red Zone conditions, Elite enemies |

### If the goal is a TABLET TEST SESSION, do these first

Ranked by "will a tester actually hit this in one sitting", not by finding count.

~~1. patrons-rivals-quests — Quest is unplayable.~~ **DONE `2c44839f0`** —
   "Continue a Quest" job option, p.89 objective column reachable, finale forced
   to Fight Off with +1 fight-to-the-death enemy, `is_quest_finale` produced so
   its four consumers fire, Rumors actually spent, progress gated on Quest
   battles, p.64 victory counts Quests. `tests/unit/test_quest_chain.gd`.
   The p.90 Defend objective landed alongside it in `3aa8d0b88`.

~~2. battle-setup — Number of Opponents difficulty modifiers.~~ **DONE
   `24c657af4`** — the count was reading `danger_level` (the p.83 Patron Danger
   Pay rating) as if it were the difficulty mode. Also fixed: Insanity's missing
   +1, the p.93 short-crew -1, and the p.99 Interested Parties reroll being
   applied to every Quest battle. Red Jobs untouched; zone tests still 7/7.

**Next up, in order:**

~~3. economy — the Trade Table's 24 no-award rolls.~~ **DONE `e2e56b985`** —
   the six "roll on another table" entries now award; the p.28 Low-Tech Weapon
   and p.29 Gear tables were also being resolved off the LOOT table.

~~5. post-battle — Advanced Training.~~ **DONE `c942fec91`** — nothing was
   spent and nothing was learned; plus XP-only payment, the unenforced
   one-course and one-attempt rules, Bot credits-only, Broker +1, the Feral and
   Engineer cost modifiers, and a fabricated eighth course. It was ALSO
   unreachable on a loaded save (`Array[Resource]` filter vs Dictionary crew).

**Next up:**

~~4. turn-upkeep-travel — World Traits.~~ **MOSTLY DONE `4fe221f50` +
   `a7449cea6`** — `WorldTraitEffects.gd` is the SSOT, all 31 campaign-side
   traits carry structured `effects` in JSON, and 19 have a live consumer
   (travel cost, departure, upkeep, repair, recruiting, patron search, Advanced
   Training, enemy numbers, Rival conversion, Invasion). The remaining 12 need a
   CALL SITE only — the resolver already exposes each one, and the tracker row
   lists them by name. Pick them off wherever you next touch the owning screen;
   `test_world_trait_effects.gd` fails if a new trait ships without an effects
   block, so the data side cannot regress.

~~6. patrons-rivals-quests — Patron Time Frame + the BHC subtables.~~
   **DONE `fab705684` + `592a67212` + `cfbd4f91f`.** `PatronJobEffects.gd` is the
   SSOT; `data/patron_generation.json` gained a stable `id` and an `effects` block
   per row, and JobOfferComponent's SECOND hardcoded copy of all 21 rows is gone.
   Offers now persist on the campaign with a real `deadline_turn`, lapse when it
   passes (Vengeful fires on a lapse), and leave with a Patron who does not follow
   you. 19 of 21 rows are applied.

   **Two rows still only reported, not applied** — pick these up here:
   - **Private Transport** (p.84, "If you have Rivals, they cannot track you this
     campaign turn") needs the p.85 Check for Rivals roll in
     `RivalEncounterCheck.gd`, which held another session's uncommitted work.
     `PatronJobEffects.blocks_rival_tracking(mission)` is ready; it needs one
     early-return.
   - **Busy** (p.84, "If the mission is a success, the Patron offers a new job
     next campaign turn"). `offers_new_job_on_success()` exists with no caller —
     and wiring it as written would be a **no-op**, which is the interesting
     part. Completing a job removes that offer from the store, so next turn the
     Patron has no live offer and generates one anyway: every Patron already
     offers work every single turn. Busy is only worth a table slot in a game
     where they do NOT, so the real divergence is our offer CADENCE, not the
     missing flag. Do not wire a distinction that does not exist; decide the
     cadence question first (the book never states a per-turn offer rate, which
     is why this needs a judgement call rather than a page citation).

~~7. patrons-rivals-quests — the three p.99 enemy-trait rules.~~
   **DONE `5eeee2c39`.** `EnemyTraitRules.gd` matches on the trait NAME before
   the colon, so the rest of the encounter tables' `special_rules` strings are
   now cheap to wire the same way — and `2d052d2de` + `1ac3697ab` did seven
   more: Cop killer, Scavengers, Tough fight, Careless, Alert,
   Prediction/Unpredictable and Going medieval.

   **What is left is print-only ON PURPOSE, probably.** Every remaining trait is
   an IN-BATTLE rule — Cowardly ("Lieutenants are affected by Morale dice"),
   Dogged (Fearless at 1-2 figures), Ferocious (+1 Brawling when initiating),
   Stubborn, Bad shots, Trick shot, Aggro, Easy targets, Needle fangs, Quick
   feet, Leap, Shimmer, Pack hunters, Up close. This is a tabletop COMPANION:
   the player resolves combat on the table, so surfacing these in the briefing
   may be the whole job. Decide that deliberately rather than by omission.

   **The sharpest lesson of the group** came from Going medieval: replacing a
   loadout ONCE is not enough. The Lieutenant branch re-rolls the basic column
   (p.93, "Lieutenants will both roll separately for their weapons") and so does
   Varied Armaments, so the resolver was correct and two later lines quietly
   undid it — the war leader kept a handgun while his mooks held blades. Test at
   the GENERATOR, not just the resolver, whenever a rule REPLACES rather than
   adjusts.

8. **patrons-rivals-quests — the two BHC rows left over** (Private Transport,
   Busy) — see the detail under item 6.

~~9. post-battle — the Injury Table's consequences beyond Sick Bay turns.~~
   **DONE `bffe2c8d1` + `d945a3ecb` + `b14974c37`.** 35% of every roll on the
   table produced nothing but time. Equipment: the flags were computed, stored
   on the injury dict and read by NOTHING, so p.78 Repair Your Kit had nothing
   to repair in any campaign. Crippling wound: the JSON had both halves of
   "1D6 credits of surgery OR -1 permanent" and neither had an accessor.

   **The knock-on chain is the lesson.** Fixing the producer surfaced two more
   layers that were also only half-built, and each was invisible until the one
   above it worked:
   - Campaign Event 45-48 damages the **STASH** (p.127), not carried gear —
     which needs `damaged: true` on the item dict, a flag Assign Equipment
     ("[DAMAGED]" suffix) and Purchase Items (sell-list exclusion) have always
     read and nothing had ever written. So p.122's "cannot be used until
     Repaired" was ALREADY enforced for stash items, with nothing to enforce on.
   - …which meant Repair Your Kit could not reach them, because it scanned only
     the acting character's status_effects. p.78 draws no such line.
   - Sick Bay reductions (Friendly Doc p.126, Health Insurance p.84) wrote
     `injury_recovery_turns`, a legacy mirror the turn rollover ignores.

   **Next in this area:** Step 8's other unimplemented row is nothing — the
   table is now complete. The nearest neighbours still open are Step 9's
   "Ability Increase Table is spent, not rolled" (the wizard says "Roll for
   advancement" and prints results that change nothing) and Step 10's Medical
   school / Bot technician injury rerolls, which now have a real Injury Table
   to reroll against.

Deliberately deprioritised for a tablet test: **factions** (DLC-gated, invisible
without the expansion) and **Elite enemies** (endgame).

### Hard-won rules that cost time to learn — read before editing

- **The Compendium prints a SECOND weapon table** under `## Game Options` whose
  values contradict the Core Rules (Shotgun 8"/1 shot vs 12"/2; Suppression maul
  2 damage Melee+Stun vs 1 damage Melee+Impact). Its designer notes call them
  "minor tweaks". It is an OPT-IN VARIANT, NOT ERRATA. A grep proving a value
  "is in the Compendium" is NOT sufficient sourcing — check the section.
  Same split applies to the **Area** trait.
- **gdUnit4 reports a parse error as "No test cases found" and EXITS 0.** A green
  exit code proves nothing. Check the executed-case count, every time.
- **A `.get(key, fallback)` whose fallback is a plausible NEIGHBOUR is worse than
  a crash.** Two p.88/p.94 tables picked the wrong column for years because
  `tables.get(mission_source, tables.get("patron", {}))` quietly turned every
  Rival battle into a Patron one — a quarter of them fought wildlife the book
  excludes outright. The output looked entirely reasonable at every step. When a
  key is a COLUMN SELECTOR, map the vocabulary explicitly and `push_warning` on
  anything unrecognised; never let an unknown source impersonate a known one.
- **When a rule says "consult the appropriate column", pin the columns with a
  TILING test.** Every column must cover 1-100 (or 1-10) with no gap and no
  overlap: a gap means a legal roll silently yields nothing, which is
  indistinguishable from the table's own "No Condition"/"no effect" row and
  therefore hides forever.
- **`verify_scripts_parse.gd` prints `=== N checked, 0 definite failures ===`
  with real parse errors in the same output.** Grep the run for `Parse Error`
  separately — the summary line is not the verdict. It caught a genuine one this
  session (`EquipmentTransferService.new()` takes a campaign) that the tally
  reported as clean. The tool ALSO emits `Compile Error: Identifier not found:
  TweenFX / GameStateManager / DataManager` for anything touching an autoload,
  because `--script` mode has no autoloads. Those are noise; `Parse Error` is not.
- **A correct JSON table is not a live one.** `patron_generation.json` held all 21
  BHC rows byte-correct against pp.83-84 — and `JobOfferComponent` carried a
  SECOND hardcoded copy in GDScript, so the JSON was decorative and a correction
  to it would have changed nothing in play. Before "fixing" a data file, grep for
  a second implementation of the same table.
- **A live consumer with no producer looks exactly like a working feature.**
  `NewWorldArrival.is_persistent_patron()` read `is_persistent` off a Patron and
  nothing anywhere ever wrote it, so the p.84 Persistent Benefit could not spare
  a single Patron from the travel purge. The travel step LOOKED implemented, and
  was, in one direction only. When wiring a rule, check both halves meet.
- **Godot's JSON parser returns EVERY number as a FLOAT.** `value is int` is
  always false on loaded data; `[1.0, 15.0] != [1, 15]`. `int()` both sides.
- **A test suite can pin fabricated rules as firmly as correct ones.** Four tests
  failed when the to-hit math was corrected, and all four were asserting invented
  behaviour. Convert them, do not delete them.
- **Dead + wrong is a much stronger deletion warrant than dead alone.** CLAUDE.md
  records a sweep that deleted three methods as "zero-caller" when they were only
  zero-caller because their consumer had been removed weeks earlier. Before
  deleting a zero-caller provider, ask what used to call it — but if the content
  also contradicts the book, the question is moot.
- **Fixing a producer is how you find the next missing producer.** Wiring the
  p.122 equipment rows exposed, in order: the wrong container (p.127 says Stash,
  not carried gear), a stash-damage flag with TWO readers and no writer, a repair
  task that could not see the container the book puts items in, and a Sick Bay
  reducer writing a field the countdown ignores. None of those were visible while
  the first producer was dead, because a pipeline with a broken source looks
  identical to one with no consumers. Expect a chain, and re-verify the CONTAINER
  the book names before assuming the target.
- **Your own test catching your own wrong target is the system working.** The
  first Equipment Malfunction test asserted crew gear and failed once the book
  was read properly. Write the assertion against the book's words, not against
  the implementation you just wrote, and it will tell you when you are wrong.
- **A fabricated CITATION is worse than an uncited invention.** `// Ferals ignore
  suppression (Five Parsecs p.20)` attached a real page number to a rule that
  page does not contain, and survived review by looking sourced.

### Verification commands that work

```powershell
# Parse sweep — the fastest global check. "0 definite failures" is the verdict;
# the '?' markers are its indeterminate bucket (it flags even itself).
& "$GODOT" --headless --path "$ROOT" --script tests/tools/verify_scripts_parse.gd

# gdUnit4 — note -c, and NEVER --headless. Always read the case COUNT.
& "$GODOT" --path "$ROOT" --script addons/gdUnit4/bin/GdUnitCmdTool.gd -c `
  -a tests/unit/test_battle_calculations.gd --quit-after 300
```

Battle regression set, all green at handoff (130/130): `test_battle_calculations`,
`test_battle_resolver_router`, `test_battle_funnel_routing`,
`test_zone_job_opposition`, `test_enemy_deploy_markers`,
`test_weapon_table_source_of_truth`.
