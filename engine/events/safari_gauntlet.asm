Special_SafariGauntlet_BeginRun:
	call SafariGauntlet_SaveGame
	xor a
	ld [wSafariGauntletDraftAttempts], a
	ld [wSafariGauntletTrainerMaskLo], a
	ld [wSafariGauntletTrainerMaskHi], a
	dec a
	ld [wJohtoBadges], a
	ld [wKantoBadges], a
	call SafariGauntlet_ClearRunInventory
	ld a, SAFARI_GAUNTLET_STEP_DRAFT
	ld [wSafariGauntletStep], a
	ld a, [wSafariGauntletSettings]
	and SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_MASK
	cp SAFARI_GAUNTLET_DIFFICULTY_HARD << SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_SHIFT
	ld a, SAFARI_GAUNTLET_BALLS
	jr nz, .got_balls
	ld a, SAFARI_GAUNTLET_HARD_BALLS
.got_balls
	ld [wSafariBallsRemaining], a
	ld a, HIGH(SAFARI_GAUNTLET_DRAFT_STEPS)
	ld [wSafariTimeRemaining], a
	ld a, LOW(SAFARI_GAUNTLET_DRAFT_STEPS)
	ld [wSafariTimeRemaining + 1], a
	call SafariGauntlet_ClampKeepCount
	ld a, [wSafariGauntletSettings]
	bit SAFARI_GAUNTLET_SETTINGS_NO_CARRY_F, a
	jr nz, .use_starter
	ld a, [wPartyCount]
	cp 1
	jr z, .use_party

.use_starter
	xor a
	ld [wPartyCount], a
	ld a, LOW(EEVEE)
	ld [wCurPartySpecies], a
	ld a, HIGH(EEVEE) << MON_EXTSPECIES_F | PLAIN_FORM
	ld [wCurForm], a
	jr .give_starter

.use_party
	call SafariGauntlet_NormalizePartyLead
	jr .run_ready

.give_starter
	ld a, SAFARI_GAUNTLET_START_LEVEL
	ld [wCurPartyLevel], a
	xor a
	ld [wCurItem], a
	ld [wCurPlayerMove], a
	ld a, POKE_BALL
	ld [wGiftMonBall], a
	call SafariGauntlet_GiveMonNoNickname
	farcall HealParty
	call SafariGauntlet_ClampPartyHP
.run_ready
	ld a, TRUE
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_HasUsableBalls:
	call SafariGauntlet_HasUsableBalls
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_CheckDraftComplete:
	ld a, [wSafariGauntletStep]
	cp SAFARI_GAUNTLET_STEP_DRAFT
	jr nz, .no
	ld a, [wPartyCount]
	cp PARTY_LENGTH
	jr nc, .yes
	call SafariGauntlet_HasStepsRemaining
	and a
	jr z, .yes
	call SafariGauntlet_HasUsableBalls
	and a
	jr nz, .no

.yes
	ld a, TRUE
	jr .done

.no
	xor a
.done
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_FinishDraft:
	ld a, SAFARI_GAUNTLET_STEP_ROUND1
	ld [wSafariGauntletStep], a
	farcall HealParty
	call SafariGauntlet_ClampPartyHP
	ld a, TRUE
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_RollTrainerFamily:
	ld d, 16

.random_loop
	ld a, 16
	call RandomRange
	ld c, a
	call SafariGauntlet_GetTrainerFamilyFlag
	ld a, [hl]
	and b
	jr z, .mark
	dec d
	jr nz, .random_loop
	ld c, 0

.scan_loop
	call SafariGauntlet_GetTrainerFamilyFlag
	ld a, [hl]
	and b
	jr z, .mark
	inc c
	ld a, c
	cp 16
	jr c, .scan_loop
	xor a
	ldh [hScriptVar], a
	ret

.mark
	ld a, [hl]
	or b
	ld [hl], a
	ld a, c
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_CheckMinParty:
	ld a, [wPartyCount]
	cp SAFARI_GAUNTLET_MIN_TEAM
	ld a, FALSE
	jr c, .done
	inc a
.done
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_ChooseKeepMon:
	ld a, [wPartyCount]
	and a
	jr z, .fail
	ld a, [wSafariGauntletKeepCount]
	cp SAFARI_GAUNTLET_KEEP_CAPACITY
	jr nc, .fail
	farcall SelectMonFromParty
	jr nc, .got_mon
	xor a
	ld [wCurPartyMon], a

.got_mon
	ld a, MON_SPECIES
	call GetPartyParamLocationAndValue
	ld [wSafariGauntletRewardSpecies], a
	ld a, MON_FORM
	call GetPartyParamLocationAndValue
	and EXTSPECIES_MASK
	ld [wSafariGauntletRewardExtSpecies], a
	call SafariGauntlet_StoreSelectedRewardInPC
	ld a, TRUE
	ld [wSafariGauntletRewardPending], a
	jr .done

.fail
	xor a
.done
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_ChooseLossKeepMon:
	ld a, [wPartyCount]
	and a
	jr z, .fail
	farcall SelectMonFromParty
	jr nc, .got_mon
	xor a
	ld [wCurPartyMon], a

.got_mon
	ld a, [wCurPartyMon]
	ld [wSafariGauntletRewardSpecies], a
	call SafariGauntlet_CopyProtectedRunMonsToScratch
	ld a, [wSafariGauntletRewardSpecies]
	ld [wCurPartyMon], a
	inc a
	ld c, a
	ld b, 1
	farcall CopyBetweenPartyAndTemp
	call SafariGauntlet_NormalizeTempReward
	ld a, TRUE
	ld [wSafariGauntletRewardPending], a
	jr .done

.fail
	xor a
.done
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_EndRunWin:
	call SafariGauntlet_RestoreRunData
	xor a
	ld [wSafariGauntletStep], a
	ld hl, wSafariGauntletRuns
	call SafariGauntlet_Inc16
	ld hl, wSafariGauntletWins
	call SafariGauntlet_Inc16
	ld hl, wSafariGauntletCurrentStreak
	inc [hl]
	ld a, [wSafariGauntletBestStreak]
	cp [hl]
	jr nc, .streak_ok
	ld a, [hl]
	ld [wSafariGauntletBestStreak], a
.streak_ok
	call SafariGauntlet_SaveReward
	call SafariGauntlet_EnsureHubParty
	call SafariGauntlet_SaveGame
	ld a, TRUE
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_EndRunLoss:
	call SafariGauntlet_RestoreRunData
	ld a, [wSafariGauntletRewardPending]
	and a
	jr z, .no_loss_keep
	call SafariGauntlet_RestoreLossKeepParty
	call SafariGauntlet_StoreProtectedScratchMonsInPC
	jr .loss_keep_done

.no_loss_keep
	xor a
	ld [wOTPartyCount], a

.loss_keep_done
	xor a
	ld [wSafariGauntletStep], a
	ld hl, wSafariGauntletRuns
	call SafariGauntlet_Inc16
	ld hl, wSafariGauntletLosses
	call SafariGauntlet_Inc16
	xor a
	ld [wSafariGauntletCurrentStreak], a
	xor a
	ld [wBattleResult], a
	call SafariGauntlet_EnsureHubParty
	call SafariGauntlet_SaveGame
	ld a, TRUE
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_ToggleDexMode:
	ld hl, wSafariGauntletSettings
	ld a, 1 << SAFARI_GAUNTLET_SETTINGS_NATIONAL_F
	xor [hl]
	ld [hl], a
	and 1 << SAFARI_GAUNTLET_SETTINGS_NATIONAL_F
	jr SafariGauntlet_ReturnBoolean

Special_SafariGauntlet_GetDexMode:
	ld a, [wSafariGauntletSettings]
	and 1 << SAFARI_GAUNTLET_SETTINGS_NATIONAL_F
SafariGauntlet_ReturnBoolean:
	ld a, FALSE
	jr z, .done
	inc a
.done
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_SetDexMode:
	ld hl, wSafariGauntletSettings
	ldh a, [hScriptVar]
	and a
	jr z, .johto
	set SAFARI_GAUNTLET_SETTINGS_NATIONAL_F, [hl]
	ld a, TRUE
	ldh [hScriptVar], a
	ret

.johto
	res SAFARI_GAUNTLET_SETTINGS_NATIONAL_F, [hl]
	xor a
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_ToggleCarryIn:
	ld hl, wSafariGauntletSettings
	ld a, 1 << SAFARI_GAUNTLET_SETTINGS_NO_CARRY_F
	xor [hl]
	ld [hl], a
	and 1 << SAFARI_GAUNTLET_SETTINGS_NO_CARRY_F
	jr SafariGauntlet_ReturnInverseBoolean

Special_SafariGauntlet_GetCarryIn:
	ld a, [wSafariGauntletSettings]
	and 1 << SAFARI_GAUNTLET_SETTINGS_NO_CARRY_F
SafariGauntlet_ReturnInverseBoolean:
	ld a, TRUE
	jr z, .done
	xor a
.done
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_SetCarryIn:
	ld hl, wSafariGauntletSettings
	ldh a, [hScriptVar]
	and a
	jr z, .off
	res SAFARI_GAUNTLET_SETTINGS_NO_CARRY_F, [hl]
	ld a, TRUE
	ldh [hScriptVar], a
	ret

.off
	set SAFARI_GAUNTLET_SETTINGS_NO_CARRY_F, [hl]
	xor a
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_ToggleBossReveal:
	ld hl, wSafariGauntletSettings
	ld a, 1 << SAFARI_GAUNTLET_SETTINGS_HIDE_BOSS_F
	xor [hl]
	ld [hl], a
	and 1 << SAFARI_GAUNTLET_SETTINGS_HIDE_BOSS_F
	jr SafariGauntlet_ReturnInverseBoolean

Special_SafariGauntlet_GetBossReveal:
	ld a, [wSafariGauntletSettings]
	and 1 << SAFARI_GAUNTLET_SETTINGS_HIDE_BOSS_F
	jr SafariGauntlet_ReturnInverseBoolean

Special_SafariGauntlet_SetBossReveal:
	ld hl, wSafariGauntletSettings
	ldh a, [hScriptVar]
	and a
	jr z, .off
	res SAFARI_GAUNTLET_SETTINGS_HIDE_BOSS_F, [hl]
	ld a, TRUE
	ldh [hScriptVar], a
	ret

.off
	set SAFARI_GAUNTLET_SETTINGS_HIDE_BOSS_F, [hl]
	xor a
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_CycleDifficulty:
	ld hl, wSafariGauntletSettings
	ld a, [hl]
	and SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_MASK
	rept SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_SHIFT
		srl a
	endr
	inc a
	cp SAFARI_GAUNTLET_DIFFICULTY_HARD + 1
	jr c, .got_difficulty
	xor a
.got_difficulty
	ld b, a
	rept SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_SHIFT
		sla a
	endr
	ld c, a
	ld a, [hl]
	and SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_CLEAR
	or c
	ld [hl], a
	ld a, b
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_SetDifficulty:
	ldh a, [hScriptVar]
	cp SAFARI_GAUNTLET_DIFFICULTY_HARD + 1
	jr c, .valid
	xor a

.valid
	ld b, a
	rept SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_SHIFT
		sla a
	endr
	ld c, a
	ld hl, wSafariGauntletSettings
	ld a, [hl]
	and SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_CLEAR
	or c
	ld [hl], a
	ld a, b
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_GetDifficulty:
	ld a, [wSafariGauntletSettings]
	and SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_MASK
	rept SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_SHIFT
		srl a
	endr
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_SaveSettings:
	call SafariGauntlet_SaveGame
	ld a, TRUE
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_SelectCarryMon:
	call SafariGauntlet_ClampKeepCount
	call SafariGauntlet_GetCarrySlotIndex
	ld a, [wSafariGauntletKeepCount]
	and a
	jr z, .cancel
	call LoadStandardMenuHeader
	ld hl, .MenuDataHeader
	call CopyMenuHeader
	ld a, [wSafariGauntletCarrySlot]
	inc a
	ld [wMenuCursorBuffer], a
	xor a
	ld [wMenuScrollPosition], a
	call InitScrollingMenu
	call ScrollingMenu
	call CloseWindow
	call ExitMenu
	ld a, [wMenuJoypad]
	cp PAD_B
	jr z, .cancel
	ld a, [wScrollingMenuCursorPosition]
	ld [wSafariGauntletCarrySlot], a
	ld a, TRUE
	jr .done

.cancel
	xor a
.done
	ldh [hScriptVar], a
	ret

.MenuDataHeader:
	db MENU_BACKUP_TILES
	menu_coords 1, 1, 18, 10
	dw .MenuData2
	db 1 ; default option

	db 0

.MenuData2:
	db $10 ; flags
	db 6, 0
	db 1
	dbw 0, wSafariGauntletKeepCount
	dba .PlaceKeepMonName
	dba NULL
	dba NULL

.PlaceKeepMonName:
	ld a, [wMenuSelection]
	and a
	ret z
	push de
	ld [wNamedObjectIndex], a
	xor a
	ld [wNamedObjectIndex + 1], a
	call GetPokemonName
	pop hl
	rst PlaceString
	ret

Special_SafariGauntlet_ClampPartyHP:
	call SafariGauntlet_ClampPartyHP
	ld a, TRUE
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_EnsureHubParty:
	call SafariGauntlet_EnsureHubParty
	ld a, TRUE
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_EnsureStarterPC:
	ld a, [wSafariGauntletSettings]
	bit SAFARI_GAUNTLET_SETTINGS_STARTER_PC_SEEDED_F, a
	jr nz, .done
	call SafariGauntlet_EnsureStarterKeepBox
	call SafariGauntlet_SeedStarterPC
	call SafariGauntlet_SaveGame

.done
	ld a, TRUE
	ldh [hScriptVar], a
	ret

SafariGauntlet_SaveGame:
	ld a, TRUE
	ld [wSavedAtLeastOnce], a
	farcall SaveGameData
	farcall SaveCurrentVersion
	ret

SafariGauntlet_NormalizePartyLead:
	xor a
	ld [wCurPartyMon], a
	ld a, SAFARI_GAUNTLET_START_LEVEL
	ld [wCurPartyLevel], a
	ld a, MON_LEVEL
	call GetPartyParamLocationAndValue
	ld [hl], SAFARI_GAUNTLET_START_LEVEL
	ld a, MON_SPECIES
	call GetPartyParamLocationAndValue
	ld [wCurSpecies], a
	ld a, MON_FORM
	call GetPartyParamLocationAndValue
	ld [wCurForm], a
	call GetBaseData
	ld d, SAFARI_GAUNTLET_START_LEVEL
	farcall CalcExpAtLevel
	ld a, MON_EXP
	call GetPartyParamLocationAndValue
	ldh a, [hMultiplicand]
	ld [hli], a
	ldh a, [hMultiplicand + 1]
	ld [hli], a
	ldh a, [hMultiplicand + 2]
	ld [hl], a
	farcall UpdatePkmnStats
	farcall HealParty
	call SafariGauntlet_ClampPartyHP
	ret

SafariGauntlet_StoreSelectedRewardInPC:
	ld a, [wCurPartyMon]
	inc a
	ld c, a
	ld b, 1
	farcall CopyBetweenPartyAndTemp
	call SafariGauntlet_NormalizeTempReward
	farcall NewStorageBoxPointer
	ret c
	ld a, c
	ld [wTempMonSlot], a
	ld a, b
	ld [wTempMonBox], a
	farcall UpdateStorageBoxMonFromTemp
	ret

SafariGauntlet_CopyProtectedRunMonsToScratch:
	xor a
	ld [wOTPartyCount], a
	ld a, [wPartyCount]
	ld b, a
	xor a
	ld c, a

.loop
	ld a, c
	cp b
	ret nc
	ld a, [wSafariGauntletRewardSpecies]
	cp c
	jr z, .next
	ld a, c
	ld [wCurPartyMon], a
	push bc
	call SafariGauntlet_IsCurPartyMonProtected
	and a
	jr z, .skip_copy
	call SafariGauntlet_CopyCurPartyMonToScratch

.skip_copy
	pop bc

.next
	inc c
	jr .loop

SafariGauntlet_CopyCurPartyMonToScratch:
	ld a, [wOTPartyCount]
	cp PARTY_LENGTH
	ret nc
	push af
	ld a, [wCurPartyMon]
	inc a
	ld c, a
	ld b, 1
	farcall CopyBetweenPartyAndTemp
	call SafariGauntlet_NormalizeTempReward
	pop af
	inc a
	ld c, a
	ld b, $80
	farcall CopyBetweenPartyAndTemp
	ld hl, wOTPartyCount
	inc [hl]
	ret

SafariGauntlet_IsCurPartyMonProtected:
	ld a, MON_SPECIES
	call GetPartyParamLocationAndValue
	ld b, a
	ld a, MON_FORM
	call GetPartyParamLocationAndValue
	and EXTSPECIES_MASK
	ld c, a
	ld hl, .ProtectedSpecies

.loop
	ld a, [hli]
	cp -1
	jr z, .no
	cp b
	jr nz, .skip_ext
	ld a, [hli]
	cp c
	jr z, .yes
	jr .loop

.skip_ext
	inc hl
	jr .loop

.yes
	ld a, TRUE
	ret

.no
	xor a
	ret

.ProtectedSpecies:
	db LOW(EEVEE), HIGH(EEVEE) << MON_EXTSPECIES_F
	db LOW(VAPOREON), HIGH(VAPOREON) << MON_EXTSPECIES_F
	db LOW(JOLTEON), HIGH(JOLTEON) << MON_EXTSPECIES_F
	db LOW(FLAREON), HIGH(FLAREON) << MON_EXTSPECIES_F
	db LOW(ESPEON), HIGH(ESPEON) << MON_EXTSPECIES_F
	db LOW(UMBREON), HIGH(UMBREON) << MON_EXTSPECIES_F
	db LOW(LEAFEON), HIGH(LEAFEON) << MON_EXTSPECIES_F
	db LOW(GLACEON), HIGH(GLACEON) << MON_EXTSPECIES_F
	db LOW(SYLVEON), HIGH(SYLVEON) << MON_EXTSPECIES_F
	db LOW(BULBASAUR), HIGH(BULBASAUR) << MON_EXTSPECIES_F
	db LOW(IVYSAUR), HIGH(IVYSAUR) << MON_EXTSPECIES_F
	db LOW(VENUSAUR), HIGH(VENUSAUR) << MON_EXTSPECIES_F
	db LOW(CHARMANDER), HIGH(CHARMANDER) << MON_EXTSPECIES_F
	db LOW(CHARMELEON), HIGH(CHARMELEON) << MON_EXTSPECIES_F
	db LOW(CHARIZARD), HIGH(CHARIZARD) << MON_EXTSPECIES_F
	db LOW(SQUIRTLE), HIGH(SQUIRTLE) << MON_EXTSPECIES_F
	db LOW(WARTORTLE), HIGH(WARTORTLE) << MON_EXTSPECIES_F
	db LOW(BLASTOISE), HIGH(BLASTOISE) << MON_EXTSPECIES_F
	db LOW(CHIKORITA), HIGH(CHIKORITA) << MON_EXTSPECIES_F
	db LOW(BAYLEEF), HIGH(BAYLEEF) << MON_EXTSPECIES_F
	db LOW(MEGANIUM), HIGH(MEGANIUM) << MON_EXTSPECIES_F
	db LOW(CYNDAQUIL), HIGH(CYNDAQUIL) << MON_EXTSPECIES_F
	db LOW(QUILAVA), HIGH(QUILAVA) << MON_EXTSPECIES_F
	db LOW(TYPHLOSION), HIGH(TYPHLOSION) << MON_EXTSPECIES_F
	db LOW(TOTODILE), HIGH(TOTODILE) << MON_EXTSPECIES_F
	db LOW(CROCONAW), HIGH(CROCONAW) << MON_EXTSPECIES_F
	db LOW(FERALIGATR), HIGH(FERALIGATR) << MON_EXTSPECIES_F
	db -1

SafariGauntlet_StoreProtectedScratchMonsInPC:
	ld a, [wOTPartyCount]
	ld b, a
	xor a
	ld c, a

.loop
	ld a, c
	cp b
	jr nc, .done
	push bc
	inc c
	ld b, $81
	farcall CopyBetweenPartyAndTemp
	call SafariGauntlet_NormalizeTempReward
	call SafariGauntlet_StoreTempMonInPC
	pop bc
	inc c
	jr .loop

.done
	xor a
	ld [wOTPartyCount], a
	ret

SafariGauntlet_StoreTempMonInPC:
	farcall NewStorageBoxPointer
	ret c
	ld a, c
	ld [wTempMonSlot], a
	ld a, b
	ld [wTempMonBox], a
	farcall UpdateStorageBoxMonFromTemp
	ret

SafariGauntlet_RestoreLossKeepParty:
	ld a, [wSafariGauntletRewardPending]
	and a
	ret z
	xor a
	ld [wSafariGauntletRewardPending], a
	call SafariGauntlet_NormalizeTempReward
	xor a
	ld [wPartyCount], a
	ld c, 1
	ld b, 0
	farcall CopyBetweenPartyAndTemp
	ld a, 1
	ld [wPartyCount], a
	farcall HealParty
	call SafariGauntlet_ClampPartyHP
	ret

SafariGauntlet_NormalizeTempReward:
	ld a, SAFARI_GAUNTLET_START_LEVEL
	ld [wTempMonLevel], a
	ld [wCurPartyLevel], a
	ld a, [wTempMonSpecies]
	ld [wCurSpecies], a
	ld a, [wTempMonForm]
	ld [wCurForm], a
	call GetBaseData
	ld d, SAFARI_GAUNTLET_START_LEVEL
	farcall CalcExpAtLevel
	ld hl, wTempMonExp
	ldh a, [hMultiplicand]
	ld [hli], a
	ldh a, [hMultiplicand + 1]
	ld [hli], a
	ldh a, [hMultiplicand + 2]
	ld [hl], a
	farcall SetTempPartyMonData
	ret

SafariGauntlet_Inc16:
	inc hl
	inc [hl]
	ret nz
	dec hl
	inc [hl]
	ret

SafariGauntlet_HasUsableBalls:
	ld a, [wNumBalls]
	and a
	ret z
	ld b, a
	ld hl, wBalls + 1

.loop
	ld a, [hli]
	and a
	jr nz, .yes
	inc hl
	dec b
	jr nz, .loop
	xor a
	ret

.yes
	ld a, TRUE
	ret

SafariGauntlet_HasStepsRemaining:
	ld a, [wSafariTimeRemaining]
	ld hl, wSafariTimeRemaining + 1
	or [hl]
	ld a, TRUE
	ret nz
	xor a
	ret

SafariGauntlet_SaveReward:
	ld a, [wSafariGauntletRewardPending]
	and a
	ret z
	xor a
	ld [wSafariGauntletRewardPending], a
	ld a, [wSafariGauntletKeepCount]
	cp SAFARI_GAUNTLET_KEEP_CAPACITY
	ret nc
	push af
	ld hl, wSafariGauntletKeepSpecies
	ld bc, 1
	rst AddNTimes
	ld a, [wSafariGauntletRewardSpecies]
	ld [hl], a
	pop af
	push af
	call SafariGauntlet_GetKeepExtFlag
	ld a, [wSafariGauntletRewardExtSpecies]
	and EXTSPECIES_MASK
	jr z, .not_ext
	ld a, b
	or [hl]
	ld [hl], a
	jr .inc_count

.not_ext
	ld a, b
	cpl
	and [hl]
	ld [hl], a

.inc_count
	pop af
	ld [wSafariGauntletCarrySlot], a
	ld hl, wSafariGauntletKeepCount
	inc [hl]
	ret

SafariGauntlet_GetKeepExtFlag:
	ld c, a
	srl a
	srl a
	srl a
	ld e, a
	ld d, 0
	ld hl, wSafariGauntletKeepExtSpecies
	add hl, de
	ld a, c
	and 7
	ld b, 1
	ret z
.mask_loop
	sla b
	dec a
	jr nz, .mask_loop
	ret

SafariGauntlet_GetTrainerFamilyFlag:
	ld a, c
	cp 8
	jr c, .low
	sub 8
	ld hl, wSafariGauntletTrainerMaskHi
	jr .got_byte

.low
	ld hl, wSafariGauntletTrainerMaskLo

.got_byte
	ld b, 1
	and a
	ret z

.mask_loop
	sla b
	dec a
	jr nz, .mask_loop
	ret

SafariGauntlet_ClampKeepCount:
	ld a, [wSafariGauntletKeepCount]
	cp SAFARI_GAUNTLET_KEEP_CAPACITY + 1
	ret c
	ld a, SAFARI_GAUNTLET_KEEP_CAPACITY
	ld [wSafariGauntletKeepCount], a
	ret

SafariGauntlet_GetCarrySlotIndex:
	call SafariGauntlet_ClampKeepCount
	ld a, [wSafariGauntletKeepCount]
	and a
	jr nz, .have_keep
	xor a
	ld [wSafariGauntletCarrySlot], a
	ret

.have_keep
	ld b, a
	ld a, [wSafariGauntletCarrySlot]
	cp b
	jr c, .valid
	xor a
	ld [wSafariGauntletCarrySlot], a
	ret

.valid
	ret

SafariGauntlet_EnsureStarterKeepBox:
	ld a, [wSafariGauntletSettings]
	bit SAFARI_GAUNTLET_SETTINGS_KEEPBOX_SEEDED_F, a
	ret nz
	call SafariGauntlet_ClampKeepCount
	ld hl, .StarterSpecies
.next_species
	ld a, [hli]
	cp -1
	jr z, .mark_seeded
	push hl
	call SafariGauntlet_AddKeepSpeciesIfMissing
	pop hl
	jr .next_species

.mark_seeded
	ld hl, wSafariGauntletSettings
	set SAFARI_GAUNTLET_SETTINGS_KEEPBOX_SEEDED_F, [hl]
	ret

.StarterSpecies:
	db EEVEE
	db BULBASAUR
	db CHARMANDER
	db SQUIRTLE
	db CHIKORITA
	db CYNDAQUIL
	db TOTODILE
	db -1

SafariGauntlet_AddKeepSpeciesIfMissing:
	ld c, a
	ld a, [wSafariGauntletKeepCount]
	ld b, a
	ld hl, wSafariGauntletKeepSpecies
.scan
	ld a, b
	and a
	jr z, .append
	ld a, [hli]
	cp c
	ret z
	dec b
	jr .scan

.append
	ld a, [wSafariGauntletKeepCount]
	cp SAFARI_GAUNTLET_KEEP_CAPACITY
	ret nc
	ld e, c
	push af
	ld hl, wSafariGauntletKeepSpecies
	ld bc, 1
	rst AddNTimes
	ld a, e
	ld [hl], a
	pop af
	push af
	call SafariGauntlet_GetKeepExtFlag
	ld a, b
	cpl
	and [hl]
	ld [hl], a
	pop af
	inc a
	ld [wSafariGauntletKeepCount], a
	ret

SafariGauntlet_SeedStarterPC:
	ld a, [wSafariGauntletSettings]
	bit SAFARI_GAUNTLET_SETTINGS_STARTER_PC_SEEDED_F, a
	ret nz
	ld hl, .StarterPCSpecies
.next_species
	ld a, [hli]
	cp -1
	jr z, .mark_seeded
	push hl
	call SafariGauntlet_AddStarterToPC
	pop hl
	jr .next_species

.mark_seeded
	ld hl, wSafariGauntletSettings
	set SAFARI_GAUNTLET_SETTINGS_STARTER_PC_SEEDED_F, [hl]
	ret

	; Two extra Eevees let players keep the starter Eevee intact and still
	; experiment with Eeveelutions.
.StarterPCSpecies:
	db EEVEE
	db EEVEE
	db BULBASAUR
	db CHARMANDER
	db SQUIRTLE
	db CHIKORITA
	db CYNDAQUIL
	db TOTODILE
	db -1

SafariGauntlet_AddStarterToPC:
	ld [wCurPartySpecies], a
	ld [wCurSpecies], a
	ld a, PLAIN_FORM
	ld [wCurForm], a
	ld a, SAFARI_GAUNTLET_START_LEVEL
	ld [wCurPartyLevel], a
	call SafariGauntlet_AddMonSilently
	ld a, [wPartyCount]
	and a
	ret z
	ld c, a
	ld b, 1
	farcall CopyBetweenPartyAndTemp
	farcall NewStorageBoxPointer
	push af
	ld a, c
	ld [wTempMonSlot], a
	ld a, b
	ld [wTempMonBox], a
	pop af
	call nc, .store_temp
	ld a, [wPartyCount]
	dec a
	ld [wCurPartyMon], a
	farcall RemoveMonFromParty
	ret

.store_temp
	farcall UpdateStorageBoxMonFromTemp
	ret

SafariGauntlet_EnsureHubParty:
	call SafariGauntlet_ClampKeepCount
	ld a, [wPartyCount]
	and a
	ret nz

.check_map
	ld a, [wMapGroup]
	cp GROUP_BATTLE_FACTORY_1F
	ret nz
	ld a, [wMapNumber]
	cp MAP_BATTLE_FACTORY_1F
	ret nz
.build_party
	; Keep hub bootstrap deterministic and resilient to stale carry data.
	; Carry selection is still applied at run start in BeginRun.
	ld a, LOW(EEVEE)
	ld [wCurPartySpecies], a
	ld a, HIGH(EEVEE) << MON_EXTSPECIES_F | PLAIN_FORM
	ld [wCurForm], a

.give_mon
	ld a, SAFARI_GAUNTLET_START_LEVEL
	ld [wCurPartyLevel], a
	xor a
	ld [wCurItem], a
	ld [wCurPlayerMove], a
	ld a, POKE_BALL
	ld [wGiftMonBall], a
	call SafariGauntlet_AddMonSilently
	farcall HealParty
	call SafariGauntlet_ClampPartyHP
	ret

SafariGauntlet_AddMonSilently:
	xor a
	ld [wMonType], a
	ld [wBattleMode], a
	farcall TryAddMonToParty
	ret

SafariGauntlet_GiveMonNoNickname:
	ldh a, [hScriptBank]
	push af
	ld a, BANK(SafariGauntletGiftData)
	ldh [hScriptBank], a
	ld de, SafariGauntletGiftData
	ld b, TRUE
	farcall GivePoke
	call SafariGauntlet_ResetLastPartyNickname
	pop af
	ldh [hScriptBank], a
	ret

SafariGauntlet_ResetLastPartyNickname:
	ld a, [wPartyCount]
	and a
	ret z
	dec a
	ld hl, wPartyMonNicknames
	call SkipNames
	push hl
	call GetPartyPokemonName
	ld de, wStringBuffer1
	pop hl
	call CopyName2
	ret

SafariGauntlet_ClampPartyHP:
	ld a, [wPartyCount]
	and a
	ret z
	ld c, a
	ld hl, wPartyMon1HP

.loop
	push bc
	push hl
	ld a, [hli]
	ld b, a
	ld a, [hli]
	ld c, a
	ld a, [hli]
	ld d, a
	ld e, [hl]
	ld a, d
	cp b
	jr c, .clamp
	jr nz, .next
	ld a, e
	cp c
	jr nc, .next

.clamp
	pop hl
	ld a, d
	ld [hli], a
	ld [hl], e
	dec hl
	jr .advance

.next
	pop hl

.advance
	ld de, PARTYMON_STRUCT_LENGTH
	add hl, de
	pop bc
	dec c
	jr nz, .loop
	ret

SafariGauntlet_RestoreRunData:
	farcall LoadPokemonData
	call SafariGauntlet_ClearRunInventory
	; Preserve the one Pokemon the player brought into the run. BeginRun saves
	; the user's hub party before temporary Safari catches are added, so loading
	; PokemonData is enough to discard run catches without regenerating Eevee.
	ret

SafariGauntlet_ClearRunInventory:
	ld hl, wNumItems
	call SafariGauntlet_InitPocket
	ld hl, wNumMedicine
	call SafariGauntlet_InitPocket
	ld hl, wNumBalls
	call SafariGauntlet_InitPocket
	ld hl, wNumBerries
	; fallthrough

SafariGauntlet_InitPocket:
	xor a
	ld [hli], a
	dec a
	ld [hl], a
	ret

SafariGauntletGiftData:
	dw SafariGauntletGiftNickname
	dw SafariGauntletGiftOT
	bigdw 0

SafariGauntletGiftNickname:
	db "TRAINER@"

SafariGauntletGiftOT:
	db "SAFARI@"
