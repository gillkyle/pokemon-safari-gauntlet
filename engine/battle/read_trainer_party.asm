ReadTrainerParty:
	ld a, [wInBattleTowerBattle]
	and a
	ret nz

	ld a, [wLinkMode]
	and a
	ret nz ; populated elsewhere

	xor a
	ld [wOTPartyCount], a

	ld hl, wOTPartyMons
	ld bc, PARTYMON_STRUCT_LENGTH * PARTY_LENGTH
	rst ByteFill

	call FindTrainerData
	ld a, b
	add l
	ld b, a
	push bc

	call GetNextTrainerDataByte
	ld [wOtherTrainerType], a

.loop2
; level
	pop bc
	ld a, l
	sub b
	jp z, .done
	push bc

	call GetNextTrainerDataByte
	farcall AdjustLevelForBadges
	call SafariGauntlet_AdjustTrainerLevelForStage
	ld [wCurPartyLevel], a

; species
	call GetNextTrainerDataByte
	ld [wCurPartySpecies], a
	ld c, a

	call GetNextTrainerDataByte
	ld b, a
	call SetDynamicForm
	ld a, b
	ld [wCurForm], a

	ld a, OTPARTYMON
	ld [wMonType], a

	push hl
	farcall TryAddMonToParty
	pop hl

; item?
	ld a, [wOtherTrainerType]
	bit TRNTYPE_ITEM, a
	jr z, .not_item

	push hl
	ld a, [wOTPartyCount]
	dec a
	ld hl, wOTPartyMon1Item
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes
	ld d, h
	ld e, l
	pop hl

	call GetNextTrainerDataByte
	ld [de], a

.not_item
; DVs?
	ld a, [wOtherTrainerType]
	bit TRNTYPE_DVS, a
	jr z, .not_dvs

	push hl
	ld a, [wOTPartyCount]
	dec a
	ld hl, wOTPartyMon1DVs
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes
	ld d, h
	ld e, l
	pop hl

	call GetNextTrainerDataByte
	farcall WriteTrainerDVs

.not_dvs
; personality?
	ld a, [wOtherTrainerType]
	bit TRNTYPE_PERSONALITY, a
	jr z, .not_personality

	; We only care about the upper personality byte.
	; The lower one has already been specified as part of
	; extended species data ("dp").
	push hl
	ld a, [wOTPartyCount]
	dec a
	ld hl, wOTPartyMon1Personality
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes
	ld d, h
	ld e, l
	pop hl
	call GetNextTrainerDataByte
	ld [de], a

.not_personality
; nickname?
	ld a, [wOtherTrainerType]
	bit TRNTYPE_NICKNAME, a
	jr z, .not_nickname

	call GetNextTrainerDataByte
	cp '@'
	jr z, .not_nickname

	push de
	ld de, wStringBuffer2
	ld [de], a
	inc de
.copy
	call GetNextTrainerDataByte
	ld [de], a
	inc de
	cp '@'
	jr nz, .copy
	push hl
	ld a, [wOTPartyCount]
	dec a
	ld hl, wOTPartyMonNicknames
	ld bc, MON_NAME_LENGTH
	rst AddNTimes
	ld d, h
	ld e, l
	ld hl, wStringBuffer2
	ld bc, MON_NAME_LENGTH
	rst CopyBytes
	pop hl
	pop de

.not_nickname
; EVs?
	ld a, [wOtherTrainerType]
	bit TRNTYPE_EVS, a
	jr z, .not_evs
	push hl
	ld a, [wOTPartyCount]
	dec a
	ld hl, wOTPartyMon1EVs
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes
	ld d, h
	ld e, l
	pop hl

	call GetNextTrainerDataByte
	farcall WriteTrainerEVs

.not_evs
; moves?
	ld a, [wOtherTrainerType]
	bit TRNTYPE_MOVES, a
	jr z, .not_moves

	push hl
	ld a, [wOTPartyCount]
	dec a
	ld hl, wOTPartyMon1Moves
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes
	ld d, h
	ld e, l
	pop hl

	ld b, NUM_MOVES
.copy_moves
	call GetNextTrainerDataByte
	ld [de], a
	inc de
	cp RETURN
	jr z, .return
	cp GYRO_BALL
	jr nz, .done_special_moves

	; Set speed EVs and IVs to 0
	push hl
	push de
	push bc
	ld a, [wOTPartyCount]
	dec a
	ld hl, wOTPartyMon1SpeEV
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes
	ld [hl], 0
	ld a, [wOTPartyCount]
	dec a
	ld hl, wOTPartyMon1DefSpeDV
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes
	ld a, [hl]
	; $f1, not $f0, to leave Hidden Power type alone
	and $f1
	ld [hl], a
	pop bc
	pop de
	pop hl
	jr .done_special_moves

.return
	; Maximize happiness
	push hl
	push de
	push bc
	ld a, [wOTPartyCount]
	dec a
	ld hl, wOTPartyMon1Happiness
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes
	ld [hl], MAX_RETURN_HAPPINESS
	pop bc
	pop de
	pop hl

.done_special_moves
	dec b
	jr nz, .copy_moves

	push hl

	ld a, [wOTPartyCount]
	dec a
	ld hl, wOTPartyMon1Species
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes
	ld d, h
	ld e, l
	ld hl, MON_PP
	add hl, de

	push hl
	ld hl, MON_MOVES
	add hl, de
	pop de

	farcall FillPP

	pop hl

.not_moves
	; custom DVs or nature may alter stats
	ld a, [wOtherTrainerType]
	and TRAINERTYPE_EVS | TRAINERTYPE_DVS | TRAINERTYPE_PERSONALITY
	jr z, .no_stat_recalc
	push hl
	ld a, [wOTPartyCount]
	dec a
	ld hl, wOTPartyMon1MaxHP
	ld bc, PARTYMON_STRUCT_LENGTH
	push af
	rst AddNTimes
	pop af
	push hl
	ld hl, wOTPartyMon1EVs - 1
	ld bc, PARTYMON_STRUCT_LENGTH
	rst AddNTimes
	pop de
	ld b, TRUE
	push de
	farcall CalcPkmnStats
	pop hl
	inc hl
	ld a, [hld]
	ld c, a
	ld a, [hld]
	ld [hl], c ; no-optimize *hl++|*hl-- = b|c|d|e
	dec hl
	ld [hl], a
	pop hl
.no_stat_recalc
	jmp .loop2

.done
	call SafariGauntlet_LoadCuratedTrainerParty
	ret

SafariGauntlet_AdjustTrainerLevelForStage:
	push hl
	ld c, a
	ld a, [wSafariGauntletStep]
	cp SAFARI_GAUNTLET_STEP_ROUND1
	jr c, .use_original
	cp SAFARI_GAUNTLET_STEP_BOSS + 1
	jr nc, .use_original
	sub SAFARI_GAUNTLET_STEP_ROUND1
	add a
	ld e, a
	ld d, 0
	ld hl, .LevelRanges
	add hl, de
	ld a, [hli]
	ld b, a ; minimum
	ld a, [hl]
	sub b
	inc a ; range size
	ld c, a
	ld a, [wOTPartyCount]

.mod_range
	cp c
	jr c, .got_offset
	sub c
	jr .mod_range

.got_offset
	add b
	call SafariGauntlet_AdjustTrainerLevelForDifficulty
	pop hl
	ret

.use_original
	ld a, c
	pop hl
	ret

.LevelRanges:
	db 50, 53
	db 52, 55
	db 54, 57
	db 56, 59
	db 57, 60

SafariGauntlet_AdjustTrainerLevelForDifficulty:
	ld b, a
	ld a, [wSafariGauntletSettings]
	and SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_MASK
	cp SAFARI_GAUNTLET_DIFFICULTY_CASUAL << SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_SHIFT
	jr z, .casual
	cp SAFARI_GAUNTLET_DIFFICULTY_HARD << SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_SHIFT
	jr z, .hard
	ld a, b
	ret

.casual
	ld a, b
	sub 3
	ret

.hard
	ld a, b
	add 3
	ret

SafariGauntlet_LoadCuratedTrainerParty:
	ld a, [wSafariGauntletStep]
	cp SAFARI_GAUNTLET_STEP_ROUND1
	jr z, .round1
	cp SAFARI_GAUNTLET_STEP_ROUND2
	jr z, .round2
	cp SAFARI_GAUNTLET_STEP_ROUND3
	jr z, .round3
	cp SAFARI_GAUNTLET_STEP_ROUND4
	jr z, .round4
	ret

.round1
	ld hl, SafariGauntletTrainerTeamsRound1
	ld d, 3
	ld e, 2 + 3 * 2
	jr .find_team

.round2
	ld hl, SafariGauntletTrainerTeamsRound2
	ld d, 4
	ld e, 2 + 4 * 2
	jr .find_team

.round3
	ld hl, SafariGauntletTrainerTeamsRound3
	ld d, 5
	ld e, 2 + 5 * 2
	jr .find_team

.round4
	ld hl, SafariGauntletTrainerTeamsRound4
	ld d, 5
	ld e, 2 + 5 * 2

.find_team
	ld c, 16

.find_loop
	ld a, [wOtherTrainerClass]
	cp [hl]
	jr nz, .skip_entry
	inc hl
	ld a, [wOtherTrainerID]
	cp [hl]
	jr z, .found
	dec hl

.skip_entry
	ld a, e

.skip_byte
	inc hl
	dec a
	jr nz, .skip_byte
	dec c
	jr nz, .find_loop
	ret

.found
	inc hl
	xor a
	ld [wOTPartyCount], a
	ld [wOtherTrainerType], a
	ld b, d

.load_loop
	push bc
	push de
	ld a, 1
	call SafariGauntlet_AdjustTrainerLevelForStage
	ld [wCurPartyLevel], a
	ld a, [hli]
	ld [wCurPartySpecies], a
	ld a, [hli]
	ld [wCurForm], a
	ld a, OTPARTYMON
	ld [wMonType], a
	push hl
	farcall TryAddMonToParty
	pop hl
	pop de
	pop bc
	dec b
	jr nz, .load_loop
	ret

SafariGauntletTrainerTeamsRound1:
	db YOUNGSTER, JOEY1
	dp RATTATA, PLAIN_FORM
	dp FURRET, PLAIN_FORM
	dp PIDGEOTTO, PLAIN_FORM
	db CAMPER, TODD1
	dp SANDSHREW, PLAIN_FORM
	dp IVYSAUR, PLAIN_FORM
	dp GROWLITHE, PLAIN_FORM
	db PICNICKER, GINA1
	dp HOPPIP, PLAIN_FORM
	dp BAYLEEF, PLAIN_FORM
	dp MARILL, PLAIN_FORM
	db LASS, DANA1
	dp CLEFAIRY, PLAIN_FORM
	dp JIGGLYPUFF, PLAIN_FORM
	dp TEDDIURSA, PLAIN_FORM
	db SCHOOLBOY, JACK1
	dp MAGNEMITE, PLAIN_FORM
	dp KADABRA, PLAIN_FORM
	dp NOCTOWL, PLAIN_FORM
	db BUG_CATCHER, WADE1
	dp BUTTERFREE, PLAIN_FORM
	dp BEEDRILL, PLAIN_FORM
	dp YANMA, PLAIN_FORM
	db BIRD_KEEPER, JOSE1
	dp SPEAROW, PLAIN_FORM
	dp DODUO, PLAIN_FORM
	dp NATU, PLAIN_FORM
	db HIKER, ANTHONY1
	dp GEODUDE, PLAIN_FORM
	dp MACHOKE, PLAIN_FORM
	dp ONIX, PLAIN_FORM
	db SAILOR, HUEY1
	dp POLIWHIRL, PLAIN_FORM
	dp SEADRA, PLAIN_FORM
	dp CHINCHOU, PLAIN_FORM
	db SUPER_NERD, STAN
	dp VOLTORB, PLAIN_FORM
	dp HAUNTER, PLAIN_FORM
	dp PORYGON, PLAIN_FORM
	db POKEMANIAC, BRENT1
	dp CUBONE, PLAIN_FORM
	dp LICKITUNG, PLAIN_FORM
	dp KANGASKHAN, PLAIN_FORM
	db BEAUTY, VICTORIA
	dp PERSIAN, PLAIN_FORM
	dp BELLOSSOM, PLAIN_FORM
	dp RAPIDASH, PLAIN_FORM
	db POKEFANM, DEREK1
	dp SNUBBULL, PLAIN_FORM
	dp GIRAFARIG, PLAIN_FORM
	dp PIKACHU, PLAIN_FORM
	db PSYCHIC_T, NATHAN
	dp DROWZEE, PLAIN_FORM
	dp XATU, PLAIN_FORM
	dp MISDREAVUS, PLAIN_FORM
	db FIREBREATHER, OTIS
	dp VULPIX, PLAIN_FORM
	dp MAGMAR, PLAIN_FORM
	dp FLAREON, PLAIN_FORM
	db BLACKBELT_T, KENJI1
	dp MANKEY, PLAIN_FORM
	dp HITMONCHAN, PLAIN_FORM
	dp HERACROSS, PLAIN_FORM

SafariGauntletTrainerTeamsRound2:
	db YOUNGSTER, JOEY3
	dp RATICATE, PLAIN_FORM
	dp FURRET, PLAIN_FORM
	dp PIDGEOT, PLAIN_FORM
	dp TAUROS, PLAIN_FORM
	db CAMPER, TODD3
	dp SANDSLASH, PLAIN_FORM
	dp VENUSAUR, PLAIN_FORM
	dp ARCANINE, PLAIN_FORM
	dp EXEGGUTOR, PLAIN_FORM
	db PICNICKER, GINA3
	dp JUMPLUFF, PLAIN_FORM
	dp MEGANIUM, PLAIN_FORM
	dp AZUMARILL, PLAIN_FORM
	dp POLITOED, PLAIN_FORM
	db PICNICKER, LIZ3
	dp WEEPINBELL, PLAIN_FORM
	dp VILEPLUME, PLAIN_FORM
	dp NIDOQUEEN, PLAIN_FORM
	dp BLISSEY, PLAIN_FORM
	db SCHOOLBOY, ALAN3
	dp MAGNETON, PLAIN_FORM
	dp ALAKAZAM, PLAIN_FORM
	dp NOCTOWL, PLAIN_FORM
	dp AMPHAROS, PLAIN_FORM
	db BUG_CATCHER, WADE3
	dp BUTTERFREE, PLAIN_FORM
	dp BEEDRILL, PLAIN_FORM
	dp SCYTHER, PLAIN_FORM
	dp HERACROSS, PLAIN_FORM
	db BIRD_KEEPER, VANCE1
	dp FEAROW, PLAIN_FORM
	dp DODRIO, PLAIN_FORM
	dp XATU, PLAIN_FORM
	dp SKARMORY, PLAIN_FORM
	db HIKER, ANTHONY3
	dp GRAVELER, PLAIN_FORM
	dp MACHAMP, PLAIN_FORM
	dp STEELIX, PLAIN_FORM
	dp PILOSWINE, PLAIN_FORM
	db SAILOR, HUEY2
	dp POLIWRATH, PLAIN_FORM
	dp KINGDRA, PLAIN_FORM
	dp LANTURN, PLAIN_FORM
	dp OCTILLERY, PLAIN_FORM
	db SUPER_NERD, ERIC
	dp ELECTRODE, PLAIN_FORM
	dp GENGAR, PLAIN_FORM
	dp PORYGON2, PLAIN_FORM
	dp WEEZING, PLAIN_FORM
	db POKEMANIAC, BRENT3
	dp MAROWAK, PLAIN_FORM
	dp LICKILICKY, PLAIN_FORM
	dp KANGASKHAN, PLAIN_FORM
	dp URSARING, PLAIN_FORM
	db SCIENTIST, DENNETT
	dp MUK, PLAIN_FORM
	dp MAGNETON, PLAIN_FORM
	dp PORYGON2, PLAIN_FORM
	dp SCIZOR, PLAIN_FORM
	db POKEFANM, DEREK3
	dp GRANBULL, PLAIN_FORM
	dp GIRAFARIG, PLAIN_FORM
	dp RAICHU, PLAIN_FORM
	dp ESPEON, PLAIN_FORM
	db PSYCHIC_T, PHIL
	dp HYPNO, PLAIN_FORM
	dp XATU, PLAIN_FORM
	dp SLOWKING, PLAIN_FORM
	dp WOBBUFFET, PLAIN_FORM
	db FIREBREATHER, NED
	dp NINETALES, PLAIN_FORM
	dp MAGMAR, PLAIN_FORM
	dp HOUNDOOM, PLAIN_FORM
	dp FLAREON, PLAIN_FORM
	db BLACKBELT_T, YOSHI
	dp PRIMEAPE, PLAIN_FORM
	dp HITMONLEE, PLAIN_FORM
	dp HITMONCHAN, PLAIN_FORM
	dp HITMONTOP, PLAIN_FORM

SafariGauntletTrainerTeamsRound3:
	db YOUNGSTER, JOEY5
	dp RATICATE, PLAIN_FORM
	dp AMBIPOM, PLAIN_FORM
	dp PIDGEOT, PLAIN_FORM
	dp TAUROS, PLAIN_FORM
	dp KANGASKHAN, PLAIN_FORM
	db CAMPER, TODD5
	dp SANDSLASH, PLAIN_FORM
	dp VENUSAUR, PLAIN_FORM
	dp ARCANINE, PLAIN_FORM
	dp EXEGGUTOR, PLAIN_FORM
	dp RHYDON, PLAIN_FORM
	db PICNICKER, GINA5
	dp JUMPLUFF, PLAIN_FORM
	dp MEGANIUM, PLAIN_FORM
	dp AZUMARILL, PLAIN_FORM
	dp POLITOED, PLAIN_FORM
	dp BELLOSSOM, PLAIN_FORM
	db PICNICKER, TIFFANY3
	dp CLEFABLE, PLAIN_FORM
	dp WIGGLYTUFF, PLAIN_FORM
	dp URSARING, PLAIN_FORM
	dp BLISSEY, PLAIN_FORM
	dp MILTANK, PLAIN_FORM
	db SCHOOLBOY, ALAN5
	dp MAGNETON, PLAIN_FORM
	dp ALAKAZAM, PLAIN_FORM
	dp AMPHAROS, PLAIN_FORM
	dp PORYGON2, PLAIN_FORM
	dp ELECTABUZZ, PLAIN_FORM
	db BUG_CATCHER, WADE5
	dp BUTTERFREE, PLAIN_FORM
	dp BEEDRILL, PLAIN_FORM
	dp SCIZOR, PLAIN_FORM
	dp HERACROSS, PLAIN_FORM
	dp YANMEGA, PLAIN_FORM
	db BIRD_KEEPER, VANCE3
	dp PIDGEOT, PLAIN_FORM
	dp DODRIO, PLAIN_FORM
	dp XATU, PLAIN_FORM
	dp SKARMORY, PLAIN_FORM
	dp GLISCOR, PLAIN_FORM
	db HIKER, ANTHONY5
	dp GOLEM, PLAIN_FORM
	dp MACHAMP, PLAIN_FORM
	dp STEELIX, PLAIN_FORM
	dp PILOSWINE, PLAIN_FORM
	dp DONPHAN, PLAIN_FORM
	db SAILOR, HUEY4
	dp POLIWRATH, PLAIN_FORM
	dp KINGDRA, PLAIN_FORM
	dp LANTURN, PLAIN_FORM
	dp OCTILLERY, PLAIN_FORM
	dp LAPRAS, PLAIN_FORM
	db PSYCHIC_T, GILBERT
	dp GENGAR, PLAIN_FORM
	dp ESPEON, PLAIN_FORM
	dp SLOWKING, PLAIN_FORM
	dp WOBBUFFET, PLAIN_FORM
	dp STARMIE, PLAIN_FORM
	db COOLTRAINERF, REENA1
	dp RAICHU, PLAIN_FORM
	dp NIDOQUEEN, PLAIN_FORM
	dp RAPIDASH, PLAIN_FORM
	dp VAPOREON, PLAIN_FORM
	dp SCIZOR, PLAIN_FORM
	db SCIENTIST, DENNETT
	dp MUK, PLAIN_FORM
	dp MAGNETON, PLAIN_FORM
	dp PORYGON2, PLAIN_FORM
	dp WEEZING, PLAIN_FORM
	dp MAGCARGO, PLAIN_FORM
	db HEX_MANIAC, NATALIE
	dp MISDREAVUS, PLAIN_FORM
	dp HOUNDOOM, PLAIN_FORM
	dp UMBREON, PLAIN_FORM
	dp GENGAR, PLAIN_FORM
	dp MISMAGIUS, PLAIN_FORM
	db BAKER, MARGARET
	dp WIGGLYTUFF, PLAIN_FORM
	dp BLISSEY, PLAIN_FORM
	dp MILTANK, PLAIN_FORM
	dp POLITOED, PLAIN_FORM
	dp CLEFABLE, PLAIN_FORM
	db RICH_BOY, WINSTON
	dp PERSIAN, PLAIN_FORM
	dp TAUROS, PLAIN_FORM
	dp KANGASKHAN, PLAIN_FORM
	dp ESPEON, PLAIN_FORM
	dp DRAGONITE, PLAIN_FORM
	db BATTLE_GIRL, NOZOMI
	dp PRIMEAPE, PLAIN_FORM
	dp HITMONLEE, PLAIN_FORM
	dp HITMONTOP, PLAIN_FORM
	dp HERACROSS, PLAIN_FORM
	dp SCIZOR, PLAIN_FORM

SafariGauntletTrainerTeamsRound4:
	db YOUNGSTER, JOEY5
	dp AMBIPOM, PLAIN_FORM
	dp DUDUNSPARCE, PLAIN_FORM
	dp WYRDEER, PLAIN_FORM
	dp TAUROS, PLAIN_FORM
	dp URSALUNA, PLAIN_FORM
	db CAMPER, TODD5
	dp VENUSAUR, PLAIN_FORM
	dp ARCANINE, PLAIN_FORM
	dp TANGROWTH, PLAIN_FORM
	dp RHYPERIOR, PLAIN_FORM
	dp EXEGGUTOR, PLAIN_FORM
	db PICNICKER, GINA5
	dp MEGANIUM, PLAIN_FORM
	dp JUMPLUFF, PLAIN_FORM
	dp AZUMARILL, PLAIN_FORM
	dp POLITOED, PLAIN_FORM
	dp SYLVEON, PLAIN_FORM
	db PICNICKER, TIFFANY3
	dp CLEFABLE, PLAIN_FORM
	dp BLISSEY, PLAIN_FORM
	dp MILTANK, PLAIN_FORM
	dp GRANBULL, PLAIN_FORM
	dp TOGEKISS, PLAIN_FORM
	db SCHOOLBOY, ALAN5
	dp AMPHAROS, PLAIN_FORM
	dp ALAKAZAM, PLAIN_FORM
	dp ELECTIVIRE, PLAIN_FORM
	dp PORYGON2, PLAIN_FORM
	dp RAICHU, PLAIN_FORM
	db BUG_CATCHER, WADE5
	dp YANMEGA, PLAIN_FORM
	dp SCIZOR, PLAIN_FORM
	dp HERACROSS, PLAIN_FORM
	dp KLEAVOR, PLAIN_FORM
	dp BUTTERFREE, PLAIN_FORM
	db BIRD_KEEPER, VANCE3
	dp PIDGEOT, PLAIN_FORM
	dp SKARMORY, PLAIN_FORM
	dp GLISCOR, PLAIN_FORM
	dp HONCHKROW, PLAIN_FORM
	dp TOGEKISS, PLAIN_FORM
	db HIKER, ANTHONY5
	dp GOLEM, PLAIN_FORM
	dp MACHAMP, PLAIN_FORM
	dp STEELIX, PLAIN_FORM
	dp RHYPERIOR, PLAIN_FORM
	dp URSALUNA, PLAIN_FORM
	db SAILOR, HUEY4
	dp KINGDRA, PLAIN_FORM
	dp LANTURN, PLAIN_FORM
	dp LAPRAS, PLAIN_FORM
	dp OCTILLERY, PLAIN_FORM
	dp GYARADOS, PLAIN_FORM
	db PSYCHIC_T, GILBERT
	dp GENGAR, PLAIN_FORM
	dp ESPEON, PLAIN_FORM
	dp SLOWKING, PLAIN_FORM
	dp STARMIE, PLAIN_FORM
	dp FARIGIRAF, PLAIN_FORM
	db COOLTRAINERF, REENA1
	dp NIDOQUEEN, PLAIN_FORM
	dp VAPOREON, PLAIN_FORM
	dp FLAREON, PLAIN_FORM
	dp JOLTEON, PLAIN_FORM
	dp SCIZOR, PLAIN_FORM
	db SCIENTIST, DENNETT
	dp MUK, PLAIN_FORM
	dp WEEZING, PLAIN_FORM
	dp PORYGON2, PLAIN_FORM
	dp ELECTIVIRE, PLAIN_FORM
	dp MAGMORTAR, PLAIN_FORM
	db HEX_MANIAC, NATALIE
	dp MISMAGIUS, PLAIN_FORM
	dp HOUNDOOM, PLAIN_FORM
	dp UMBREON, PLAIN_FORM
	dp CURSOLA, PLAIN_FORM
	dp GENGAR, PLAIN_FORM
	db BAKER, MARGARET
	dp BLISSEY, PLAIN_FORM
	dp WIGGLYTUFF, PLAIN_FORM
	dp MILTANK, PLAIN_FORM
	dp CLEFABLE, PLAIN_FORM
	dp TOGEKISS, PLAIN_FORM
	db RICH_BOY, WINSTON
	dp PERSIAN, PLAIN_FORM
	dp ESPEON, PLAIN_FORM
	dp DRAGONITE, PLAIN_FORM
	dp TYRANITAR, PLAIN_FORM
	dp ARCANINE, PLAIN_FORM
	db BATTLE_GIRL, NOZOMI
	dp ANNIHILAPE, PLAIN_FORM
	dp HERACROSS, PLAIN_FORM
	dp SNEASLER, PLAIN_FORM
	dp HITMONTOP, PLAIN_FORM
	dp MACHAMP, PLAIN_FORM

SetDynamicForm:
; Adjust form of mon in bc dynamically based on context if no form is set.
; If no dynamic setting applies, b is set to plain form.
	ld a, b
	and FORM_MASK
	ret nz

	; First, set b to base form in case no special case applies.
	inc b ; ld b, PLAIN_FORM ; (don't overwrite other parts of b)

	; Check for Arbok.
	assert !HIGH(ARBOK)
	bit MON_EXTSPECIES_F, b
	ret nz
	ld a, c
	cp LOW(ARBOK)
	ret nz

	push bc
	call RegionCheck
	ld a, e
	pop bc

	and a
	assert ARBOK_JOHTO_FORM == ARBOK_KANTO_FORM - 1
	ld a, ARBOK_KANTO_FORM
	jr nz, .got_arbok_form
	dec a
.got_arbok_form
	or b
	ld b, a
	ret

Battle_GetTrainerName::
	ld a, [wInBattleTowerBattle]
	and a
	ld hl, wOTPlayerName
	ld a, BANK(Battle_GetTrainerName) ; make FarCopyBytes act like CopyBytes
	ld [wTrainerGroupBank], a
	jr nz, CopyTrainerName

	ld a, [wOtherTrainerID]
	ld b, a
	ld a, [wOtherTrainerClass]
	ld c, a

GetTrainerName::
	dec c
	push bc
	ld b, 0
	ld hl, TrainerGroups
	add hl, bc
	add hl, bc
	add hl, bc
	ld a, [hli]
	ld [wTrainerGroupBank], a
	ld a, [hli]
	ld h, [hl]
	ld l, a
	pop bc
	call SkipTrainerParties
	jr CopyTrainerName

SkipTrainerParties:
; Skips b-1 parties
	; Size of the current party.
	call GetNextTrainerDataByte
	dec b
	ret z

	; Skip all of it.
	add l
	ld l, a
	adc h
	sub l
	ld h, a
	jr SkipTrainerParties

CopyTrainerName:
	ld de, wStringBuffer1
	push de
	ld bc, NAME_LENGTH
	ld a, [wTrainerGroupBank]
	call FarCopyBytes
	pop de
	ret

SetTrainerBattleLevel:
	ld a, 255
	ld [wCurPartyLevel], a

	ld a, [wInBattleTowerBattle]
	and a
	ret nz

	ld a, [wLinkMode]
	and a
	ret nz

	call FindTrainerData

	inc hl
	call GetNextTrainerDataByte

	farcall AdjustLevelForBadges
	ld [wCurPartyLevel], a
	ret

FindTrainerData:
; Returns party size in bytes excluding trainer name in b.
	farcall SetBadgeBaseLevel

	ld a, [wOtherTrainerClass]
	dec a
	ld c, a
	ld b, 0
	ld hl, TrainerGroups
	add hl, bc
	add hl, bc
	add hl, bc
	ld a, [hli]
	ld [wTrainerGroupBank], a
	ld a, [hli]
	ld h, [hl]
	ld l, a

	ld a, [wOtherTrainerID]
	ld b, a
	; fallthrough
SkipTrainerPartiesAndName:
	call SkipTrainerParties
	ld b, a

.skip_name
	dec b
	call GetNextTrainerDataByte
	cp '@'
	jr nz, .skip_name
	ret

GetNextTrainerDataByte:
	ld a, [wTrainerGroupBank]
	call GetFarByte
	inc hl
	ret

; must come before the EVSpreads table below, to define
; the EV_SPREAD_* values and NUM_EV_SPREADS total
INCLUDE "data/trainers/parties.asm"


SECTION "DV and EV Spreads", ROMX

WriteTrainerDVs:
; Writes DVs to de with the DV spread index in a.
	push hl
	push de
	push bc

	push de
	ld hl, DVSpreads
	ld bc, NUM_STATS / 2 ; 2 DVs per byte
	rst AddNTimes
	rst CopyBytes
	pop hl
	jmp PopBCDEHL

WriteTrainerEVs:
; Writes EVs to de with the EV spread index in a.
; For classic EVs, writes (EV total / 2) to all stats.
; For modern EVs, writes the table data directly.
	push hl
	push de
	push bc

	push de
	ld hl, EVSpreads
	ld bc, NUM_STATS
	rst AddNTimes
	rst CopyBytes
	pop hl

	; If modern EVs are enabled, we're done.
	ld a, [wInitialOptions2]
	and EV_OPTMASK
	cp EVS_OPT_MODERN
	jr z, .done

	; Otherwise, calculate total and set EV to total/2.
	push hl
	farcall _GetEVTotal
	pop hl
	srl b
	rr c
	ld a, c
	cp MODERN_MAX_EV + 1
	jr c, .got_evs
	ld a, MODERN_MAX_EV
.got_evs
	ld bc, NUM_STATS
	rst ByteFill

.done
	jmp PopBCDEHL

DVSpreads:
	table_width NUM_STATS / 2
	for n, NUM_DV_SPREADS
		; each DV_SPREAD_*_HP/ATK/DEF/SPE/SAT/SDF is implicitly defined
		; by `tr_dvs` (see data/trainers/parties.asm)
		for x, 1, EACH_SPREAD_STAT, 2
			def y = x + 1
			dn DV_SPREAD_{d:n}_{STATS{x}}, DV_SPREAD_{d:n}_{STATS{y}}
		endr
	endr
	assert_table_length NUM_DV_SPREADS

EVSpreads:
	table_width NUM_STATS
	for n, NUM_EV_SPREADS
		; each EV_SPREAD_*_HP/ATK/DEF/SPE/SAT/SDF is implicitly defined
		; by `tr_evs` (see data/trainers/parties.asm)
		for x, 1, EACH_SPREAD_STAT
			db EV_SPREAD_{d:n}_{STATS{x}}
		endr
	endr
	assert_table_length NUM_EV_SPREADS

ENDSECTION
