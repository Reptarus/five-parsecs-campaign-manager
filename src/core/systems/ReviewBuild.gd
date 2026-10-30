## ReviewBuild - the ONE predicate for the Modiphius review build.
##
## A review build turns the Alpha-1 menu scope off (MainMenu.is_a1_build()) and
## grants every DLC pack in memory (DLCManager._apply_review_grants()), so a
## reviewer can reach all five modes and every Compendium chapter without a store.
## It is decided by the `review_build` custom feature tag, which is set ONLY on the
## two review presets in export_presets.cfg (fiveparsecs-review-android,
## five-parsecs-review-windows). With no tag, every caller behaves exactly as the
## Alpha-1 build always has.
##
## The reason lives here and not in project.godot: that file is GENERATED, and
## Godot strips every comment from it on each save and export.
##
## Testing it from the desk (verified against godot-docs
## tutorials/export/feature_tags):
##   * an export preset's custom feature tags are NOT applied when the project runs
##     from the editor -- not even for a Runnable preset -- so has_feature() is
##     false in every editor run and every gdUnit4 run;
##   * in a DEBUG build the user argument `--review-build` turns it on. User
##     arguments must follow a bare `--`:   godot --path . -- --review-build
##   * Debug > Customize Run Instances > Feature Tags (with Enable Multiple
##     Instances ticked) applies a tag to an editor run.
## The argument is ignored in a release build, so a shipped alpha cannot be talked
## into review mode from its command line.
##
## evaluate() holds the logic and is pure, so a test can drive every combination;
## is_active() only gathers the three real inputs.
extends RefCounted

const FEATURE_TAG := "review_build"
const DEBUG_ARG := "--review-build"


static func is_active() -> bool:
	return evaluate(OS.has_feature(FEATURE_TAG), OS.get_cmdline_user_args(), OS.is_debug_build())


static func evaluate(has_feature: bool, user_args: PackedStringArray, is_debug: bool) -> bool:
	if has_feature:
		return true
	return is_debug and DEBUG_ARG in user_args


## The QA tools (dashboard Scenarios jump, DiceManager "Force the next roll") open in
## a debug build, as they always have, and in a review build, so a reviewer can reach
## late-game states and rare table rows without hours of play. An Alpha-1 release
## build has neither input, so it still cannot reach them.
static func qa_tools_enabled() -> bool:
	return qa_tools_allowed(OS.is_debug_build(), is_active())


static func qa_tools_allowed(is_debug: bool, review_active: bool) -> bool:
	return is_debug or review_active
