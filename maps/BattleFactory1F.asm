BattleFactory1F_MapScriptHeader:
	def_scene_scripts

	def_callbacks

	def_warp_events

	def_coord_events

	def_bg_events
	bg_event 12,  7, BGEVENT_UP, SafariGauntletReceptionistScript
	bg_event 13,  7, BGEVENT_UP, SafariGauntletReceptionistScript
	bg_event 14,  5, BGEVENT_READ, BattleFactory1FRulesScript
	bg_event 10,  5, BGEVENT_JUMPTEXT, SafariGauntletRecordsText
	bg_event 25,  6, BGEVENT_JUMPTEXT, SafariGauntletKeepBoxText

	def_object_events
	object_event 12,  5, SPRITE_SCIENTIST, SPRITEMOVEDATA_STANDING_DOWN, 0, 0, -1, 0, OBJECTTYPE_SCRIPT, 0, SafariGauntletReceptionistScript, -1
	object_event 10,  7, SPRITE_SCIENTIST, SPRITEMOVEDATA_STANDING_UP, 0, 0, -1, PAL_NPC_BLUE, OBJECTTYPE_SCRIPT, 0, SafariGauntletSettingsScript, -1
	pc_nurse_event  6,  6
	object_event 12, 10, SPRITE_CLERK, SPRITEMOVEDATA_STANDING_UP, 0, 0, -1, PAL_NPC_BLUE, OBJECTTYPE_COMMAND, jumptextfaceplayer, SafariGauntletExitBlockedText, -1
	object_event 13, 10, SPRITE_CLERK, SPRITEMOVEDATA_STANDING_UP, 0, 0, -1, PAL_NPC_GREEN, OBJECTTYPE_COMMAND, jumptextfaceplayer, SafariGauntletExitBlockedText, -1
	object_event 11, 11, SPRITE_CLERK, SPRITEMOVEDATA_STANDING_UP, 0, 0, -1, PAL_NPC_RED, OBJECTTYPE_COMMAND, jumptextfaceplayer, SafariGauntletExitBlockedText, -1
	object_event 14, 11, SPRITE_CLERK, SPRITEMOVEDATA_STANDING_UP, 0, 0, -1, PAL_NPC_BLUE, OBJECTTYPE_COMMAND, jumptextfaceplayer, SafariGauntletExitBlockedText, -1
	object_event 18,  6, SPRITE_CLERK, SPRITEMOVEDATA_STANDING_DOWN, 0, 0, -1, PAL_NPC_RED, OBJECTTYPE_COMMAND, pokemart, MARTTYPE_BP, MART_BATTLEFACTORY_1, -1
	object_event 20,  6, SPRITE_CLERK, SPRITEMOVEDATA_STANDING_DOWN, 0, 0, -1, PAL_NPC_GREEN, OBJECTTYPE_COMMAND, pokemart, MARTTYPE_BP, MART_BATTLEFACTORY_2, -1
	object_event 22,  6, SPRITE_CLERK, SPRITEMOVEDATA_STANDING_DOWN, 0, 0, -1, PAL_NPC_BLUE, OBJECTTYPE_COMMAND, pokemart, MARTTYPE_BP, MART_BATTLEFACTORY_3, -1

	object_const_def
	const BATTLEFACTORY1F_RECEPTIONIST

BattleFactory1FRulesScript:
	jumpthistext
		text "Safari Gauntlet"
		line "rules:"

		para "Start with the"
		line "counter guide."

		para "Draft Lv.30"
		line "#mon in normal"
		cont "wild battles."

		para "You may catch up"
		line "to six #mon."

		para "The field has a"
		line "500-step limit."

		para "Common #mon are"
		line "near the start,"
		cont "rarer ones live"
		cont "deeper inside."

		para "Then fight four"
		line "trainers and a"
		cont "Gym Leader."

		para "Win to keep one"
		line "#mon in the"
		cont "Keep Box."
		done

BattleFactory1FStreakText:
	text "Streak: "
	text_decimal wBattleFactoryCurStreak, 2, 5
	text " wins"
	line "Record: "
	text_decimal wBattleFactoryTopStreak, 2, 5
	text " wins"
	cont "Swaps this run: "
	text_decimal wBattleFactorySwapCount, 1, 2
	done

SafariGauntletCounterStartScript:
	applyonemovement PLAYER, turn_head_up
	sjumpfwd SafariGauntletReceptionistScript

SafariGauntletReceptionistScript:
	readmem wSafariGauntletStep
	ifequal SAFARI_GAUNTLET_STEP_DRAFT, .ReturnToDraft
	ifequal SAFARI_GAUNTLET_STEP_ROUND1, .Round1Ready
	ifequal SAFARI_GAUNTLET_STEP_ROUND2, .Round2Ready
	ifequal SAFARI_GAUNTLET_STEP_ROUND3, .Round3Ready
	ifequal SAFARI_GAUNTLET_STEP_ROUND4, .Round4Ready
	ifequal SAFARI_GAUNTLET_STEP_BOSS, .BossReady
	opentext
	writetext SafariGauntletIntroText
	yesorno
	iffalse_jumpopenedtext SafariGauntletMaybeLaterText
	writetext SafariGauntletSaveText
	waitbutton
	special Special_SafariGauntlet_BeginRun
	random 4
	writemem wSafariGauntletBoss
	special Special_SafariGauntlet_GetDifficulty
	ifequalfwd SAFARI_GAUNTLET_DIFFICULTY_CASUAL, .CasualSupplies
	ifequalfwd SAFARI_GAUNTLET_DIFFICULTY_HARD, .HardSupplies
	givekeyitem SUPER_ROD
	giveitem MASTER_BALL, 1
	giveitem POKE_BALL, 20
	giveitem GREAT_BALL, 15
	giveitem ULTRA_BALL, 10
	giveitem SUPER_POTION, 5
	giveitem HYPER_POTION, 3
	giveitem FULL_HEAL, 2
	giveitem REVIVE, 1
	giveitem RARE_CANDY, 10
	giveitem THUNDERSTONE, 1
	giveitem FIRE_STONE, 1
	giveitem WATER_STONE, 1
	giveitem LEAF_STONE, 1
	giveitem ICE_STONE, 1
	writetext SafariGauntletStandardSuppliesText
	sjumpfwd .AfterSupplies

.CasualSupplies
	givekeyitem SUPER_ROD
	giveitem MASTER_BALL, 1
	giveitem POKE_BALL, 25
	giveitem GREAT_BALL, 20
	giveitem ULTRA_BALL, 15
	giveitem SUPER_POTION, 7
	giveitem HYPER_POTION, 5
	giveitem FULL_HEAL, 4
	giveitem REVIVE, 2
	giveitem RARE_CANDY, 10
	giveitem THUNDERSTONE, 1
	giveitem FIRE_STONE, 1
	giveitem WATER_STONE, 1
	giveitem LEAF_STONE, 1
	giveitem ICE_STONE, 1
	writetext SafariGauntletCasualSuppliesText
	sjumpfwd .AfterSupplies

.HardSupplies
	givekeyitem SUPER_ROD
	giveitem MASTER_BALL, 1
	giveitem POKE_BALL, 15
	giveitem GREAT_BALL, 12
	giveitem ULTRA_BALL, 8
	giveitem SUPER_POTION, 3
	giveitem HYPER_POTION, 2
	giveitem FULL_HEAL, 1
	giveitem RARE_CANDY, 6
	giveitem THUNDERSTONE, 1
	giveitem FIRE_STONE, 1
	giveitem WATER_STONE, 1
	giveitem LEAF_STONE, 1
	giveitem ICE_STONE, 1
	writetext SafariGauntletHardSuppliesText

.AfterSupplies
	waitbutton
	special Special_SafariGauntlet_GetBossReveal
	iffalsefwd .BossHidden
	readmem wSafariGauntletBoss
	ifequalfwd SAFARI_GAUNTLET_BOSS_CHUCK, .RevealChuck
	ifequalfwd SAFARI_GAUNTLET_BOSS_JASMINE, .RevealJasmine
	ifequalfwd SAFARI_GAUNTLET_BOSS_PRYCE, .RevealPryce
	writetext SafariGauntletRevealClairText
	sjumpfwd .StartDraft

.RevealChuck
	writetext SafariGauntletRevealChuckText
	sjumpfwd .StartDraft

.RevealJasmine
	writetext SafariGauntletRevealJasmineText
	sjumpfwd .StartDraft

.RevealPryce
	writetext SafariGauntletRevealPryceText
	sjumpfwd .StartDraft

.BossHidden
	writetext SafariGauntletRevealHiddenText

.StartDraft
	writetext SafariGauntletDraftFieldText
	waitbutton
	closetext
	blackoutmod BATTLE_FACTORY_1F
	wildon
	warpfacing UP, SAFARI_ZONE_HUB, 16, 25
	end

.ReturnToDraft
	opentext
	writetext SafariGauntletReturnToDraftText
	waitbutton
	closetext
	blackoutmod BATTLE_FACTORY_1F
	wildon
	warpfacing UP, SAFARI_ZONE_HUB, 16, 25
	end

.Round1Ready
	opentext
	writetext SafariGauntletRound1ReadyText
	yesorno
	iffalse_jumpopenedtext SafariGauntletPrepLaterText
	closetext
	scall SafariGauntletRound1
	iftrue SafariGauntletDefeat
	loadmem wSafariGauntletStep, SAFARI_GAUNTLET_STEP_ROUND2
	jumptextfaceplayer SafariGauntletBetweenRoundsText

.Round2Ready
	opentext
	writetext SafariGauntletRound2ReadyText
	yesorno
	iffalse_jumpopenedtext SafariGauntletPrepLaterText
	closetext
	scall SafariGauntletRound2
	iftrue SafariGauntletDefeat
	loadmem wSafariGauntletStep, SAFARI_GAUNTLET_STEP_ROUND3
	jumptextfaceplayer SafariGauntletBetweenRoundsText

.Round3Ready
	opentext
	writetext SafariGauntletRound3ReadyText
	yesorno
	iffalse_jumpopenedtext SafariGauntletPrepLaterText
	closetext
	scall SafariGauntletRound3
	iftrue SafariGauntletDefeat
	loadmem wSafariGauntletStep, SAFARI_GAUNTLET_STEP_ROUND4
	jumptextfaceplayer SafariGauntletBetweenRoundsText

.Round4Ready
	opentext
	writetext SafariGauntletRound4ReadyText
	yesorno
	iffalse_jumpopenedtext SafariGauntletPrepLaterText
	closetext
	scall SafariGauntletRound4
	iftrue SafariGauntletDefeat
	loadmem wSafariGauntletStep, SAFARI_GAUNTLET_STEP_BOSS
	jumptextfaceplayer SafariGauntletBossUnlockedText

.BossReady
	opentext
	writetext SafariGauntletBossReadyText
	yesorno
	iffalse_jumpopenedtext SafariGauntletPrepLaterText
	special Special_SafariGauntlet_GetDifficulty
	ifequalfwd SAFARI_GAUNTLET_DIFFICULTY_HARD, .StartBoss
	writetext SafariGauntletBossHealText
	waitbutton
	closetext
	special HealParty
	special Special_SafariGauntlet_ClampPartyHP
	sjumpfwd .DoBoss

.StartBoss
	closetext

.DoBoss
	scall SafariGauntletBossBattle
	iftrue SafariGauntletDefeat
	sjump SafariGauntletVictory

SafariGauntletRound1:
	showtext SafariGauntletRound1Text
	winlosstext SafariGauntletTrainerWinText, SafariGauntletTrainerLossText
	random 3
	ifequalfwd 0, .Quentin
	ifequalfwd 1, .Todd4
	loadtrainer FISHER, RALPH4
	sjumpfwd .Battle

.Quentin
	loadtrainer CAMPER, QUENTIN
	sjumpfwd .Battle

.Todd4
	loadtrainer CAMPER, TODD4

.Battle
	loadvar VAR_BATTLETYPE, BATTLETYPE_CANLOSE
	startbattle
	iftruefwd .Lost
	reloadmapafterbattle
	special Special_SafariGauntlet_ClampPartyHP
	givebp SAFARI_GAUNTLET_ROUND_BP
	showtext SafariGauntletRoundBPText
	setval FALSE
	end

.Lost
	special Special_SafariGauntlet_EndRunLoss
	reloadmapafterbattle
	setval TRUE
	end

SafariGauntletRound2:
	showtext SafariGauntletRound2Text
	winlosstext SafariGauntletTrainerWinText, SafariGauntletTrainerLossText
	random 3
	ifequalfwd 0, .Tully2
	ifequalfwd 1, .Wilton1
	loadtrainer PSYCHIC_T, PHIL
	sjumpfwd .Battle

.Tully2
	loadtrainer FISHER, TULLY2
	sjumpfwd .Battle

.Wilton1
	loadtrainer FISHER, WILTON1

.Battle
	loadvar VAR_BATTLETYPE, BATTLETYPE_CANLOSE
	startbattle
	iftruefwd .Lost
	reloadmapafterbattle
	special Special_SafariGauntlet_ClampPartyHP
	givebp SAFARI_GAUNTLET_ROUND_BP
	showtext SafariGauntletRoundBPText
	setval FALSE
	end

.Lost
	special Special_SafariGauntlet_EndRunLoss
	reloadmapafterbattle
	setval TRUE
	end

SafariGauntletRound3:
	showtext SafariGauntletRound3Text
	winlosstext SafariGauntletTrainerWinText, SafariGauntletTrainerLossText
	random 3
	ifequalfwd 0, .Gilbert
	ifequalfwd 1, .Nozomi
	loadtrainer FISHER, WILTON2
	sjumpfwd .Battle

.Gilbert
	loadtrainer PSYCHIC_T, GILBERT
	sjumpfwd .Battle

.Nozomi
	loadtrainer BATTLE_GIRL, NOZOMI

.Battle
	loadvar VAR_BATTLETYPE, BATTLETYPE_CANLOSE
	startbattle
	iftruefwd .Lost
	reloadmapafterbattle
	special Special_SafariGauntlet_ClampPartyHP
	givebp SAFARI_GAUNTLET_ROUND_BP
	showtext SafariGauntletRoundBPText
	setval FALSE
	end

.Lost
	special Special_SafariGauntlet_EndRunLoss
	reloadmapafterbattle
	setval TRUE
	end

SafariGauntletRound4:
	showtext SafariGauntletRound4Text
	winlosstext SafariGauntletTrainerWinText, SafariGauntletTrainerLossText
	random 3
	ifequalfwd 0, .Ronda
	ifequalfwd 1, .Wilton3
	loadtrainer FISHER, TULLY3
	sjumpfwd .Battle

.Ronda
	loadtrainer BATTLE_GIRL, RONDA
	sjumpfwd .Battle

.Wilton3
	loadtrainer FISHER, WILTON3

.Battle
	loadvar VAR_BATTLETYPE, BATTLETYPE_CANLOSE
	startbattle
	iftruefwd .Lost
	reloadmapafterbattle
	special Special_SafariGauntlet_ClampPartyHP
	givebp SAFARI_GAUNTLET_ROUND_BP
	showtext SafariGauntletRoundBPText
	setval FALSE
	end

.Lost
	special Special_SafariGauntlet_EndRunLoss
	reloadmapafterbattle
	setval TRUE
	end

SafariGauntletBossBattle:
	readmem wSafariGauntletBoss
	ifequalfwd SAFARI_GAUNTLET_BOSS_CHUCK, .Chuck
	ifequalfwd SAFARI_GAUNTLET_BOSS_JASMINE, .Jasmine
	ifequalfwd SAFARI_GAUNTLET_BOSS_PRYCE, .Pryce
	winlosstext SafariGauntletBossWinText, SafariGauntletBossLossText
	loadtrainer CLAIR, 1
	sjumpfwd .Battle

.Chuck
	winlosstext SafariGauntletBossWinText, SafariGauntletBossLossText
	loadtrainer CHUCK, 1
	sjumpfwd .Battle

.Jasmine
	winlosstext SafariGauntletBossWinText, SafariGauntletBossLossText
	loadtrainer JASMINE, 1
	sjumpfwd .Battle

.Pryce
	winlosstext SafariGauntletBossWinText, SafariGauntletBossLossText
	loadtrainer PRYCE, 1

.Battle
	loadvar VAR_BATTLETYPE, BATTLETYPE_CANLOSE
	startbattle
	iftruefwd .Lost
	reloadmapafterbattle
	special Special_SafariGauntlet_ClampPartyHP
	givebp SAFARI_GAUNTLET_BOSS_BP
	showtext SafariGauntletBossBPText
	setval FALSE
	end

.Lost
	special Special_SafariGauntlet_EndRunLoss
	reloadmapafterbattle
	setval TRUE
	end

SafariGauntletDraftFailed:
	special Special_SafariGauntlet_EndRunLoss
	jumptextfaceplayer SafariGauntletDraftFailedText

SafariGauntletDefeat:
	jumptextfaceplayer SafariGauntletDefeatText

SafariGauntletVictory:
	opentext
	writetext SafariGauntletVictoryText
	waitbutton
	writetext SafariGauntletKeepPromptText
	waitbutton
	closetext
	special Special_SafariGauntlet_ChooseKeepMon
	special Special_SafariGauntlet_EndRunWin
	jumptextfaceplayer SafariGauntletReturnedText

SafariGauntletSettingsScript:
	faceplayer
	opentext
	writetext SafariGauntletSettingsHeaderText
	promptbutton
	special Special_SafariGauntlet_GetDexMode
	iftruefwd .National
	writetext SafariGauntletSettingsJohtoText
	sjumpfwd .AskToggle

.National
	writetext SafariGauntletSettingsNationalText
.AskToggle
	yesorno
	iffalsefwd .CarryIn
	special Special_SafariGauntlet_ToggleDexMode
	iftruefwd .SetNational
	writetext SafariGauntletSetJohtoText
	sjumpfwd .AfterDex

.SetNational
	writetext SafariGauntletSetNationalText
.AfterDex
	promptbutton

.CarryIn
	special Special_SafariGauntlet_GetCarryIn
	iftruefwd .CarryEnabled
	writetext SafariGauntletCarryOffText
	sjumpfwd .AskCarry

.CarryEnabled
	writetext SafariGauntletCarryOnText
.AskCarry
	yesorno
	iffalsefwd .BossReveal
	special Special_SafariGauntlet_ToggleCarryIn
	iftruefwd .CarryNowOn
	writetext SafariGauntletCarrySetOffText
	sjumpfwd .AfterCarry

.CarryNowOn
	writetext SafariGauntletCarrySetOnText
.AfterCarry
	promptbutton

.BossReveal
	special Special_SafariGauntlet_GetBossReveal
	iftruefwd .RevealEnabled
	writetext SafariGauntletBossRevealOffText
	sjumpfwd .AskReveal

.RevealEnabled
	writetext SafariGauntletBossRevealOnText
.AskReveal
	yesorno
	iffalsefwd .Difficulty
	special Special_SafariGauntlet_ToggleBossReveal
	iftruefwd .RevealNowOn
	writetext SafariGauntletBossRevealSetOffText
	sjumpfwd .AfterReveal

.RevealNowOn
	writetext SafariGauntletBossRevealSetOnText
.AfterReveal
	promptbutton

.Difficulty
	special Special_SafariGauntlet_GetDifficulty
	ifequalfwd SAFARI_GAUNTLET_DIFFICULTY_CASUAL, .DifficultyCasual
	ifequalfwd SAFARI_GAUNTLET_DIFFICULTY_HARD, .DifficultyHard
	writetext SafariGauntletDifficultyStandardText
	sjumpfwd .AskDifficulty

.DifficultyCasual
	writetext SafariGauntletDifficultyCasualText
	sjumpfwd .AskDifficulty

.DifficultyHard
	writetext SafariGauntletDifficultyHardText
.AskDifficulty
	yesorno
	iffalsefwd .SaveSettings
	special Special_SafariGauntlet_CycleDifficulty
	ifequalfwd SAFARI_GAUNTLET_DIFFICULTY_CASUAL, .DifficultySetCasual
	ifequalfwd SAFARI_GAUNTLET_DIFFICULTY_HARD, .DifficultySetHard
	writetext SafariGauntletDifficultySetStandardText
	sjumpfwd .Done

.DifficultySetCasual
	writetext SafariGauntletDifficultySetCasualText
	sjumpfwd .Done

.DifficultySetHard
	writetext SafariGauntletDifficultySetHardText
.Done
	promptbutton
	sjumpfwd .SaveSettings

.SaveSettings
	special Special_SafariGauntlet_SaveSettings
	jumpopenedtext SafariGauntletSettingsSavedText

SafariGauntletRecordsText:
	text "Safari Gauntlet"
	line "Runs: "
	text_decimal wSafariGauntletRuns, 2, 5
	text " Wins: "
	text_decimal wSafariGauntletWins, 2, 5

	para "Losses: "
	text_decimal wSafariGauntletLosses, 2, 5
	line "Streak: "
	text_decimal wSafariGauntletCurrentStreak, 1, 3
	text " Best: "
	text_decimal wSafariGauntletBestStreak, 1, 3

	para "BP: "
	text_decimal wBattlePoints, 2, 5
	done

SafariGauntletKeepBoxText:
	text "Safari Keep Box"
	line "Stored: "
	text_decimal wSafariGauntletKeepCount, 1, 2
	text "/30 #mon"

	para "Win the gauntlet"
	line "to keep one."

	para "Spend BP at the"
	line "exchange counters"
	cont "for your team."
	done

SafariGauntletExitBlockedText:
	text "The Safari"
	line "Gauntlet is"
	cont "self-contained."

	para "Please stay inside"
	line "between runs."
	done

SafariGauntletIntroText:
	text "Safari Gauntlet!"

	para "Catch a Lv.30"
	line "draft team, then"
	cont "clear five battles."

	para "Win, and one"
	line "#mon joins your"
	cont "Keep Box."

	para "Begin a run?"
	done

SafariGauntletSaveText:
	text "I'll save first."

	para "Your party and bag"
	line "come back after"
	cont "the run."

	para "One moment."
	done

SafariGauntletMaybeLaterText:
	text "The Gauntlet will"
	line "be here."
	done

SafariGauntletStandardSuppliesText:
	text "Run supplies are"
	line "loaded."

	para "You have a Master"
	line "Ball, plenty of"
	cont "other Balls,"
	cont "healing items,"
	cont "ten Candies,"
	cont "Eevee stones,"
	cont "and a Super Rod."
	prompt

SafariGauntletCasualSuppliesText:
	text "Casual supplies"
	line "are loaded."

	para "You have a Master"
	line "Ball, extra"
	cont "Balls and healing,"
	cont "ten Candies,"
	cont "Eevee stones,"
	cont "and a Super Rod."
	prompt

SafariGauntletHardSuppliesText:
	text "Hard supplies are"
	line "loaded."

	para "You still get one"
	line "Master Ball, but"
	cont "fewer supplies"
	cont "six Candies,"
	cont "Eevee stones,"
	cont "and a Super Rod."
	prompt

SafariGauntletRevealChuckText:
	text "Boss reveal:"
	line "Chuck waits at"
	cont "the finish."
	prompt

SafariGauntletRevealJasmineText:
	text "Boss reveal:"
	line "Jasmine waits at"
	cont "the finish."
	prompt

SafariGauntletRevealPryceText:
	text "Boss reveal:"
	line "Pryce waits at"
	cont "the finish."
	prompt

SafariGauntletRevealClairText:
	text "Boss reveal:"
	line "Clair waits at"
	cont "the finish."
	prompt

SafariGauntletRevealHiddenText:
	text "Boss reveal is"
	line "hidden this run."
	prompt

SafariGauntletDraftFieldText:
	text "Enter the Safari"
	line "draft field."

	para "You have 500"
	line "field steps."

	para "Battle and catch"
	line "#mon normally."

	para "The draft ends"
	line "when your party"
	cont "fills or your"
	cont "Balls or steps"
	cont "run out."
	prompt

SafariGauntletReturnToDraftText:
	text "Your draft is"
	line "still open."

	para "I'll send you back"
	line "to the field."
	done

SafariGauntletDraftEncounterText:
	text "A draft encounter"
	line "appears!"
	done

SafariGauntletPrepText:
	text "Draft complete."

	para "Use your bag now,"
	line "then the ladder"
	cont "begins."
	done

SafariGauntletRound1ReadyText:
	text "Round 1 is ready."

	para "Heal, use items,"
	line "or rearrange your"
	cont "party first."

	para "Start the match?"
	done

SafariGauntletRound2ReadyText:
	text "Round 2 is ready."

	para "You may heal or"
	line "reorder before"
	cont "continuing."

	para "Start the match?"
	done

SafariGauntletRound3ReadyText:
	text "Round 3 is ready."

	para "Take your time in"
	line "the hub."

	para "Start the match?"
	done

SafariGauntletRound4ReadyText:
	text "Round 4 is ready."

	para "Use your supplies"
	line "before entering."

	para "Start the match?"
	done

SafariGauntletBossReadyText:
	text "The Gym Leader is"
	line "waiting."

	para "This is the final"
	line "battle."

	para "Enter?"
	done

SafariGauntletPrepLaterText:
	text "Prepare as long as"
	line "you need."
	done

SafariGauntletBetweenRoundsText:
	text "Round cleared."

	para "Heal, switch your"
	line "lead, or use items"
	cont "before the next"
	cont "match."
	done

SafariGauntletBossUnlockedText:
	text "The ladder is"
	line "clear."

	para "Prepare for the"
	line "Gym Leader, then"
	cont "talk to me."
	done

SafariGauntletRound1Text:
	text "Round 1:"
	line "Camper Quentin!"
	done

SafariGauntletRound2Text:
	text "Round 2:"
	line "Fisher Tully!"
	done

SafariGauntletRound3Text:
	text "Round 3:"
	line "Psychic Gilbert!"
	done

SafariGauntletRound4Text:
	text "Round 4:"
	line "Battle Girl Ronda!"
	done

SafariGauntletBossHealText:
	text "Final gate."

	para "Your team is fully"
	line "healed before the"
	cont "Gym Leader."
	done

SafariGauntletRoundBPText:
	text "<PLAYER> earned"
	line "2 BP!"
	done

SafariGauntletBossBPText:
	text "<PLAYER> earned"
	line "10 BP from the"
	cont "Gym Leader!"
	done

SafariGauntletTrainerWinText:
	text "Round cleared!"
	done

SafariGauntletTrainerLossText:
	text "The run ends here!"
	done

SafariGauntletBossWinText:
	text "Boss defeated!"
	done

SafariGauntletBossLossText:
	text "The boss ends"
	line "your run!"
	done

SafariGauntletDraftFailedText:
	text "You need at least"
	line "four #mon to"
	cont "enter the ladder."

	para "Run marked as a"
	line "loss."
	done

SafariGauntletDefeatText:
	text "Safari Gauntlet"
	line "run failed."

	para "Your party and bag"
	line "were restored."
	done

SafariGauntletVictoryText:
	text "Safari Gauntlet"
	line "cleared!"

	para "Choose one #mon"
	line "from this team to"
	cont "keep."
	prompt

SafariGauntletKeepPromptText:
	text "Pick carefully."
	line "It can carry into"
	cont "future runs."
	prompt

SafariGauntletReturnedText:
	text "Record saved."

	para "Your original"
	line "party and bag are"
	cont "back."
	done

SafariGauntletSettingsJohtoText:
	text "Mode: Johto."

	para "Any Johto #mon"
	line "can appear in"
	cont "the draft."

	para "Switch to National"
	line "draft encounters?"
	done

SafariGauntletSettingsHeaderText:
	text "Safari Gauntlet"
	line "settings."

	para "Changes are saved."
	done

SafariGauntletSettingsNationalText:
	text "Mode: National."

	para "Any National"
	line "#mon can"
	cont "appear in draft."

	para "Switch to Johto"
	line "draft encounters?"
	done

SafariGauntletSettingsUnchangedText:
	text "Settings unchanged."
	done

SafariGauntletSetNationalText:
	text "National draft"
	line "mode selected."
	done

SafariGauntletSetJohtoText:
	text "Johto draft mode"
	line "selected."
	done

SafariGauntletCarryOnText:
	text "Carry-in: On."

	para "Toggle carry-in?"
	done

SafariGauntletCarryOffText:
	text "Carry-in: Off."

	para "Toggle carry-in?"
	done

SafariGauntletCarrySetOnText:
	text "Carry-in #mon"
	line "enabled."
	done

SafariGauntletCarrySetOffText:
	text "Carry-in #mon"
	line "disabled."
	done

SafariGauntletBossRevealOnText:
	text "Boss reveal: On."

	para "Toggle reveal?"
	done

SafariGauntletBossRevealOffText:
	text "Boss reveal: Off."

	para "Toggle reveal?"
	done

SafariGauntletBossRevealSetOnText:
	text "Boss reveal"
	line "enabled."
	done

SafariGauntletBossRevealSetOffText:
	text "Boss reveal"
	line "disabled."
	done

SafariGauntletDifficultyStandardText:
	text "Difficulty:"
	line "Standard."

	para "Change difficulty?"
	done

SafariGauntletDifficultyCasualText:
	text "Difficulty:"
	line "Casual."

	para "Change difficulty?"
	done

SafariGauntletDifficultyHardText:
	text "Difficulty:"
	line "Hard."

	para "Change difficulty?"
	done

SafariGauntletDifficultySetStandardText:
	text "Difficulty set"
	line "to Standard."
	done

SafariGauntletDifficultySetCasualText:
	text "Difficulty set"
	line "to Casual."
	done

SafariGauntletDifficultySetHardText:
	text "Difficulty set"
	line "to Hard."
	done

SafariGauntletSettingsSavedText:
	text "Settings saved."
	done

BattleFactory1FReceptionistScript:
	jumptextfaceplayer SafariGauntletGuideText

SafariGauntletGuideText:
	text "This is the"
	line "Safari Gauntlet."

	para "Talk to the"
	line "counter guide"
	cont "to start."

	para "Settings are"
	line "changed by the"
	cont "blue aide."

	para "They stay saved"
	line "for future runs."
	done
