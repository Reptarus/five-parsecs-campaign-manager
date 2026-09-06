extends RefCounted
## Small, shared value-to-text conversions for player-facing surfaces.
##
## Every function here exists because the SAME defect was found on more than one
## screen during the deploy #19 tablet walk, and fixing it per-screen is how three
## copies of the species-name logic came to disagree (T11-31).
##
## Nothing here invents or interprets game data — these are presentation-only
## transforms on values the owning system already produced.

## Print a number the way a player writes it.
##
## T11-33/T11-34. Godot's JSON parser returns EVERY number as a float, so a value
## that was written as `35` comes back as `35.0` and `str()` prints "35.0". The
## device walk found this on the ship hull readout ("30.0 / 35.0") and in the
## journal's Details block. Fractional values are rare but legal (a 2.5 ft table
## size), so they must survive rather than being rounded away.
static func number(value: Variant) -> String:
	if value is int:
		return str(value)
	if value is float:
		var f: float = value
		if is_equal_approx(f, roundf(f)):
			return str(int(roundf(f)))
		return str(f)
	return str(value)


## Turn a snake_case identifier into the book's Title Case.
##
## T11-30. The Encounter Log printed `interested_parties` verbatim. The pp.94-103
## encounter categories are Title Case in the book ("Interested Parties", "Roving
## Threats", "Criminal Elements", "Hired Muscle"), unlike the p.89 Notable Sights,
## which stay in sentence case and therefore keep their own `_sight_label`.
##
## ⚠ `capitalize()` is given the RAW token on purpose. Replacing the underscores
## first and passing "interested parties" returns "Interested pParties", because
## capitalize() also inserts a space before each interior capital it produces.
## Observed, not theorised — the same trap documented on SheetDataContext.
static func title_case(token: String) -> String:
	var raw: String = token.strip_edges()
	if raw.is_empty():
		return ""
	# A value that already carries a capital came from a data file that owns its
	# own spelling - a name, not an identifier - and is handed back UNTOUCHED.
	# Reformatting such a value is how "Genetic Uplift" became "GeneticUplift"
	# elsewhere, and capitalize() mangles "K'Erin" outright. Storage ids in this
	# project are lower_snake_case without exception, so "has an uppercase
	# letter" cleanly separates the two.
	if raw != raw.to_lower():
		return raw
	return raw.capitalize()


## Turn a SCREAMING_SNAKE identifier into the book's sentence case.
##
## T11-34. The p.89 Notable Sights are stored as `DOCUMENTATION` / `SHINY_BITS` /
## `PERSON_OF_INTEREST` (data/mission_tables/reward_items.json) and the book prints
## them in SENTENCE case, not Title Case — which is why `title_case()` above is the
## wrong transform for them and why they were given their own label on the sheet.
## That sheet-local copy is now this function, so the two surfaces cannot drift.
##
## ⚠ `title_case()` deliberately hands back anything carrying a capital, to protect
## "K'Erin" and "Feral Jackals". An ALL-CAPS token is the one case that rule gets
## wrong: it is a storage identifier in the other spelling, not a name that owns
## its capitals. Mixed case still means "owns its spelling" and is untouched here.
static func sentence_case(token: String) -> String:
	var raw: String = token.strip_edges()
	if raw.is_empty():
		return ""
	var words: String = raw.to_lower().replace("_", " ").strip_edges()
	if words.is_empty():
		return ""
	return words.substr(0, 1).to_upper() + words.substr(1)


## Render one value out of a journal/stats block, where the caller iterates keys
## generically and cannot know which is a number, a storage id or a real name.
##
## T11-34. `CampaignJournalScreen`'s Details block sent EVERY value through
## `number()`, which returns a String unchanged — so the numbers were fixed and
## `Enemy category: interested_parties` / `Notable sight: DOCUMENTATION` kept
## printing raw next to them. The sheet had already been fixed, so two surfaces
## disagreed about whether a stored token is presentable.
##
## The rule follows this project's two storage spellings, which map onto the two
## display conventions the book uses:
##   lower_snake  -> Title Case   ("interested_parties" -> "Interested Parties")
##   UPPER_SNAKE  -> sentence     ("DOCUMENTATION"      -> "Documentation")
##   mixed case   -> untouched    ("Salvage Team", "K'Erin", "Gain 1 Quest Rumor.")
static func stat_value(value: Variant) -> String:
	if value is int or value is float:
		return number(value)
	if not (value is String):
		return number(value)
	var raw: String = (value as String).strip_edges()
	if raw.is_empty():
		return ""
	# ⚠ A value with NO cased letters is neither an identifier nor a name, and must
	# be handed back before either branch touches it: `capitalize()` inserts a
	# space before an interior digit run, so the panic range "1-3" comes out as
	# "1- 3" and the signed combat modifier "+0" is at the same risk. Caught by
	# this function's own "leaves alone" test rather than in the field.
	if raw.to_lower() == raw.to_upper():
		return raw
	# A token carrying no lowercase letter at all is an identifier in the other
	# storage spelling, not a name that owns its capitals.
	if raw == raw.to_upper():
		return sentence_case(raw)
	return title_case(raw)


## Join non-empty parts with a separator, dropping the blanks.
##
## Used where a line is assembled from optional facts and an absent one must not
## leave a dangling separator ("Gangers · · since turn 6").
static func join_parts(parts: Array, separator: String = " · ") -> String:
	var kept: Array = []
	for p in parts:
		var s: String = str(p).strip_edges()
		if not s.is_empty():
			kept.append(s)
	return separator.join(PackedStringArray(kept))


## "1 credit" / "2 credits" — T11-33, seen as "1 credits" on the ship screen.
static func pluralize(count: Variant, singular: String, plural: String = "") -> String:
	var n: String = number(count)
	var word: String = plural if not plural.is_empty() else singular + "s"
	return "%s %s" % [n, singular if n == "1" else word]
