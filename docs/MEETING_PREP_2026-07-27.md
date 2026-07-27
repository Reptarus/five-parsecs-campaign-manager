# Meeting Prep: Chris Birch, Mon Jul 27 2026, 9:00 to 10:00am PDT

**Meeting**: "Design document" (Google Meet `meet.google.com/wfu-espr-ewd`)
**Calendar note from Chris**: "Touching base before gencon"
**Attendees**: Elijah, Chris (accepted), Gavin (no response yet)
**Context**: Gen Con runs **Jul 30 to Aug 2** in Indianapolis. This call is 3 days before. Assume Chris is largely unreachable from Jul 29 through roughly Aug 6. Anything that needs a Modiphius decision either lands tomorrow or slips two weeks.

---

## 0. Two deliverables. Do not leave without both.

1. **The LOI finalised and signed on the call** — including the monetization model written into it, replacing "pricing model is still open."
2. **An alpha start date, with Modiphius's side of the launch committed to it.**

Both are achievable on this call. Everything else on this list is optional.

**The monetization model is not a separate agenda item. It is a term in deliverable 1.** It was parked in May pending alpha data, the alpha never started, and the park became a permanent hole. Decide the model (§3, it is already written), put it in the doc, sign it. Only the price stays open for alpha.

---

### Deliverable 1: get the LOI signed on the call

**It is one negotiation item and three blanks away from signature, and two of those blanks are yours.** Close yours on the call so the only thing left is his signature.

| Item | Whose | Do this |
|---|---|---|
| Fee threshold | Both | Bring the taper wording (§2c). Resolve it verbally and type it in live |
| Signing entity | **Yours** | Sign as an individual. See below |
| Your address | **Yours** | Fill it in before the call |
| Governing law | Both | Do not let this block. Say "England and Wales is fine for the LOI, we will set it properly in the long-form" |

**On the signing entity:** sign as an individual. The LOI is explicitly non-binding except confidentiality and good faith, so signing personally costs you nothing and can be superseded when the Definitive Agreement is drawn up. Add one line: *"Developer may substitute a business entity before the long-form agreement."* Waiting to form an entity is not worth another month.

**The technique that matters: do the edits live, on screen, during the call.** It is a Google Doc. Share your screen, make the taper edit, fill your blanks, resolve his comment, and ask him to sign at the bottom before you hang up. **Do not leave with "I'll update it and send it over."** That is exactly how the last two months went.

**Why he has no good reason to refuse:** an LOI signature is cheap. It is non-binding, it commits him to nothing but good faith, his business manager and MD have both already reviewed it, and he said "broadly there" three weeks ago. If he still will not sign a non-binding document after that, his answer is itself information worth having.

**The sentence:**

> "I would like to sign this today. It has been through your business manager and your MD, you said we were broadly there on the fourth, and there is one open comment. If we settle the fee level now I will fill in my side on screen and we can both sign before you go to Gen Con. I need documented commitment to keep this at the top of my stack."

That last sentence is the honest one. Say it plainly. It is not a threat and Chris will understand exactly what it means.

---

### Deliverable 2: the alpha date

**The alpha is a coordinated launch, not a build milestone.** The testers come from Modiphius's channels: the 5PFH newsletter, the official Discord, social, the Facebook community group. Gavin has to create the private tester channel and assign roles. Without Modiphius acting there is no cohort, so it has never been yours to schedule.

**The delay has been on his side, and the record is what it is:**

| Date | What happened |
|---|---|
| May 25 | Kickoff target. Call happens, three drafts assigned to you |
| May 26 to 27 | You deliver all three drafts plus the one-pager |
| Jun 1 | You bump. *"we've all been at UK Games Expo since Thursday... hope to respond in next couple of days latest"* |
| Jun 4 | Instead of alpha feedback, a new request: the master design document |
| Jun 4 | *"running through this with our MD... bear with us"* |
| Jun 8 | Asks to see the art |
| **Jun 8 to Jul 4** | **Nothing. Four weeks.** |
| Jul 4 | LOI comments. *"I'll need a couple of days to check in with my business manager"* |
| **Jul 6 to Jul 18** | **Nothing. Twelve days.** |
| Jul 18 | The fee-threshold comment |
| Jul 26 | Still no alpha date |

Two months, and every touchpoint moved to something other than starting the test. Name it once, flatly, and move to the ask.

**The lever is his own sentence**, Jul 8: *"I think critical goal is to get your playtesting moving and the right paperwork in place to give you assurance we're on board."* Both of tomorrow's deliverables are things **he** called critical, and he listed playtesting separately from the paperwork, so the alpha is not gated on the LOI by his own framing.

**The ask, small enough to say yes to on the call:**

1. A date. You name a candidate, he confirms.
2. Amplification that week: newsletter, Discord, social, Facebook group. Already agreed in principle, form already reviewed Jul 4.
3. Gavin creates the private tester channel and assigns roles. He already has your Discord details — you have been in the server for months — so this is purely him doing it.

**The cost of not getting it tomorrow:** Gen Con is Jul 30 to Aug 2, and with recovery he is realistically gone until Aug 6 to 10. No date tomorrow means a mid-to-late August start, another three to four weeks on top of the two months. Say it out loud. It is the calendar, not a threat.

**Your side is done. Say so, because it removes the last thing he could point at.**

The in-app bug reporter — the item flagged back in May as the one greenfield blocker before A1 — **was built and verified last night**. Testers can file a report in two taps from anywhere in the app; it captures the screen, campaign phase, turn, device and the app log automatically, saves to disk before anything else so nothing is ever lost, and posts straight into a private Discord channel. 51 automated tests, all four project lints clean, verified live on desktop in landscape, portrait and with the game paused.

Everything else was already ready: core loop verified end to end Jul 10, 151 test suites green, on-device Android testing Jul 5 to 6 that found and fixed six device-only bugs.

**The one honest caveat, and you should volunteer it rather than be asked:** your tablet died and the replacement is in transit, so the reporter is verified on desktop but **not yet on Android**, which is the alpha platform. A static audit already caught two Android-only defects (a config file that would never have shipped inside the APK, and app logging that was silently off on Android), both fixed. What remains is a device pass: touch-scroll, the mail intent, sandboxed file writes.

**So factor the tablet into the date you name.** Do not commit to a start that assumes device testing you cannot currently do. "Testers get the build the week after my replacement tablet lands" is a defensible, honest commitment; a hard calendar date that silently depends on hardware in transit is not.

**The script:**

> "The other thing I want to leave with is the alpha date. It has been two months since the May 25 target and I have had the build, the form and the docs ready that whole time. The last piece on my side, the in-app bug reporter, is now built and tested — testers can file a report in two taps and it comes straight to me with the screen, the campaign turn and the app log attached. The only thing left on my end is a device pass, and my tablet died so I am waiting on the replacement. What I need from you is the amplification push in the week we pick, and Gavin standing up the private tester channel. If we do not set it today, Gen Con puts us into mid-August, and that is another month gone."

If it helps him say yes: Modiphius is at Gen Con with the Five Parsecs line Jul 30 to Aug 2. Opening signups that week costs him nothing and puts the form in front of exactly the right audience.

---

### Before the call, decide your own line

You are close to walking, and that is a legitimate position rather than a mood: you own the code, nothing is signed, the LOI is non-binding, and your exit cost is as low right now as it will ever be. Decide tonight, for yourself, what you need out of tomorrow to keep prioritising this. Do not say it as a threat on the call. *"I need documented commitment to keep this at the top of my stack"* carries the same information and leaves him somewhere to go.

---

## 1. The commitment checklist — get these said OUT LOUD

**This is the actual instrument for this call.** Not a presentation. Nine closed questions, each needing a yes, a no, or a date from Chris's mouth. Keep this open and tick as you go.

**The rule for the whole hour: no item leaves the call as "we'll sort it over email."** That mechanism has produced two months of nothing. Every time he reaches for it, use the deflection line below.

**The deflection line** (say it warmly, use it every time):
> "You're travelling Thursday, so email will put this into mid-August. Can I get a yes or no now, even a provisional one? I'll write it up straight after and you can correct anything I got wrong."

| # | Ask him, verbatim | What counts as an answer | Got it |
|---|---|---|---|
| 1 | "Can we sign the LOI today, on this call?" | **Yes / no.** If no: *"What specifically is left, and what date can you sign?"* | ☐ |
| 2 | "On the fee level, does the taper work — full fee to $3,000, straight-line to zero at $5,000?" | **A number he says out loud.** Not "sounds reasonable" | ☐ |
| 3 | "Are we agreed the model is one-time purchase plus a paid unlock per book, no subscription at launch?" | **Yes / no.** If he wants subscription: *"What content programme funds it?"* | ☐ |
| 4 | "What date do testers get the first build?" | **A calendar date.** Not "soon," not "after Gen Con" | ☐ |
| 5 | "Will the newsletter, Discord, social and the Facebook group push the signup that week?" | **Yes / no, and who owns it** | ☐ |
| 6 | "When can Gavin stand up the private tester channel? He already has my Discord." | **A day** | ☐ |
| 7 | "Can the alpha signup ride along at Gen Con — a QR code or a line in whatever goes out?" | **Yes / no.** Cheap for him, fine if no | ☐ |
| 8 | "You offered to include any Five Parsecs own-IP products. Yes, as a right rather than an obligation, same terms, each as its own paid unlock?" | **Yes / no** | ☐ |
| 9 | "I'm parking the full illustrated art system until the app ships. Any objection?" | **Acknowledgement.** Just get it on the record | ☐ |

**Items 1 and 4 are the call.** If you get nothing else, get those two.

### How to open, so the shape is set before he starts

> "Chris, before we get into anything — I want to leave this call with two things settled rather than opened: the LOI signed, and a date testers get the build. I've had everything ready since May and I don't want another round of email between us. Can we work through it that way?"

Asking permission for the *format* up front makes the deflection line non-confrontational later. You're just holding him to something he agreed to in minute one.

### Convert verbal to written the same day

Send the recap within two hours, before he travels. Short, in the email body, Gavin copied, one line per commitment:

> "Quick record of what we agreed, correct anything I got wrong: LOI signed [or: you'll sign by X]. Fee tapers full to $3,000, zero at $5,000. Model is one-time purchase plus per-book unlocks. Testers get the first build [DATE]. Modiphius amplifies that week across newsletter, Discord, social and the group. Gavin sets up the tester channel by [DATE]. Illustrated art system parked until after launch."

Silence on that email is acceptance, and it becomes the thing you point at next time.

### Prepared counters for his three likely deflections

**1. "I don't want you to over-extend yourself, especially if a role comes up."**

He has said versions of this before, and it reads as consideration while functioning as a reason to relax the pace. Flip it, warmly:

> "I appreciate that, genuinely, but I'd turn it around. Right now I'm full-time on this, and that's the scarcest thing in the project. If I do take a role it becomes evenings and weekends, and an alpha takes three months instead of six weeks. So the window to run this properly is now, and every month we wait spends the one input that's hardest to get back."

Your availability is an asset with an expiry, not a liability to be protected. He almost certainly has not framed it that way.

**2. "Let me check with [business manager / MD / the team] and come back to you."**

Both have already reviewed the LOI, and he said "broadly there" on Jul 4.

> "They've both been through it and you said we were broadly there three weeks ago. Is there anything in it you'd expect them to change? If not, can we sign and let them raise anything in the long-form?"

**3. "Let's pick this up after Gen Con."**

> "That's realistically mid-August, which is another month on top of two. Can we settle just the date and the signature now, and leave everything else until you're back?"

Narrowing to two items makes yes much cheaper than a full deferral.

### If he will not commit to anything

That is also an answer, and you should treat it as one rather than absorbing it as another delay. Say plainly: *"I need documented commitment to keep this at the top of my stack."* Then decide afterward, not in the moment.

---

## 1b. Suggested 60-minute shape

| Time | Item | Checklist |
|---|---|---|
| 0:00 to 0:05 | Set the format (script above) | — |
| 0:05 to 0:25 | **LOI: fee level, pricing-model paragraph, edit live, sign** | 1, 2, 3 |
| 0:25 to 0:40 | **Alpha date and his side of the launch** | 4, 5, 6, 7 |
| 0:40 to 0:50 | His items, and the art line | 8, 9 |
| 0:50 to 1:00 | Read the commitments back to him before hanging up | all |

**Drop order if it runs long: art, then his items, then monetization detail. Never items 1 or 4.**

---

## 2. Item 1: the LOI is one item from done

**State of play, verified against the live Google Doc today:**

- Chris (Jul 4): *"I'll need a couple of days to check in with my business manager... but i think we're broadly there."*
- Chris (Jun 4, separate thread): he is running it past *"our MD who handles a lot of the commercial deals."*
- Modiphius has filled in their own entity address (3rd Floor, 39 Harwood Road, London SW6 4QP).
- Chris's two suggested edits on the maintenance fee are **already merged into the body text**.
- Tester rewards are **already resolved** in the body: credited as playtesters plus free access to the app and paid content.

**What is actually still open:**

| Item | Status |
|---|---|
| Fee threshold above which the fee is not taken | **OPEN. The only substantive one.** Chris's comment, Jul 18. |
| Signing entity and address (yours) | Blank |
| Governing law | Blank, depends on entity |
| **Pricing model** | **Says "still open." Close it — see §3d for replacement wording** |
| Scope of "any Five Parsecs own IP products" | Chris offered it Jul 18, needs a yes plus terms |

### 2a. The fee threshold: what Chris proposed

> *"We'd like to propose a level above which the development fee is not taken first. For example if net receipts reach $3k per month, then it would simply be a $1500 split each way. If it was $2k a month, you'd receive $1000, then we'd each receive $500. Need to discuss the level that is fair."*

**Do not fight the concept.** It is a reasonable instinct: the fee is there so maintenance is funded when times are lean, and at scale a straight split is simpler. Concede the principle immediately. Then fix the mechanism.

### 2b. The defect: a cliff, not a slope

With fee `F` = $1,000 taken off the top, your share of net `N` is `(N + F) / 2`. Above the threshold it becomes `N / 2`. So:

| Monthly net | You, under the LOI today | You, under Chris's $3k cliff |
|---:|---:|---:|
| $2,999 | $1,999.50 | $1,999.50 |
| **$3,000** | $2,000.00 | **$1,500.00** |
| $3,500 | $2,250.00 | $1,750.00 |
| $3,999 | $2,499.50 | $1,999.50 |
| $4,000 | $2,500.00 | $2,000.00 |

**Earning one dollar more drops your income by $499.50, and you do not get back to where you were until net receipts reach $3,999.** That is a $999 dead zone, and its width always equals the fee. This is not a haggle about the level. Any threshold set this way has the same hole in it.

### 2c. The counter to bring: taper, do not cliff

Say it in one line: *"Happy with the principle. Let's phase it out rather than switch it off, so neither of us is sitting on a cliff edge."*

**Proposed language:**

> The monthly maintenance fee is taken in full while net receipts are at or below $3,000 per month. Between $3,000 and $5,000 the fee reduces on a straight line to zero. Above $5,000 per month no fee is taken and net receipts are split 50/50.

**What that does to the numbers:**

| Monthly net | You, LOI today | You, Chris's cliff | You, taper | Modiphius, taper |
|---:|---:|---:|---:|---:|
| $3,000 | $2,000 | $1,500 | **$2,000** | $1,000 |
| $4,000 | $2,500 | $2,000 | **$2,250** | $1,750 |
| $5,000 | $3,000 | $2,500 | **$2,500** | $2,500 |
| $10,000 | $5,500 | $5,000 | **$5,000** | $5,000 |

It is continuous at both ends, always monotonic, and at $4,000 it lands exactly halfway between the two positions. Chris gets the thing he asked for: at scale, the fee is gone and it is a clean 50/50.

### 2d. The point to make if he pushes on the level

Chris has already secured Modiphius's downside twice in his own edits: the fee is *"recoupable from net receipts"* and *"in the event that royalties are not sufficient... Modiphius will not owe the developer any part of the fee."* **Modiphius cannot lose money on this fee under any scenario.** Asking for a ceiling as well as a floor is asking for both ends. One or the other is fair.

Also worth saying plainly, without heat: the fee is payment for ongoing work, not a hardship subsidy. Support load goes *up* with users, not down. If the fee disappears at scale, the service obligation should be described in the long-form agreement as best-efforts rather than a commitment.

### 2e. Separate wording flag: "recoupable"

The merged sentence reads *"a monthly maintenance / support / development fee of $1,000, which is recoupable from net receipts and..."*

"Recoupable" is a term of art meaning an advance that is later recovered out of the recipient's earnings. Read strictly, that says Modiphius can claw the fee back out of your 50%. The following sentence makes the intent clear, but the two together are muddled. Ask for it to be replaced with plain wording:

> The fee is payable only out of net receipts. If net receipts in a given month are less than the fee, the fee for that month is limited to the receipts available, and Modiphius owes no shortfall.

Frame it as tidying, not as a challenge. It costs Chris nothing.

### 2f. Small fixes while the doc is open

- Typo: *"I I own and run the tester list"* (double I).
- Tester reward scope: *"any additional paid content under the 'Five Parsecs From Home' application"* is open-ended. If the app later carries other Five Parsecs family products, that is a lot of free content forever. Suggest scoping it to Five Parsecs From Home content, or to content released within 24 months of launch. Small, and you look careful rather than grabby.

---

## 3. Item 2: the monetization model — DECIDE IT, do not present it

**This is not a recommendation to deliver. It is a hole that has to be closed, and it belongs in the LOI you are signing.**

### 3a. Why it is still open, and why that has to end tomorrow

The model was deliberately parked on May 25, to be settled with alpha data. **The alpha never started, so the park became permanent.** It is now circular: no model, so the alpha cannot test pricing, so no data, so still no model. Two months gone.

Meanwhile it is blocking real things:

- The LOI you are about to sign says *"Pricing model is still open."* You would be signing a commercial agreement whose central economic variable is undefined, and the maintenance fee, the $35,000 recoup and the 50/50 split are all priced against revenue whose shape nobody has agreed.
- **Chris is already assuming a subscription might exist.** His LOI comment on tester rewards reads *"free purchase, or free X months whichever we decide on."*
- The DLC "unlock all content" switch has no implementation because it is tangled with the undecided model.
- Google Play requires products or subscriptions to be declared at listing. You cannot set up the store without this.
- Every forecast Modiphius has seen assumes $18 one-time ARPU.

### 3b. The distinction that unblocks it

**The price needs alpha data. The model does not.**

Price is an empirical question: what will people pay. That genuinely needs Van Westendorp during alpha, exactly as `PRICING_RESEARCH_PLAN.md` lays out.

Model is a structural question, answered by what the product is and by evidence already in hand. Parking it was the error. Decide it now, let alpha refine the number inside it.

### 3c. The decision

**One-time purchase for the base app, one-time paid unlocks per book, no subscription required to play. An optional all-access tier stays possible later, deferred rather than refused.**

The reasoning, in the order that will land with Chris and survive being retold to his board member:

1. **Modiphius has already run the experiment.** Fallout companion app, ~40,000 installed base: **1,650 non-subscription purchasers versus 1,200 active subscriptions**, 3.0% subscription penetration. On an app offering both, more people bought than subscribed.
2. **A subscription needs a content treadmill and this product does not have one.** Fallout Wasteland Warfare gains content with every Fallout release. 5PFH is a finite ruleset, and the stated goal is that the app carries all of it. Once it does there is nothing left to meter, and "what am I paying for this month" has no good answer.
3. **The form factor argues against it.** Solo, offline, at the table. It has to work in a basement with no signal.
4. **2026 is a bad year to meter ownership.** Stop Killing Games passed 1.25M signatures and went to EU lawmakers in April; Sony's Jul 1 digital-only announcement drew the UK retailers' association calling it "a triumph of corporate convenience over consumer choice." The solo tabletop audience is the most ownership-minded segment there is, and the backlash would attach to Modiphius.
5. **Per-book unlocks solve a requirement Chris raised himself.** His LOI comment: *"We'll have to be able to identify sales of those products to pay royalties."* One paid unlock per book gives per-product attribution per storefront, automatically. **It is already built**: `StoreManager` per-SKU product IDs, `DLCManager` 33 content flags across 3 packs, plus a Bug Hunt SKU and a bundle. Point at it rather than promising it.

**Be ready for the fair counter:** 1,200 recurring subscribers can out-earn 1,650 one-time buyers over time. That is true, and point 2 is the answer.

### 3d. Put it in the LOI, replacing the "still open" paragraph

Proposed replacement for the *"Pricing model is still open"* paragraph:

> **Pricing model.** The app is sold as a one-time purchase, with each expansion available as a separate one-time paid unlock corresponding to the physical product line. This gives per-product sales attribution for royalty purposes. The specific price points are to be confirmed using data from the closed alpha and Early Access. A subscription or all-access tier is not part of the launch model and would be a separate decision if the content programme later justifies it. The monthly maintenance fee applies regardless of pricing model.

That last sentence matters: it closes the ambiguity Chris's own "if subscription" phrasing left open on the May 25 call.

### 3e. The actual price ladder

ARPU is a *derived average* across base plus expansions, not a price anyone pays. The prices being proposed:

| SKU | Price | Basis |
|---|---:|---|
| **Base app** (Core Rules campaign, full loop) | **$9.99** | Top of the mobile premium band. Direct precedent: **Six Ages 2** ships $9.99 iOS / $24.99 Steam simultaneously and has held both for years; King of Dragon Pass held $9.99 on iOS for 5+ years |
| Compendium bundle (3 packs) | $9.99 | 3 x $4.99 individually = $14.97, so the bundle is ~33% off — matches the "Complete Edition, 10–20% bundle discount" guidance in `PRICING_RESEARCH_PLAN.md` §6 |
| — each pack individually | $4.99 | The plan's "~1/3 to 1/2 of base price" DLC tier |
| Planetfall | $6.99 | Higher tier: a full standalone game, not a supplement. Physical is $55 MSRP |
| Tactics | $6.99 | Same reasoning |
| Bug Hunt | $4.99 | Supplement tier |
| **Weighted ARPU** | **$15.63** | Derived, not charged. See §3f |

Everything digital sits at a fraction of the physical MSRP, which supports the T4 digital-to-physical conversion thesis rather than cannibalising it.

**Say the model with confidence, the number as provisional.** That distinction is the whole point of §3b: the *model* is decided on product shape and his own Fallout data; only the *price* needs alpha to confirm.

> "Nine ninety-nine for the base app, expansions at five to seven behind it. The precedent is Six Ages 2, which ships at nine ninety-nine on mobile and twenty-four ninety-nine on Steam simultaneously and has held both. I'm confident about the structure now. The exact number is one of the things the alpha is for, and I'd rather confirm it with tester data than lock it today."

### 3f. The numbers, corrected 2026-07-27

Two things were wrong in the forecast Modiphius has already seen, and both are now fixed in `MODIPHIUS_DIGITAL_FORECAST.md` §5b-rev. **Do not quote the old figures.**

**Correction 1 — ARPU was overstated ~20%.** The `$18 weighted ARPU` assumed each buyer takes ~1.15 expansions. Chris's own confirmed physical sales say otherwise: Planetfall attached at **18.5%** of Core (6,000 vs 32,500) and Tactics + Bug Hunt at **15.4%** (5,000). **82–85% of core buyers never bought an expansion.** Real expected purchases per buyer is 0.68. Corrected ARPU is **$15.63**.

**Correction 2 — every table was Steam-based.** The product is mobile-first, so the platform fee is 15% under the small-business programmes, not Steam's 30%.

**Corrected, mobile-first, book-by-book:**

| Scenario | Conversion | Net/year | **Per month** |
|---|---:|---:|---:|
| Conservative | 5% | $33,958 | **$2,830** |
| **Moderate** | **10%** | **$67,902** | **$5,658** |
| Strong | 20% | $135,818 | $11,318 |

**This changes the fee-threshold argument, and improves it.** Conservative sits at **$2,830/mo**, just under his proposed $3,000 threshold. Moderate sits at **$5,658/mo**, just above the $5,000 taper endpoint. So **the $3,000–$5,000 band is exactly the range the app passes through as it ramps** — which is precisely when a hard cliff bites, and precisely why the fee should phase out rather than switch off.

> "The band we're talking about, three to five thousand a month, is the range the app passes through on its way up rather than somewhere it sits. That's the worst possible place to put a step, because it hits during the ramp. Phasing it out over that band means neither of us is watching a threshold."

### 3g. The one number to ask him for

The **Compendium's DTRPG sales figure**. It is `[UNKNOWN]` in §4c, it is the expansion closest to core, and its attach rate is the single biggest lever in the pricing model — the corrected ARPU assumes 25% and that is the only assumed input in the chain. A two-minute lookup on his side.

> "One thing that would sharpen the pricing case: do you have the Compendium's DriveThru numbers? Planetfall and Tactics I can derive from what you gave me, but the Compendium is the one closest to the core book and it's the number my model is least sure of."

### 3h. Do not volunteer a revenue total

If he asks what it will make, give the **structure**, not a figure. Every number he has seen is wrong twice over (Steam basis, inflated ARPU), and the corrected ones still rest on a scenario ladder rather than real data. The honest line, which is also the true one:

> "I've got a corrected model and I'll send it over, but the conversion rate underneath it is still an assumption. That's one of the things the alpha is actually for — it replaces the guess with a real number. I'd rather re-base the forecast on tester data than commit to a figure I'd have to walk back."

## 4. Item 4: art — the answer is "park it"

**Position: the illustrated narrative art system goes on the backburner until the basic app ships.**

That is the whole item. It is too much work for both sides right now, it is not what is blocking a good product, and it adds a multi-party approval dependency on top of an alpha that has already slipped. Revisit after launch.

### 4a. Why, in the two sentences Chris needs to hear it in

He asked for "a sense of how much." The honest answer is what justifies parking it:

> "I built the proof of concept to see what it would look like, and that told me the real scope. Two of the three asset classes it needs have never been made, because books do not need them: per-scene actor layers that are currently painted into the flat images, and a crew figure set across 28 species, where I have already used every species concept piece that exists. On top of that it needs a change to how the PSDs are organised and a steady flow of approvals between you, Richard and me."

> "That is more work than it is worth for either of us right now, so I would rather park it and get the app out. The narrative system stays in with the art we already have, and we can revisit the full version once there is a shipped product to build on."

### 4b. Backup numbers, only if he pushes

- The 4 PSDs already extracted total **122 layers**, of which 44% are copies or transforms of another layer and 34% are non-NORMAL blends. **0 of the 122** classification decisions have been made.
- 6 adjustment layers cannot be exported as pixels at all, so extraction loses the colour grade.
- Per-scene actors do not amortise even between scenes: 34 planned across the 7 Story Track events, and **16 of those 34 are multiple instances of one object type inside a single scene** (4 sentries in event 07, 3 mercs in event 02).
- The 16 crew figures on disk are cutouts of the books' species concept art, dimensions ranging 604x1010 to 4104x6838. They cover 10 of 28 species and there is no second concept piece to go get.

### 4c. What ships instead

Nothing changes and nothing is lost. The narrative system already works, `story_event_01` renders, and the 8 sub-category backdrops are already in. Text and atmosphere carry the rest. This is a deferral of the *full* treatment, not of the feature.

One dev-side note if you demo: `export_presets.cfg:10` excludes 12 of the 13 scene directories from the **Android** build, so demo from Windows or you will show gradients.

---

## 5. Verify before the call: the MOBILE ONLY discrepancy

Your Jul 8 email said: *"I updated the language that it should be MOBILE ONLY, let me know if I missed anything."*

**The live LOI does not say that.** As of today it still reads:

> "The plan is mobile first, Android to begin with and iOS to follow, with a desktop edition on Steam as the Early Access milestone we are building toward."

and

> "The first big shared milestone we are working toward is Steam Early Access."

Either the edit did not save, or it went into a different document (possibly the one-pager).

**Recommendation: do not "fix" it. The current text is the better position, and you should keep it deliberately.**

- "Mobile only" reads as a restriction. In a document that grants exclusivity for the Five Parsecs digital companion app, restricting the app to mobile could mean a later Steam edition needs a fresh negotiation. That gives away the desktop option for nothing.
- "Mobile first, Android first, iOS to follow, desktop edition on Steam as the milestone we are building toward" says the same thing about priority while retaining the right.
- It also keeps the LOI consistent with every forecast Modiphius has already seen.

**How to raise it, briefly and without drama:** *"On platform language, I said I'd tighten it to mobile only. Looking at it again I'd rather it read mobile first with the desktop edition retained, because that is what we actually mean and it keeps our options open. Mobile is the launch platform and the right form factor for a companion. Steam is still the milestone."*

---

## 6. Chris's items: be ready, do not lead with these

### 6a. The new Five Parsecs product

From the LOI comments (Jul 4, updated Jul 18):

> *"We have another Five Parsecs product - a space fight squadron version still to come, plus a traveller edition which will sit alongside the family... We'll have to be able to identify sales of those products to pay royalties though."*

and

> *"We could say that any Five Parsecs own IP products can be included (so not Traveller) as that is a natural fit and there's no external royalties or approvals involved."*

This is almost certainly the *"thought which is tied in to a new Five Parsecs product that might help"* from his Jul 8 email. Note: the squadron game appears to be **unannounced** (no public trace found). Treat it as confidential.

**Your position:**
- **Yes** to including all Five Parsecs own-IP products under this agreement. It is more content under one deal, more SKUs, more revenue, and it strengthens the T3 platform story.
- **As a right, not an obligation.** Each product is added by mutual agreement when it is ready. You should not be committed to building content for a book that does not exist yet on terms set today.
- **Same commercial terms**, with each product shipping as its own paid unlock.
- **Royalty attribution is already solved.** Per-product DLC SKUs give per-product sales data by storefront. Say that plainly, it is a strong moment: he raised a requirement and the answer is that it is already built.
- **Traveller stays out**, as he suggested. Third-party licence, external approvals, not worth the complexity in a first agreement.

**Prepare for the possibility that his monetization "thought" is a crowdfunder tie-in.** He mentioned crowdfunding in his Jun 4 email as part of the growing FiveX audience. If he proposes bundling the app into a campaign, the things to think about live:
- A paid add-on SKU at a real price is good: guaranteed volume, and it recoups $35,000 fast.
- A free stretch goal or free-with-pledge is bad: it gives away thousands of copies, destroys the launch price anchor, and it is your recoupment that pays for it, since you keep 100% until $35,000.
- The line to hold: *"Happy for the app to be part of a campaign. I'd want it as a paid add-on rather than a free inclusion, because until recoupment those units are the only thing paying the development cost back."*

### 6b. Gen Con is an opportunity, ask for it

Chris's stated critical goal is getting playtesting moving. Modiphius is at Gen Con Jul 30 to Aug 2 with the Five Parsecs line, and Planetfall shipped this year. The alpha signup form is drafted and Chris has already reviewed it.

**Ask:** *"If there is any Five Parsecs presence at Gen Con, can the alpha signup ride along? A QR code on the stand, a line in whatever goes out that week. It costs nothing and it is the cheapest tester recruitment we will ever get."*

This is a strong ask because it serves his priority, not yours, and it is free.

### 6c. Tester rewards

Already resolved in the LOI body. Only raise it to tighten the scope wording per §2f. Do not reopen the substance.

---

## 8. Things to have open on your desktop at 8:55

1. The live LOI, at the fee-threshold comment.
2. This document, at §2b (the dead-zone table) and §3e (the mobile forecast table).
3. The app running, on the layered Firefight or Meeting scene.
4. A phone-shaped window of the same scene, for the letterbox demo.
5. The alpha signup form draft, in case the Gen Con ask lands and he wants to see it.

---

## 9. What to send within two hours of the call

Chris disappears into Gen Con on Wednesday. Send the recap the same day, short, in the body of the email, with Gavin copied:

- The agreed fee mechanism, in one sentence, so he can paste it into the doc.
- The monetization recommendation in three bullets, written so he can forward it to the board member verbatim.
- The art tiers with the one question attached (which tier before alpha).
- The alpha date and the one ask (amplification, plus Gen Con signup if he said yes).
- Anything he owes you, with "after Gen Con" attached so it does not look like pressure.

House style: no em dashes.

---

## Appendix: sources for every number in this document

| Claim | Source |
|---|---|
| Meeting time, Gen Con note, attendees | Google Calendar event `73aloapsaei3ke40j8plvvpftn` |
| Gen Con 2026 dates | [gencon.com future dates](https://www.gencon.com/attend/futuredates) |
| Chris's fee threshold proposal | Live LOI comment `AAACDOeqcaU`, Jul 18 2026 |
| Chris's "broadly there" and business manager | Live LOI comment `AAAB_DnNdc4`, Jul 6 2026 |
| Chris's new-product and royalty-attribution comment | Live LOI comment `AAAB_DnNdc0`, Jul 4 and Jul 18 2026 |
| Current LOI body text, incl. platform language | Google Doc `1QH5QC9Ckkf8Llnh3ITXI0XbwZSEhV01JbhQoTYqCqlI`, read Jul 26 2026 |
| Chris "intrigued to see how the art will work" | Gmail thread `19e94509667b660e`, Jun 8 2026 |
| Fallout app paying-user data | `MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #6 (Chris email, May 5 2026), tabulated in `MODIPHIUS_DIGITAL_FORECAST.md` §5b-cal |
| Steam-only forecast scenarios | `MODIPHIUS_DIGITAL_FORECAST.md` §6b |
| Ecosystem audience 51,113 | `MODIPHIUS_DIGITAL_FORECAST.md` §5a |
| Mobile ARPU and 15% platform cut | `MODIPHIUS_DIGITAL_FORECAST.md` §6c, §6c.1 |
| Six Ages 2 pricing precedent | `MODIPHIUS_DIGITAL_FORECAST.md` §6c.3 |
| 28 art tags | `data/narrative/atmosphere_openers.json` → `art_tag_to_category` |
| 421 scene paintings, 87% widescreen, 248 untagged | `docs/assets/modiphius_art_inventory.csv` (737 rows), `docs/assets/MODIPHIUS_ART_REFERENCE.md` |
| 87 PSDs, ~28 scene-usable, 4 built | Same CSV, filtered on `ext = psd`; built scenes in `assets/scenes/*/` |
| 55% illustration frame, aspect handling | `src/ui/screens/narrative/NarrativeScreen.gd:59`, `src/ui/screens/narrative/SceneStage.gd:179` |
| Feedback widget still unbuilt | `src/ui/components/feedback/` contains only `ValidationPanel.gd` (form validation, Dec 2025); no caller of `addons/talo/apis/feedback_api.gd` in `src/` |
| Build health, on-device testing | `docs/QA_STATUS_DASHBOARD.md` (Jul 6 2026), git log Jul 10 to 11 |
| Stop Killing Games, Sony digital-only, ERA quote | [Stop Killing Games (Wikipedia)](https://en.wikipedia.org/wiki/Stop_Killing_Games), [Above the Law, Jul 2026](https://abovethelaw.com/2026/07/the-end-of-physical-playstation-games-ownership-licenses-and-the-digital-backlash/), [Gadget Review](https://www.gadgetreview.com/backlash-to-playstation-killing-discs-intensifies-a-triumph-of-corporate-convenience-over-consumer-choice) |
| Fallout companion app subscription structure | [Modiphius blog: What Makes the Companion App tick](https://www.modiphius.net/blogs/news/fallout-wasteland-warfare-the-companion-app) |
