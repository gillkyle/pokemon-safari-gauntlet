Special_SafariGauntlet_BeginRun:
	xor a
	ld [wSafariGauntletDraftAttempts], a
	ld [wPartyCount], a
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
	ld a, [wSafariGauntletSettings]
	bit SAFARI_GAUNTLET_SETTINGS_NO_CARRY_F, a
	jr nz, .use_starter
	ld a, [wSafariGauntletKeepCount]
	and a
	jr nz, .use_carry
.use_starter
	ld a, LOW(EEVEE)
	ld [wCurPartySpecies], a
	ld a, HIGH(EEVEE) << MON_EXTSPECIES_F | PLAIN_FORM
	ld [wCurForm], a
	jr .give_starter

.use_carry
	ld hl, wSafariGauntletKeepSpecies
	ld a, [hl]
	ld [wCurPartySpecies], a
	xor a
	call SafariGauntlet_GetKeepExtFlag
	ld a, [hl]
	and b
	ld a, PLAIN_FORM
	jr z, .got_carry_form
	ld a, EXTSPECIES_MASK | PLAIN_FORM
.got_carry_form
	ld [wCurForm], a

.give_starter
	ld a, 35
	ld [wCurPartyLevel], a
	xor a
	ld [wCurItem], a
	ld [wCurPlayerMove], a
	ld a, POKE_BALL
	ld [wGiftMonBall], a
	call SafariGauntlet_GiveMonNoNickname
	farcall HealParty
	call SafariGauntlet_ClampPartyHP
	ld a, TRUE
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_CanDraft:
	ld a, [wSafariGauntletStep]
	cp SAFARI_GAUNTLET_STEP_DRAFT
	jr nz, .no
	ld a, [wPartyCount]
	cp PARTY_LENGTH
	jr nc, .no
	call SafariGauntlet_HasStepsRemaining
	and a
	jr z, .no
	call SafariGauntlet_HasUsableBalls
	and a
	jr z, .no
	ld a, TRUE
	jr .done

.no
	xor a
.done
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

Special_SafariGauntlet_NextDraftAttempt:
	ld hl, wSafariGauntletDraftAttempts
	inc [hl]
	ld a, [hl]
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
	call SafariGauntlet_SaveGame
	ld a, TRUE
	ldh [hScriptVar], a
	ret

Special_SafariGauntlet_EndRunLoss:
	call SafariGauntlet_RestoreRunData
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

Special_SafariGauntlet_ClampPartyHP:
	call SafariGauntlet_ClampPartyHP
	ld a, TRUE
	ldh [hScriptVar], a
	ret

SafariGauntlet_SaveGame:
	ld a, TRUE
	ld [wSavedAtLeastOnce], a
	farcall SaveGameData
	farcall SaveCurrentVersion
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
	xor a
	ld [wPartyCount], a
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
	db "EEVEE@"

SafariGauntletGiftOT:
	db "SAFARI@"
