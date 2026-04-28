BattleFactory1F_MapScriptHeader:
	def_scene_scripts

	def_callbacks
	callback MAPCALLBACK_NEWMAP, SafariGauntletHubLoadCallback

	def_warp_events

	def_coord_events

	def_bg_events
	bg_event 12,  7, BGEVENT_UP, SafariGauntletReceptionistScript
	bg_event 13,  7, BGEVENT_UP, SafariGauntletReceptionistScript
	bg_event 14,  5, BGEVENT_READ, BattleFactory1FRulesScript
	bg_event 10,  5, BGEVENT_JUMPTEXT, SafariGauntletRecordsText
	bg_event  4,  6, BGEVENT_READ, SafariGauntletKeepBoxScript
	bg_event  5,  6, BGEVENT_READ, SafariGauntletKeepBoxScript
	bg_event  4,  7, BGEVENT_UP, SafariGauntletKeepBoxScript
	bg_event  5,  7, BGEVENT_UP, SafariGauntletKeepBoxScript
	bg_event  8,  6, BGEVENT_READ, SafariGauntletKeepBoxScript
	bg_event  9,  6, BGEVENT_READ, SafariGauntletKeepBoxScript
	bg_event  8,  7, BGEVENT_UP, SafariGauntletKeepBoxScript
	bg_event  9,  7, BGEVENT_UP, SafariGauntletKeepBoxScript
	bg_event  9, 11, BGEVENT_READ, SafariGauntletSettingsMenu
	bg_event 16, 11, BGEVENT_READ, SafariGauntletMoveReminderMenu
	bg_event 25,  6, BGEVENT_READ, SafariGauntletKeepBoxScript

	def_object_events
	object_event 12,  5, SPRITE_SCIENTIST, SPRITEMOVEDATA_STANDING_DOWN, 0, 0, -1, 0, OBJECTTYPE_SCRIPT, 0, SafariGauntletReceptionistScript, -1
	object_event  9, 11, SPRITE_SCIENTIST, SPRITEMOVEDATA_STANDING_DOWN, 0, 0, -1, PAL_NPC_BLUE, OBJECTTYPE_SCRIPT, 0, SafariGauntletSettingsScript, -1
	object_event 16, 10, SPRITE_GRAMPS, SPRITEMOVEDATA_STANDING_DOWN, 0, 0, -1, 0, OBJECTTYPE_SCRIPT, 0, SafariGauntletMoveReminderScript, -1
	object_event 24, 10, SPRITE_CLERK, SPRITEMOVEDATA_STANDING_DOWN, 0, 0, -1, PAL_NPC_BROWN, OBJECTTYPE_SCRIPT, 0, SafariGauntletTMVendorScript, -1
	object_event  6,  6, SPRITE_BOWING_NURSE, SPRITEMOVEDATA_STANDING_DOWN, 0, 0, -1, 0, OBJECTTYPE_SCRIPT, 0, SafariGauntletNurseScript, -1
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

		para "Draft Lv.50"
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
		cont "special boss."

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

SafariGauntletNurseScript:
	special Special_SafariGauntlet_EnsureHubParty
	jumpstd pokecenternurse

SafariGauntletHubLoadCallback:
	special Special_SafariGauntlet_EnsureHubParty
	endcallback

SafariGauntletReceptionistScript:
	special Special_SafariGauntlet_EnsureHubParty
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
	readvar VAR_PARTYCOUNT
	ifnotequal 1, .NeedOnePokemon
	writetext SafariGauntletSaveText
	waitbutton
	special Special_SafariGauntlet_BeginRun
	random SAFARI_GAUNTLET_BOSS_COUNT
	writemem wSafariGauntletBoss
	random SAFARI_GAUNTLET_TM_SHOP_SET_COUNT
	writemem wSafariGauntletTMShopSet
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
	giveitem SUPER_REPEL, 3
	giveitem REVIVE, 1
	giveitem RARE_CANDY, 12
	giveitem THUNDERSTONE, 1
	giveitem FIRE_STONE, 1
	giveitem WATER_STONE, 1
	giveitem LEAF_STONE, 1
	giveitem ICE_STONE, 1
	giveitem SUN_STONE, 1
	giveitem MOON_STONE, 1
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
	giveitem SUPER_REPEL, 3
	giveitem REVIVE, 2
	giveitem RARE_CANDY, 12
	giveitem THUNDERSTONE, 1
	giveitem FIRE_STONE, 1
	giveitem WATER_STONE, 1
	giveitem LEAF_STONE, 1
	giveitem ICE_STONE, 1
	giveitem SUN_STONE, 1
	giveitem MOON_STONE, 1
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
	giveitem SUPER_REPEL, 3
	giveitem RARE_CANDY, 12
	giveitem THUNDERSTONE, 1
	giveitem FIRE_STONE, 1
	giveitem WATER_STONE, 1
	giveitem LEAF_STONE, 1
	giveitem ICE_STONE, 1
	giveitem SUN_STONE, 1
	giveitem MOON_STONE, 1
	writetext SafariGauntletHardSuppliesText

.AfterSupplies
	waitbutton
	special Special_SafariGauntlet_GetBossReveal
	iffalsefwd .BossHidden
	scall SafariGauntletRevealBoss
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

.NeedOnePokemon
	jumpopenedtext SafariGauntletNeedOnePokemonText

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
	random 16
	ifequalfwd 0, .Joey1
	ifequalfwd 1, .Todd1
	ifequalfwd 2, .Gina1
	ifequalfwd 3, .Dana1
	ifequalfwd 4, .Jack1
	ifequalfwd 5, .Wade1
	ifequalfwd 6, .Jose1
	ifequalfwd 7, .Anthony1
	ifequalfwd 8, .Huey1
	ifequalfwd 9, .Stan
	ifequalfwd 10, .Brent1
	ifequalfwd 11, .Victoria
	ifequalfwd 12, .Derek1
	ifequalfwd 13, .Nathan
	ifequalfwd 14, .Otis
	loadtrainer BLACKBELT_T, KENJI1
	sjumpfwd .Battle

.Joey1
	loadtrainer YOUNGSTER, JOEY1
	sjumpfwd .Battle

.Todd1
	loadtrainer CAMPER, TODD1
	sjumpfwd .Battle

.Gina1
	loadtrainer PICNICKER, GINA1
	sjumpfwd .Battle

.Dana1
	loadtrainer LASS, DANA1
	sjumpfwd .Battle

.Jack1
	loadtrainer SCHOOLBOY, JACK1
	sjumpfwd .Battle

.Wade1
	loadtrainer BUG_CATCHER, WADE1
	sjumpfwd .Battle

.Jose1
	loadtrainer BIRD_KEEPER, JOSE1
	sjumpfwd .Battle

.Anthony1
	loadtrainer HIKER, ANTHONY1
	sjumpfwd .Battle

.Huey1
	loadtrainer SAILOR, HUEY1
	sjumpfwd .Battle

.Stan
	loadtrainer SUPER_NERD, STAN
	sjumpfwd .Battle

.Brent1
	loadtrainer POKEMANIAC, BRENT1
	sjumpfwd .Battle

.Victoria
	loadtrainer BEAUTY, VICTORIA
	sjumpfwd .Battle

.Derek1
	loadtrainer POKEFANM, DEREK1
	sjumpfwd .Battle

.Nathan
	loadtrainer PSYCHIC_T, NATHAN
	sjumpfwd .Battle

.Otis
	loadtrainer FIREBREATHER, OTIS

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
	random 16
	ifequalfwd 0, .Joey3
	ifequalfwd 1, .Todd3
	ifequalfwd 2, .Gina3
	ifequalfwd 3, .Liz3
	ifequalfwd 4, .Alan3
	ifequalfwd 5, .Vance1
	ifequalfwd 6, .Anthony3
	ifequalfwd 7, .Parry1
	ifequalfwd 8, .Phil
	ifequalfwd 9, .Huey2
	ifequalfwd 10, .Eric
	ifequalfwd 11, .Dennett
	ifequalfwd 12, .Yoshi
	ifequalfwd 13, .Subaru
	ifequalfwd 14, .Ned
	loadtrainer BOARDER, RONALD
	sjumpfwd .Battle

.Joey3
	loadtrainer YOUNGSTER, JOEY3
	sjumpfwd .Battle

.Todd3
	loadtrainer CAMPER, TODD3
	sjumpfwd .Battle

.Gina3
	loadtrainer PICNICKER, GINA3
	sjumpfwd .Battle

.Liz3
	loadtrainer PICNICKER, LIZ3
	sjumpfwd .Battle

.Alan3
	loadtrainer SCHOOLBOY, ALAN3
	sjumpfwd .Battle

.Anthony3
	loadtrainer HIKER, ANTHONY3
	sjumpfwd .Battle

.Parry1
	loadtrainer HIKER, PARRY1
	sjumpfwd .Battle

.Vance1
	loadtrainer BIRD_KEEPER, VANCE1
	sjumpfwd .Battle

.Phil
	loadtrainer PSYCHIC_T, PHIL
	sjumpfwd .Battle

.Huey2
	loadtrainer SAILOR, HUEY2
	sjumpfwd .Battle

.Eric
	loadtrainer SUPER_NERD, ERIC
	sjumpfwd .Battle

.Dennett
	loadtrainer SCIENTIST, DENNETT
	sjumpfwd .Battle

.Yoshi
	loadtrainer BLACKBELT_T, YOSHI
	sjumpfwd .Battle

.Subaru
	loadtrainer BATTLE_GIRL, SUBARU
	sjumpfwd .Battle

.Ned
	loadtrainer FIREBREATHER, NED

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
	random 16
	ifequalfwd 0, .Todd5
	ifequalfwd 1, .Gina4
	ifequalfwd 2, .Tiffany3
	ifequalfwd 3, .Anthony4
	ifequalfwd 4, .Parry2
	ifequalfwd 5, .Vance2
	ifequalfwd 6, .Gilbert
	ifequalfwd 7, .Nozomi
	ifequalfwd 8, .Kevin
	ifequalfwd 9, .Reena1
	ifequalfwd 10, .Huey3
	ifequalfwd 11, .Natalie
	ifequalfwd 12, .Dennett
	ifequalfwd 13, .Margaret
	ifequalfwd 14, .Winston
	loadtrainer BUG_MANIAC, LOU
	sjumpfwd .Battle

.Todd5
	loadtrainer CAMPER, TODD5
	sjumpfwd .Battle

.Gina4
	loadtrainer PICNICKER, GINA4
	sjumpfwd .Battle

.Tiffany3
	loadtrainer PICNICKER, TIFFANY3
	sjumpfwd .Battle

.Anthony4
	loadtrainer HIKER, ANTHONY4
	sjumpfwd .Battle

.Parry2
	loadtrainer HIKER, PARRY2
	sjumpfwd .Battle

.Vance2
	loadtrainer BIRD_KEEPER, VANCE2
	sjumpfwd .Battle

.Gilbert
	loadtrainer PSYCHIC_T, GILBERT
	sjumpfwd .Battle

.Nozomi
	loadtrainer BATTLE_GIRL, NOZOMI
	sjumpfwd .Battle

.Kevin
	loadtrainer COOLTRAINERM, KEVIN
	sjumpfwd .Battle

.Reena1
	loadtrainer COOLTRAINERF, REENA1
	sjumpfwd .Battle

.Huey3
	loadtrainer SAILOR, HUEY3
	sjumpfwd .Battle

.Natalie
	loadtrainer HEX_MANIAC, NATALIE
	sjumpfwd .Battle

.Dennett
	loadtrainer SCIENTIST, DENNETT
	sjumpfwd .Battle

.Margaret
	loadtrainer BAKER, MARGARET
	sjumpfwd .Battle

.Winston
	loadtrainer RICH_BOY, WINSTON

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
	random 12
	ifequalfwd 0, .Falkner
	ifequalfwd 1, .Bugsy
	ifequalfwd 2, .Whitney
	ifequalfwd 3, .Morty
	ifequalfwd 4, .Chuck
	ifequalfwd 5, .Jasmine
	ifequalfwd 6, .Pryce
	ifequalfwd 7, .Clair
	ifequalfwd 8, .Brock
	ifequalfwd 9, .Misty
	ifequalfwd 10, .Surge
	loadtrainer ERIKA, 1
	sjumpfwd .Battle

.Falkner
	loadtrainer FALKNER, 1
	sjumpfwd .Battle

.Bugsy
	loadtrainer BUGSY, 1
	sjumpfwd .Battle

.Whitney
	loadtrainer WHITNEY, 1
	sjumpfwd .Battle

.Morty
	loadtrainer MORTY, 1
	sjumpfwd .Battle

.Chuck
	loadtrainer CHUCK, 1
	sjumpfwd .Battle

.Jasmine
	loadtrainer JASMINE, 1
	sjumpfwd .Battle

.Pryce
	loadtrainer PRYCE, 1
	sjumpfwd .Battle

.Clair
	loadtrainer CLAIR, 1
	sjumpfwd .Battle

.Brock
	loadtrainer BROCK, 1
	sjumpfwd .Battle

.Misty
	loadtrainer MISTY, 1
	sjumpfwd .Battle

.Surge
	loadtrainer LT_SURGE, 1

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

SafariGauntletRevealBoss:
	readmem wSafariGauntletBoss
	ifequalfwd SAFARI_GAUNTLET_BOSS_FALKNER, .Falkner
	ifequalfwd SAFARI_GAUNTLET_BOSS_BUGSY, .Bugsy
	ifequalfwd SAFARI_GAUNTLET_BOSS_WHITNEY, .Whitney
	ifequalfwd SAFARI_GAUNTLET_BOSS_MORTY, .Morty
	ifequalfwd SAFARI_GAUNTLET_BOSS_CHUCK, .Chuck
	ifequalfwd SAFARI_GAUNTLET_BOSS_JASMINE, .Jasmine
	ifequalfwd SAFARI_GAUNTLET_BOSS_PRYCE, .Pryce
	ifequalfwd SAFARI_GAUNTLET_BOSS_CLAIR, .Clair
	ifequalfwd SAFARI_GAUNTLET_BOSS_BROCK, .Brock
	ifequalfwd SAFARI_GAUNTLET_BOSS_MISTY, .Misty
	ifequalfwd SAFARI_GAUNTLET_BOSS_LT_SURGE, .LtSurge
	ifequalfwd SAFARI_GAUNTLET_BOSS_ERIKA, .Erika
	ifequalfwd SAFARI_GAUNTLET_BOSS_JANINE, .Janine
	ifequalfwd SAFARI_GAUNTLET_BOSS_SABRINA, .Sabrina
	ifequalfwd SAFARI_GAUNTLET_BOSS_BLAINE, .Blaine
	ifequalfwd SAFARI_GAUNTLET_BOSS_BLUE, .Blue
	ifequalfwd SAFARI_GAUNTLET_BOSS_WILL, .Will
	ifequalfwd SAFARI_GAUNTLET_BOSS_KOGA, .Koga
	ifequalfwd SAFARI_GAUNTLET_BOSS_BRUNO, .Bruno
	ifequalfwd SAFARI_GAUNTLET_BOSS_KAREN, .Karen
	ifequalfwd SAFARI_GAUNTLET_BOSS_LANCE, .Lance
	gettrainername RED, 1, STRING_BUFFER_4
	sjumpfwd .Reveal

.Falkner
	gettrainername FALKNER, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Bugsy
	gettrainername BUGSY, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Whitney
	gettrainername WHITNEY, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Morty
	gettrainername MORTY, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Chuck
	gettrainername CHUCK, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Jasmine
	gettrainername JASMINE, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Pryce
	gettrainername PRYCE, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Clair
	gettrainername CLAIR, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Brock
	gettrainername BROCK, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Misty
	gettrainername MISTY, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.LtSurge
	gettrainername LT_SURGE, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Erika
	gettrainername ERIKA, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Janine
	gettrainername JANINE, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Sabrina
	gettrainername SABRINA, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Blaine
	gettrainername BLAINE, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Blue
	gettrainername BLUE, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Will
	gettrainername WILL, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Koga
	gettrainername KOGA, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Bruno
	gettrainername BRUNO, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Karen
	gettrainername KAREN, 2, STRING_BUFFER_4
	sjumpfwd .Reveal

.Lance
	gettrainername CHAMPION, LANCE2, STRING_BUFFER_4

.Reveal
	writetext SafariGauntletRevealBossText
	end

SafariGauntletBossBattle:
	readmem wSafariGauntletBoss
	winlosstext SafariGauntletBossWinText, SafariGauntletBossLossText
	ifequalfwd SAFARI_GAUNTLET_BOSS_FALKNER, .Falkner
	ifequalfwd SAFARI_GAUNTLET_BOSS_BUGSY, .Bugsy
	ifequalfwd SAFARI_GAUNTLET_BOSS_WHITNEY, .Whitney
	ifequalfwd SAFARI_GAUNTLET_BOSS_MORTY, .Morty
	ifequalfwd SAFARI_GAUNTLET_BOSS_CHUCK, .Chuck
	ifequalfwd SAFARI_GAUNTLET_BOSS_JASMINE, .Jasmine
	ifequalfwd SAFARI_GAUNTLET_BOSS_PRYCE, .Pryce
	ifequalfwd SAFARI_GAUNTLET_BOSS_CLAIR, .Clair
	ifequalfwd SAFARI_GAUNTLET_BOSS_BROCK, .Brock
	ifequalfwd SAFARI_GAUNTLET_BOSS_MISTY, .Misty
	ifequalfwd SAFARI_GAUNTLET_BOSS_LT_SURGE, .LtSurge
	ifequalfwd SAFARI_GAUNTLET_BOSS_ERIKA, .Erika
	ifequalfwd SAFARI_GAUNTLET_BOSS_JANINE, .Janine
	ifequalfwd SAFARI_GAUNTLET_BOSS_SABRINA, .Sabrina
	ifequalfwd SAFARI_GAUNTLET_BOSS_BLAINE, .Blaine
	ifequalfwd SAFARI_GAUNTLET_BOSS_BLUE, .Blue
	ifequalfwd SAFARI_GAUNTLET_BOSS_WILL, .Will
	ifequalfwd SAFARI_GAUNTLET_BOSS_KOGA, .Koga
	ifequalfwd SAFARI_GAUNTLET_BOSS_BRUNO, .Bruno
	ifequalfwd SAFARI_GAUNTLET_BOSS_KAREN, .Karen
	ifequalfwd SAFARI_GAUNTLET_BOSS_LANCE, .Lance
	loadtrainer RED, 1
	sjumpfwd .Battle

.Falkner
	loadtrainer FALKNER, 2
	sjumpfwd .Battle

.Bugsy
	loadtrainer BUGSY, 2
	sjumpfwd .Battle

.Whitney
	loadtrainer WHITNEY, 2
	sjumpfwd .Battle

.Morty
	loadtrainer MORTY, 2
	sjumpfwd .Battle

.Chuck
	loadtrainer CHUCK, 2
	sjumpfwd .Battle

.Jasmine
	loadtrainer JASMINE, 2
	sjumpfwd .Battle

.Pryce
	loadtrainer PRYCE, 2
	sjumpfwd .Battle

.Clair
	loadtrainer CLAIR, 2
	sjumpfwd .Battle

.Brock
	loadtrainer BROCK, 2
	sjumpfwd .Battle

.Misty
	loadtrainer MISTY, 2
	sjumpfwd .Battle

.LtSurge
	loadtrainer LT_SURGE, 2
	sjumpfwd .Battle

.Erika
	loadtrainer ERIKA, 2
	sjumpfwd .Battle

.Janine
	loadtrainer JANINE, 2
	sjumpfwd .Battle

.Sabrina
	loadtrainer SABRINA, 2
	sjumpfwd .Battle

.Blaine
	loadtrainer BLAINE, 2
	sjumpfwd .Battle

.Blue
	loadtrainer BLUE, 2
	sjumpfwd .Battle

.Will
	loadtrainer WILL, 2
	sjumpfwd .Battle

.Koga
	loadtrainer KOGA, 2
	sjumpfwd .Battle

.Bruno
	loadtrainer BRUNO, 2
	sjumpfwd .Battle

.Karen
	loadtrainer KAREN, 2
	sjumpfwd .Battle

.Lance
	loadtrainer CHAMPION, LANCE2

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
	special Special_SafariGauntlet_ChooseKeepMon
	special Special_SafariGauntlet_EndRunWin
	jumpopenedtext SafariGauntletReturnedText

SafariGauntletMoveReminderScript:
	special Special_SafariGauntlet_EnsureHubParty
	faceplayer

SafariGauntletMoveReminderMenu:
	opentext
	writetext SafariGauntletMoveReminderIntroText
	yesorno
	iffalse_jumpopenedtext SafariGauntletMoveReminderLaterText
	readvar VAR_PARTYCOUNT
	ifequalfwd 0, .NoParty
	setval NO_MOVE
	writetext SafariGauntletMoveReminderWhichMonText
	waitbutton
	special Special_MoveTutor
	ifequalfwd $0, .Learned
	jumpopenedtext SafariGauntletMoveReminderLaterText

.NoParty
	jumpopenedtext SafariGauntletMoveReminderNoPartyText

.Learned
	jumpopenedtext SafariGauntletMoveReminderDoneText

SafariGauntletTMVendorScript:
	special Special_SafariGauntlet_EnsureHubParty
	faceplayer
	opentext
.Loop
	writetext SafariGauntletTMVendorPickText
	readmem wSafariGauntletTMShopSet
	ifequalfwd $1, .Set1
	ifequalfwd $2, .Set2
	loadmenu SafariGauntletTMVendorMenuData0
	verticalmenu
	closewindow
	ifequalfwd $1, .Thunderbolt
	ifequalfwd $2, .Flamethrower
	ifequalfwd $3, .IceBeam
	ifequalfwd $4, .ShadowBall
	jumpopenedtext SafariGauntletTMVendorLaterText

.Set1
	loadmenu SafariGauntletTMVendorMenuData1
	verticalmenu
	closewindow
	ifequalfwd $1, .Earthquake
	ifequalfwd $2, .Psychic
	ifequalfwd $3, .GigaDrain
	ifequalfwd $4, .AerialAce
	jumpopenedtext SafariGauntletTMVendorLaterText

.Set2
	loadmenu SafariGauntletTMVendorMenuData2
	verticalmenu
	closewindow
	ifequalfwd $1, .EnergyBall
	ifequalfwd $2, .WillOWisp
	ifequalfwd $3, .ShadowClaw
	ifequalfwd $4, .ThunderWave
	jumpopenedtext SafariGauntletTMVendorLaterText

.Thunderbolt
	checktmhm TM_THUNDERBOLT
	iftruefwd .AlreadyOwned
	checkbp 5
	ifequalfwd HAVE_LESS, .NotEnoughBP
	gettmhmname TM_THUNDERBOLT, STRING_BUFFER_3
	givetmhm TM_THUNDERBOLT
	takebp 5
	sjumpfwd .Bought

.Flamethrower
	checktmhm TM_FLAMETHROWER
	iftruefwd .AlreadyOwned
	checkbp 5
	ifequalfwd HAVE_LESS, .NotEnoughBP
	gettmhmname TM_FLAMETHROWER, STRING_BUFFER_3
	givetmhm TM_FLAMETHROWER
	takebp 5
	sjumpfwd .Bought

.IceBeam
	checktmhm TM_ICE_BEAM
	iftruefwd .AlreadyOwned
	checkbp 5
	ifequalfwd HAVE_LESS, .NotEnoughBP
	gettmhmname TM_ICE_BEAM, STRING_BUFFER_3
	givetmhm TM_ICE_BEAM
	takebp 5
	sjumpfwd .Bought

.ShadowBall
	checktmhm TM_SHADOW_BALL
	iftruefwd .AlreadyOwned
	checkbp 4
	ifequalfwd HAVE_LESS, .NotEnoughBP
	gettmhmname TM_SHADOW_BALL, STRING_BUFFER_3
	givetmhm TM_SHADOW_BALL
	takebp 4
	sjumpfwd .Bought

.Earthquake
	checktmhm TM_EARTHQUAKE
	iftruefwd .AlreadyOwned
	checkbp 5
	ifequalfwd HAVE_LESS, .NotEnoughBP
	gettmhmname TM_EARTHQUAKE, STRING_BUFFER_3
	givetmhm TM_EARTHQUAKE
	takebp 5
	sjumpfwd .Bought

.Psychic
	checktmhm TM_PSYCHIC
	iftruefwd .AlreadyOwned
	checkbp 5
	ifequalfwd HAVE_LESS, .NotEnoughBP
	gettmhmname TM_PSYCHIC, STRING_BUFFER_3
	givetmhm TM_PSYCHIC
	takebp 5
	sjumpfwd .Bought

.GigaDrain
	checktmhm TM_GIGA_DRAIN
	iftruefwd .AlreadyOwned
	checkbp 4
	ifequalfwd HAVE_LESS, .NotEnoughBP
	gettmhmname TM_GIGA_DRAIN, STRING_BUFFER_3
	givetmhm TM_GIGA_DRAIN
	takebp 4
	sjumpfwd .Bought

.AerialAce
	checktmhm TM_AERIAL_ACE
	iftruefwd .AlreadyOwned
	checkbp 3
	ifequalfwd HAVE_LESS, .NotEnoughBP
	gettmhmname TM_AERIAL_ACE, STRING_BUFFER_3
	givetmhm TM_AERIAL_ACE
	takebp 3
	sjumpfwd .Bought

.EnergyBall
	checktmhm TM_ENERGY_BALL
	iftruefwd .AlreadyOwned
	checkbp 4
	ifequalfwd HAVE_LESS, .NotEnoughBP
	gettmhmname TM_ENERGY_BALL, STRING_BUFFER_3
	givetmhm TM_ENERGY_BALL
	takebp 4
	sjumpfwd .Bought

.WillOWisp
	checktmhm TM_WILL_O_WISP
	iftruefwd .AlreadyOwned
	checkbp 4
	ifequalfwd HAVE_LESS, .NotEnoughBP
	gettmhmname TM_WILL_O_WISP, STRING_BUFFER_3
	givetmhm TM_WILL_O_WISP
	takebp 4
	sjumpfwd .Bought

.ShadowClaw
	checktmhm TM_SHADOW_CLAW
	iftruefwd .AlreadyOwned
	checkbp 4
	ifequalfwd HAVE_LESS, .NotEnoughBP
	gettmhmname TM_SHADOW_CLAW, STRING_BUFFER_3
	givetmhm TM_SHADOW_CLAW
	takebp 4
	sjumpfwd .Bought

.ThunderWave
	checktmhm TM_THUNDER_WAVE
	iftruefwd .AlreadyOwned
	checkbp 3
	ifequalfwd HAVE_LESS, .NotEnoughBP
	gettmhmname TM_THUNDER_WAVE, STRING_BUFFER_3
	givetmhm TM_THUNDER_WAVE
	takebp 3

.Bought
	playsound SFX_TRANSACTION
	writetext SafariGauntletTMVendorBoughtText
	waitbutton
	sjump .Loop

.AlreadyOwned
	writetext SafariGauntletTMVendorAlreadyOwnedText
	waitbutton
	sjump .Loop

.NotEnoughBP
	writetext SafariGauntletTMVendorNotEnoughBPText
	waitbutton
	sjump .Loop

SafariGauntletKeepBoxNPCScript:
	faceplayer
	sjumpfwd SafariGauntletKeepBoxScript

SafariGauntletKeepBoxScript:
	special Special_SafariGauntlet_EnsureHubParty
	jumpstd pcscript

SafariGauntletSettingsScript:
	faceplayer
	sjumpfwd SafariGauntletSettingsMenu

SafariGauntletSettingsStartMenuScript:
SafariGauntletSettingsMenu:
	opentext
.Loop
	writetext SafariGauntletSettingsHeaderText
	loadmenu SafariGauntletSettingsMainMenuData
	verticalmenu
	closewindow
	ifequalfwd $1, .DexMode
	ifequalfwd $2, .CarryIn
	ifequalfwd $3, .BossReveal
	ifequalfwd $4, .Difficulty
	jumpopenedtext SafariGauntletSettingsSavedText

.DexMode
	writetext SafariGauntletSettingsDexPromptText
	loadmenu SafariGauntletDexModeMenuData
	verticalmenu
	closewindow
	ifequalfwd $1, .SetJohto
	ifequalfwd $2, .SetNational
	sjump .Loop

.SetJohto
	setval FALSE
	special Special_SafariGauntlet_SetDexMode
	special Special_SafariGauntlet_SaveSettings
	writetext SafariGauntletSetJohtoText
	promptbutton
	sjump .Loop

.SetNational
	setval TRUE
	special Special_SafariGauntlet_SetDexMode
	special Special_SafariGauntlet_SaveSettings
	writetext SafariGauntletSetNationalText
	promptbutton
	sjump .Loop

.CarryIn
	writetext SafariGauntletSettingsCarryPromptText
	loadmenu SafariGauntletOnOffMenuData
	verticalmenu
	closewindow
	ifequalfwd $1, .CarryOn
	ifequalfwd $2, .CarryOff
	sjump .Loop

.CarryOn
	setval TRUE
	special Special_SafariGauntlet_SetCarryIn
	special Special_SafariGauntlet_SaveSettings
	writetext SafariGauntletCarrySetOnText
	promptbutton
	sjump .Loop

.CarryOff
	setval FALSE
	special Special_SafariGauntlet_SetCarryIn
	special Special_SafariGauntlet_SaveSettings
	writetext SafariGauntletCarrySetOffText
	promptbutton
	sjump .Loop

.BossReveal
	writetext SafariGauntletSettingsBossPromptText
	loadmenu SafariGauntletBossRevealMenuData
	verticalmenu
	closewindow
	ifequalfwd $1, .RevealOn
	ifequalfwd $2, .RevealOff
	sjump .Loop

.RevealOn
	setval TRUE
	special Special_SafariGauntlet_SetBossReveal
	special Special_SafariGauntlet_SaveSettings
	writetext SafariGauntletBossRevealSetOnText
	promptbutton
	sjump .Loop

.RevealOff
	setval FALSE
	special Special_SafariGauntlet_SetBossReveal
	special Special_SafariGauntlet_SaveSettings
	writetext SafariGauntletBossRevealSetOffText
	promptbutton
	sjump .Loop

.Difficulty
	writetext SafariGauntletSettingsDifficultyPromptText
	loadmenu SafariGauntletDifficultyMenuData
	verticalmenu
	closewindow
	ifequalfwd $1, .DifficultySetCasual
	ifequalfwd $2, .DifficultySetStandard
	ifequalfwd $3, .DifficultySetHard
	sjump .Loop

.DifficultySetCasual
	setval SAFARI_GAUNTLET_DIFFICULTY_CASUAL
	special Special_SafariGauntlet_SetDifficulty
	special Special_SafariGauntlet_SaveSettings
	writetext SafariGauntletDifficultySetCasualText
	promptbutton
	sjump .Loop

.DifficultySetStandard
	setval SAFARI_GAUNTLET_DIFFICULTY_STANDARD
	special Special_SafariGauntlet_SetDifficulty
	special Special_SafariGauntlet_SaveSettings
	writetext SafariGauntletDifficultySetStandardText
	promptbutton
	sjump .Loop

.DifficultySetHard
	setval SAFARI_GAUNTLET_DIFFICULTY_HARD
	special Special_SafariGauntlet_SetDifficulty
	special Special_SafariGauntlet_SaveSettings
	writetext SafariGauntletDifficultySetHardText
	promptbutton
	sjump .Loop

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

	para "Your newest kept"
	line "#mon becomes"
	cont "your carry-in."
	done

SafariGauntletKeepBoxDoneText:
	text "Come back anytime."
	done

SafariGauntletKeepBoxEmptyText:
	text "No stored #mon"
	line "yet."

	para "Win a run and keep"
	line "one to unlock"
	cont "carry-in selection."
	done

SafariGauntletCarryChoiceText:
	text "Choose which"
	line "stored #mon"
	cont "to carry in."
	done

SafariGauntletCarryChoiceChangedText:
	text "Carry-in updated."
	done

SafariGauntletCarryChoiceSavedText:
	text "Carry-in choice"
	line "saved."
	done

SafariGauntletKeepBoxOpenPCText:
	text "Open your PC to"
	line "manage your team"
	cont "and boxes?"
	done

SafariGauntletExitBlockedText:
	text "The Safari"
	line "Gauntlet is"
	cont "self-contained."

	para "Please stay inside"
	line "between runs."
	done

SafariGauntletIntroText:
	text "Start a Safari"
	line "Gauntlet run?"
	done

SafariGauntletSaveText:
	text "Saving and loading"
	line "run supplies."
	done

SafariGauntletMaybeLaterText:
	text "The Gauntlet will"
	line "be here."
	done

SafariGauntletNeedOnePokemonText:
	text "Choose exactly"
	line "one #mon first."
	done

SafariGauntletStandardSuppliesText:
	text "Run supplies are"
	line "loaded."

	para "You have a Master"
	line "Ball, plenty of"
	cont "other Balls,"
	cont "healing items,"
	cont "12 Candies,"
	cont "3 Super"
	cont "Repels,"
	cont "Eevee stones"
	cont "(Sun/Moon too),"
	cont "and a Super Rod."
	prompt

SafariGauntletCasualSuppliesText:
	text "Casual supplies"
	line "are loaded."

	para "You have a Master"
	line "Ball, extra"
	cont "Balls and healing,"
	cont "12 Candies,"
	cont "3 Super"
	cont "Repels,"
	cont "Eevee stones"
	cont "(Sun/Moon too),"
	cont "and a Super Rod."
	prompt

SafariGauntletHardSuppliesText:
	text "Hard supplies are"
	line "loaded."

	para "You still get one"
	line "Master Ball, but"
	cont "fewer supplies"
	cont "12 Candies,"
	cont "3 Super"
	cont "Repels,"
	cont "Eevee stones"
	cont "(Sun/Moon too),"
	cont "and a Super Rod."
	prompt

SafariGauntletMoveReminderIntroText:
	text "Need old moves?"
	line "I can help."

	para "Use relearner?"
	done

SafariGauntletMoveReminderWhichMonText:
	text "Pick a #mon."
	done

SafariGauntletMoveReminderNoPartyText:
	text "Bring at least one"
	line "#mon first."
	done

SafariGauntletMoveReminderLaterText:
	text "Come back later."
	done

SafariGauntletMoveReminderDoneText:
	text "Old move taught."
	done

SafariGauntletTMVendorIntroText:
	text "TM stock is ready."
	line "Open TM shop?"
	done

SafariGauntletTMVendorLaterText:
	text "Come back anytime."
	done

SafariGauntletTMVendorPickText:
	text "BP: "
	text_decimal wBattlePoints, 2, 5
	line "Pick a TM."

	para "Press B to quit."
	done

SafariGauntletTMVendorConfirmText:
	text_ram wStringBuffer3
	text " costs BP."
	line "Buy it?"
	done

SafariGauntletTMVendorBoughtText:
	text "Bought "
	text_ram wStringBuffer3
	text "."
	done

SafariGauntletTMVendorThanksText:
	text "Done. Anything"
	line "else?"
	done

SafariGauntletTMVendorAlreadyOwnedText:
	text "You already have"
	line "that TM."
	done

SafariGauntletTMVendorNotEnoughBPText:
	text "You need more BP."
	done

SafariGauntletTMVendorMenuData0:
	db MENU_BACKUP_TILES
	menu_coords 0, 0, 19, 9
	dw .Items
	db 1 ; default option

.Items:
	db $80 ; flags
	db 4 ; items
	db "TM24 TBOLT  5BP@"
	db "TM35 FLAME  5BP@"
	db "TM13 ICEBM  5BP@"
	db "TM30 SHADOW 4BP@"

SafariGauntletTMVendorMenuData1:
	db MENU_BACKUP_TILES
	menu_coords 0, 0, 19, 9
	dw .Items
	db 1 ; default option

.Items:
	db $80 ; flags
	db 4 ; items
	db "TM26 EQUAKE 5BP@"
	db "TM29 PSYCHC 5BP@"
	db "TM19 GIGADR 4BP@"
	db "TM40 AERIAL 3BP@"

SafariGauntletTMVendorMenuData2:
	db MENU_BACKUP_TILES
	menu_coords 0, 0, 19, 9
	dw .Items
	db 1 ; default option

.Items:
	db $80 ; flags
	db 4 ; items
	db "TM53 E-BALL 4BP@"
	db "TM61 WISP  4BP@"
	db "TM65 SCLAW 4BP@"
	db "TM73 TWAVE 3BP@"

SafariGauntletRevealBossText:
	text "Boss reveal:"
	line ""
	text_ram wStringBuffer4
	text " waits at"
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
	text "The final boss is"
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
	line "final boss, then"
	cont "talk to me."
	done

SafariGauntletRound1Text:
	text "Round 1:"
	line "Trainer selected!"
	done

SafariGauntletRound2Text:
	text "Round 2:"
	line "Trainer selected!"
	done

SafariGauntletRound3Text:
	text "Round 3:"
	line "Trainer selected!"
	done

SafariGauntletRound4Text:
	text "Round 4:"
	line "Trainer selected!"
	done

SafariGauntletBossHealText:
	text "Final gate."

	para "Your team is fully"
	line "healed before the"
	cont "final boss."
	done

SafariGauntletRoundBPText:
	text "<PLAYER> earned"
	line "2 BP!"
	done

SafariGauntletBossBPText:
	text "<PLAYER> earned"
	line "10 BP from the"
	cont "final boss!"
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
	line "one #mon to"
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

SafariGauntletSettingsDexPromptText:
	text "Draft mode?"
	done

SafariGauntletSettingsCarryPromptText:
	text "Carry-in?"
	done

SafariGauntletSettingsBossPromptText:
	text "Boss reveal?"
	done

SafariGauntletSettingsDifficultyPromptText:
	text "Difficulty?"
	done

SafariGauntletSettingsMainMenuData:
	db MENU_BACKUP_TILES
	menu_coords 0, 0, 16, 10
	dw .Items
	db 1 ; default option

.Items:
	db $80 ; flags
	db 5 ; items
	db "Draft Mode@"
	db "Carry-in@"
	db "Boss Reveal@"
	db "Difficulty@"
	db "Done@"

SafariGauntletDexModeMenuData:
	db MENU_BACKUP_TILES
	menu_coords 0, 0, 15, 8
	dw .Items
	db 1 ; default option

.Items:
	db $80 ; flags
	db 3 ; items
	db "Johto@"
	db "National@"
	db "Back@"

SafariGauntletOnOffMenuData:
	db MENU_BACKUP_TILES
	menu_coords 0, 0, 12, 8
	dw .Items
	db 1 ; default option

.Items:
	db $80 ; flags
	db 3 ; items
	db "On@"
	db "Off@"
	db "Back@"

SafariGauntletBossRevealMenuData:
	db MENU_BACKUP_TILES
	menu_coords 0, 0, 12, 8
	dw .Items
	db 1 ; default option

.Items:
	db $80 ; flags
	db 3 ; items
	db "Reveal@"
	db "Hide@"
	db "Back@"

SafariGauntletDifficultyMenuData:
	db MENU_BACKUP_TILES
	menu_coords 0, 0, 14, 9
	dw .Items
	db 2 ; default option

.Items:
	db $80 ; flags
	db 4 ; items
	db "Casual@"
	db "Standard@"
	db "Hard@"
	db "Back@"

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
	line "under Rules in"
	cont "the Start menu."

	para "They stay saved"
	line "for future runs."
	done
