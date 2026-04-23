SafariZoneHub_MapScriptHeader:
	def_scene_scripts

	def_callbacks

	def_warp_events
	warp_event 16, 27, SAFARI_ZONE_FUCHSIA_GATE, 1
	warp_event 17, 27, SAFARI_ZONE_FUCHSIA_GATE, 2
	warp_event 31, 12, SAFARI_ZONE_EAST, 1
	warp_event 31, 13, SAFARI_ZONE_EAST, 2
	warp_event  2, 12, SAFARI_ZONE_WEST, 5
	warp_event  2, 13, SAFARI_ZONE_WEST, 6
	warp_event 16,  2, SAFARI_ZONE_NORTH, 5
	warp_event 17,  2, SAFARI_ZONE_NORTH, 6
	warp_event 19, 21, SAFARI_ZONE_HUB_REST_HOUSE, 1

	def_coord_events
	coord_event 16, 26, -1, SafariGauntletDraftExitScript
	coord_event 17, 26, -1, SafariGauntletDraftExitScript

	def_bg_events
	bg_event 16, 24, BGEVENT_JUMPTEXT, SafariGauntletDraftFieldSignText
	bg_event 20, 22, BGEVENT_JUMPTEXT, SafariZoneHubRestHouseSignText

	def_object_events
	object_event 15, 25, SPRITE_OFFICER, SPRITEMOVEDATA_STANDING_RIGHT, 0, 0, -1, PAL_NPC_BLUE, OBJECTTYPE_SCRIPT, 0, SafariGauntletDraftGuideScript, -1
	object_event 16, 27, SPRITE_OFFICER, SPRITEMOVEDATA_STANDING_UP, 0, 0, -1, PAL_NPC_BLUE, OBJECTTYPE_SCRIPT, 0, SafariGauntletDraftExitScript, -1
	object_event 17, 27, SPRITE_OFFICER_F, SPRITEMOVEDATA_STANDING_UP, 0, 0, -1, PAL_NPC_BLUE, OBJECTTYPE_SCRIPT, 0, SafariGauntletDraftExitScript, -1

GenericTrainerBug_maniacKai:
	generictrainer BUG_MANIAC, KAI, EVENT_BEAT_BUG_MANIAC_KAI, Bug_maniacKaiSeenText, Bug_maniacKaiBeatenText

	text "Venonat is so"
	line "similar to"
	cont "Butterfree!"

	para "Their weight,"
	line "their eyes,"
	cont "their abilities…"

	para "Evolution is"
	line "weird sometimes."
	done

Bug_maniacKaiSeenText:
	text "My Venonat evolved"
	line "into a Venomoth?!"
	done

Bug_maniacKaiBeatenText:
	text "I thought it would"
	line "for sure evolve"
	cont "into Butterfree!"
	done

SafariGauntletDraftGuideScript:
	faceplayer
	opentext
	writetext SafariGauntletDraftGuideText
	waitbutton
	closetext
	end

SafariGauntletDraftExitScript:
	special Special_SafariGauntlet_CheckDraftComplete
	iftruefwd .FinishDraft
	opentext
	writetext SafariGauntletLeaveDraftText
	yesorno
	iffalse_jumpopenedtext SafariGauntletStayInFieldText
	special Special_SafariGauntlet_CheckMinParty
	iffalsefwd .TooFew
	closetext
	sjumpfwd .WarpBack

.TooFew
	special Special_SafariGauntlet_HasUsableBalls
	iffalsefwd .OutOfBalls
	jumpopenedtext SafariGauntletNeedMoreDraftText

.OutOfBalls
	writetext SafariGauntletOutOfBallsLossText
	waitbutton
	closetext
	special Special_SafariGauntlet_EndRunLoss
	warpfacing UP, BATTLE_FACTORY_1F, 12, 8
	end

.FinishDraft
	special Special_SafariGauntlet_CheckMinParty
	iffalsefwd .DraftEndedTooSmall
	opentext
	writetext SafariGauntletDraftDoneGateText
	waitbutton
	closetext

.WarpBack
	special Special_SafariGauntlet_FinishDraft
	warpfacing UP, BATTLE_FACTORY_1F, 12, 8
	end

.DraftEndedTooSmall
	opentext
	writetext SafariGauntletDraftEndedLossText
	waitbutton
	closetext
	special Special_SafariGauntlet_EndRunLoss
	warpfacing UP, BATTLE_FACTORY_1F, 12, 8
	end

SafariGauntletDraftFieldSignText:
	text "Safari Gauntlet"
	line "Draft Field"

	para "Steps left: "
	text_decimal wSafariTimeRemaining, 2, 3

	para "Center: common"
	line "draft picks."

	para "East and west:"
	line "stronger roles."

	para "North: rare"
	line "anchors."
	done

SafariZoneHubRestHouseSignText:
	text "Rest House"
	done

SafariGauntletDraftGuideText:
	text "Catch normally in"
	line "the grass or with"
	cont "your Super Rod."

	para "Your draft ends"
	line "when your party"
	cont "fills or your"
	cont "Balls or steps"
	cont "run out."

	para "Steps left: "
	text_decimal wSafariTimeRemaining, 2, 3

	para "You can leave from"
	line "the south gate."
	done

SafariGauntletLeaveDraftText:
	text "Leave the draft"
	line "field and start"
	cont "the ladder?"
	done

SafariGauntletStayInFieldText:
	text "Keep hunting."
	done

SafariGauntletNeedMoreDraftText:
	text "You need at least"
	line "four #mon."

	para "Catch more before"
	line "starting battles."
	done

SafariGauntletOutOfBallsLossText:
	text "No Balls remain,"
	line "and your team is"
	cont "too small."

	para "The run is marked"
	line "as a loss."
	done

SafariGauntletDraftEndedLossText:
	text "The draft ended,"
	line "but your team is"
	cont "too small."

	para "The run is marked"
	line "as a loss."
	done

SafariGauntletDraftDoneGateText:
	text "Draft complete."

	para "Return to the hub"
	line "and prepare for"
	cont "Round 1."
	done
