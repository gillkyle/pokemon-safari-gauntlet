local log_path = "/tmp/safari-gauntlet-loss-keep-policy.log"
local screenshot_path = "/tmp/safari-gauntlet-loss-keep-policy.png"
local pc_menu_screenshot = "/tmp/safari-gauntlet-loss-keep-pc-menu.png"
local bills_menu_screenshot = "/tmp/safari-gauntlet-loss-keep-bills-pc-menu.png"
local storage_text_screenshot = "/tmp/safari-gauntlet-loss-keep-storage-text.png"
local box_ui_screenshot = "/tmp/safari-gauntlet-loss-keep-box-ui.png"

local repo = "/Users/kyle/dev/pokecrystal"
local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)
local B = bit(KEY.B)
local START = bit(KEY.START)
local UP = bit(KEY.UP)
local DOWN = bit(KEY.DOWN)
local LEFT = bit(KEY.LEFT)
local RIGHT = bit(KEY.RIGHT)

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local GROUP_SAFARI_ZONE = 32
local MAP_SAFARI_ZONE_HUB = 1
local SAFARI_GAUNTLET_STEP_DRAFT = 1
local SAFARI_GAUNTLET_STEP_ROUND1 = 2
local BATTLEMODE_TRAINER = 2
local OW_UP = 0x04

local PARTYMON_STRUCT_LENGTH = 48
local MON_SPECIES = 0
local MON_FORM = 21
local MON_PP = 22
local MON_LEVEL = 31
local MON_HP = 34
local MON_MAXHP = 36
local MON_ATK = 38
local MON_DEF = 40
local MON_SPE = 42
local MON_SAT = 44
local MON_SDF = 46

local PIDGEY = 16
local EEVEE = 133
local CHARIZARD = 6
local RATTATA = 19
local GEODUDE = 74
local VAPOREON = 134
local SENTRET = 161

local f = assert(io.open(log_path, "w"))

local function read_file(path)
	local fh = assert(io.open(path, "r"))
	local text = fh:read("*a")
	fh:close()
	return text
end

local function load_symbols()
	local symbols = {}
	for line in read_file(repo .. "/polishedcrystal-3.2.3.sym"):gmatch("[^\n]+") do
		local bank, addr, name = line:match("^(%x%x):(%x%x%x%x)%s+([%w_.$]+)$")
		if bank and addr and name then
			symbols[name] = tonumber(addr, 16)
			symbols[name .. "_bank"] = tonumber(bank, 16)
		end
	end
	return symbols
end

local S = load_symbols()
local W = {
	map_group = S.wMapGroup,
	map_number = S.wMapNumber,
	y = S.wYCoord,
	x = S.wXCoord,
	map_status = S.wMapStatus,
	script_flags = S.wScriptFlags,
	script_mode = S.wScriptMode,
	script_text_addr = S.wScriptTextAddr,
	player_direction = S.wPlayerDirection,
	options2 = S.wOptions2,
	crash_code = S.hCrashCode,
	party_count = S.wPartyCount,
	party_mon1 = S.wPartyMon1,
	party_menu_cursor = S.wPartyMenuCursor,
	battle_mode = S.wBattleMode,
	battle_result = S.wBattleResult,
	battle_ended = S.wBattleEnded,
	battle_mon_hp = S.wBattleMonHP,
	battle_mon_max_hp = S.wBattleMonMaxHP,
	enemy_hp = S.wEnemyMonHP,
	cursor_pos = S.wBillsPC_CursorPos,
	temp_species = S.wTempMonSpecies,
	temp_level = S.wTempMonLevel,
	safari_time = S.wSafariTimeRemaining,
	step = S.wSafariGauntletStep,
	runs_hi = S.wSafariGauntletRuns,
	losses_hi = S.wSafariGauntletLosses,
	bills_box_list = S.wBillsPC_BoxList,
	loss_keep_prompt = S.SafariGauntletLossKeepPromptText,
	loss_keep_stored = S.SafariGauntletLossKeepStoredText,
}

for name, value in pairs(W) do
	assert(value ~= nil, "missing symbol " .. name)
end

local observed_loss_prompt = false
local observed_loss_stored = false

local function wram_offset(addr)
	if addr >= 0xd000 and addr <= 0xdfff and emu.memory and emu.memory.wram then
		return 0x1000 + (addr - 0xd000)
	elseif addr >= 0xc000 and addr <= 0xcfff and emu.memory and emu.memory.wram then
		return addr - 0xc000
	end
	return nil
end

local function read8(addr)
	local offset = wram_offset(addr)
	if offset then
		return emu.memory.wram:read8(offset)
	end
	return emu:read8(addr)
end

local function write8(addr, value)
	local offset = wram_offset(addr)
	if offset then
		emu.memory.wram:write8(offset, value & 0xff)
	else
		emu:write8(addr, value & 0xff)
	end
end

local function read16(hi)
	return read8(hi) * 256 + read8(hi + 1)
end

local function read16le(lo)
	return read8(lo) + read8(lo + 1) * 256
end

local function write16(hi, value)
	write8(hi, value // 256)
	write8(hi + 1, value % 256)
end

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function state_line(prefix)
	log(string.format(
		"%s crash=%02x map=%d/%d xy=%d,%d status=%02x script=%02x/%02x text=%04x party=%d lead=%d level=%d step=%d battle=%d runs=%d losses=%d",
		prefix,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.map_status),
		read8(W.script_flags),
		read8(W.script_mode),
		read16le(W.script_text_addr),
		read8(W.party_count),
		read8(W.party_mon1 + MON_SPECIES),
		read8(W.party_mon1 + MON_LEVEL),
		read8(W.step),
		read8(W.battle_mode),
		read16(W.runs_hi),
		read16(W.losses_hi)
	))
end

local function apply_keys(keys)
	emu:clearKeys(0xffffffff)
	if keys ~= 0 then
		emu:addKeys(keys)
	end
end

local function fail(reason)
	state_line(reason)
	emu:screenshot(screenshot_path)
	log("screenshot=" .. screenshot_path)
	apply_keys(0)
	error(reason)
end

local function force_party_fainted()
	for i = 0, 5 do
		local base = W.party_mon1 + i * PARTYMON_STRUCT_LENGTH
		write16(base + MON_HP, 0)
	end
	write16(W.battle_mon_hp, 0)
	write8(W.battle_result, 1)
	write8(W.battle_ended, 1)
	local enemy_hp = read16(W.enemy_hp)
	if enemy_hp == 0 then
		write16(W.enemy_hp, 999)
	end
end

local loss_forcing = false
local function run_frames(keys, frames)
	apply_keys(keys)
	for _ = 1, frames do
		write8(W.options2, read8(W.options2) & 0x3f)
		if loss_forcing then
			force_party_fainted()
		end
		emu:runFrame()
		if read8(W.crash_code) ~= 0 then
			fail("FAILED_CRASH")
		end
		local text_addr = read16le(W.script_text_addr)
		if text_addr == W.loss_keep_prompt then
			observed_loss_prompt = true
		elseif text_addr == W.loss_keep_stored then
			observed_loss_stored = true
		end
	end
	apply_keys(0)
end

local function pulse(keys, down_frames, up_frames)
	run_frames(keys, down_frames or 8)
	run_frames(0, up_frames or 22)
end

local function in_hub()
	return read8(W.map_group) == GROUP_BATTLE_FACTORY
		and read8(W.map_number) == MAP_BATTLE_FACTORY_1F
end

local function in_draft()
	return read8(W.map_group) == GROUP_SAFARI_ZONE
		and read8(W.map_number) == MAP_SAFARI_ZONE_HUB
		and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT
end

local function boot_to_hub()
	for _ = 1, 80 do
		pulse(START)
		pulse(A)
		pulse(B)
		pulse(A)
		if in_hub() then
			break
		end
	end

	local hub_frame = nil
	for i = 1, 9000 do
		run_frames(0, 1)
		if in_hub() and not hub_frame then
			hub_frame = emu:currentFrame()
			state_line("hub_seen")
		end
		if in_hub()
			and hub_frame
			and emu:currentFrame() - hub_frame > 180
			and read8(W.map_status) == 2
			and read8(W.script_flags) == 0
			and read8(W.script_mode) == 0
			and read8(W.party_count) == 1 then
			state_line("hub_ready")
			return
		end
		if i % 300 == 0 then
			state_line("boot_wait")
		end
	end
	fail("FAILED_BOOT_TO_HUB")
end

local function move_toward(tx, ty)
	if read8(W.x) < tx then
		return RIGHT
	elseif read8(W.x) > tx then
		return LEFT
	elseif read8(W.y) < ty then
		return DOWN
	elseif read8(W.y) > ty then
		return UP
	end
	return 0
end

local function stand_at_reception()
	for i = 1, 2400 do
		local keys = move_toward(12, 8)
		if keys == 0 then
			write8(W.player_direction, OW_UP)
			state_line("reception_ready")
			return
		end
		run_frames(keys, 1)
		if i % 300 == 0 then
			state_line("move_wait")
		end
	end
	fail("FAILED_REACH_RECEPTION")
end

local function stand_at_pc()
	for i = 1, 2400 do
		local keys = move_toward(5, 8)
		if keys == 0 then
			write8(W.player_direction, OW_UP)
			state_line("pc_ready")
			return
		end
		run_frames(keys, 1)
		if i % 300 == 0 then
			state_line("pc_move_wait")
		end
	end
	fail("FAILED_REACH_PC")
end

local function wait_for_idle()
	for i = 1, 1800 do
		if in_hub()
			and read8(W.battle_mode) == 0
			and read8(W.script_flags) == 0
			and read8(W.script_mode) == 0 then
			state_line("hub_idle_after_loss")
			return
		end
		pulse(A)
		if i % 120 == 0 then
			state_line("idle_wait")
		end
	end
	fail("FAILED_IDLE_AFTER_LOSS")
end

local function open_pc_to_box_ui()
	stand_at_pc()
	pulse(A, 10, 70)
	emu:screenshot(pc_menu_screenshot)
	log("pc_menu_screenshot=" .. pc_menu_screenshot)
	pulse(A, 10, 70)
	emu:screenshot(bills_menu_screenshot)
	log("bills_menu_screenshot=" .. bills_menu_screenshot)
	pulse(A, 10, 360)
	emu:screenshot(storage_text_screenshot)
	log("storage_text_screenshot=" .. storage_text_screenshot)
	pulse(A, 10, 600)
	pulse(A, 10, 600)
	emu:screenshot(box_ui_screenshot)
	log("box_ui_screenshot=" .. box_ui_screenshot)
	state_line("box_ui_ready")
end

local function verify_selected_box_mon(expected_species, expected_level, label)
	for i = 1, 900 do
		if read8(W.temp_species) == expected_species and read8(W.temp_level) == expected_level then
			state_line("verified_box_level_" .. label)
			return
		end
		run_frames(0, 1)
		if i % 120 == 0 then
			state_line("box_level_wait_" .. label)
		end
	end
	fail(string.format(
		"FAILED_BOX_LEVEL_%s_EXPECTED_%d_L%d_GOT_%d_L%d",
		label,
		expected_species,
		expected_level,
		read8(W.temp_species),
		read8(W.temp_level)
	))
end

local function start_gauntlet()
	for i = 1, 1800 do
		if in_draft() then
			state_line("draft_started")
			return
		end
		pulse(A)
		if i % 120 == 0 then
			state_line("start_wait")
		end
	end
	fail("FAILED_START_DRAFT")
end

local function copy_lead_to_slot(slot_index)
	local dest = W.party_mon1 + slot_index * PARTYMON_STRUCT_LENGTH
	for i = 0, PARTYMON_STRUCT_LENGTH - 1 do
		write8(dest + i, read8(W.party_mon1 + i))
	end
end

local function set_slot(slot_index, species, level)
	local base = W.party_mon1 + slot_index * PARTYMON_STRUCT_LENGTH
	level = level or 55
	write8(base + MON_SPECIES, species)
	write8(base + MON_FORM, 0)
	write8(base + MON_LEVEL, level)
	write16(base + MON_HP, 120)
	write16(base + MON_MAXHP, 120)
	write16(base + MON_ATK, 80)
	write16(base + MON_DEF, 80)
	write16(base + MON_SPE, 80)
	write16(base + MON_SAT, 80)
	write16(base + MON_SDF, 80)
	for move = 0, 3 do
		write8(base + MON_PP + move, 40)
	end
end

local function seed_full_loss_party()
	for slot = 1, 5 do
		copy_lead_to_slot(slot)
	end
	set_slot(0, PIDGEY, 55)
	set_slot(1, EEVEE, 35)
	set_slot(2, CHARIZARD, 35)
	set_slot(3, RATTATA, 55)
	set_slot(4, GEODUDE, 55)
	set_slot(5, SENTRET, 55)
	write8(W.party_count, 6)
	state_line("seeded_full_loss_party")
end

local function finish_draft_to_round1()
	write16(W.safari_time, 1)
	for i = 1, 12000 do
		if in_hub() and read8(W.step) == SAFARI_GAUNTLET_STEP_ROUND1 and read8(W.party_count) == 6 then
			state_line("round1_ready_after_seeded_draft")
			return
		end
		if in_draft() then
			if read8(W.script_flags) ~= 0 or read8(W.script_mode) ~= 0 then
				pulse(A)
			else
				local keys = UP
				if i % 120 > 60 then
					keys = DOWN
				end
				run_frames(keys, 1)
			end
		else
			pulse(A)
		end
		if i % 300 == 0 then
			state_line("finish_draft_wait")
		end
	end
	fail("FAILED_FINISH_DRAFT")
end

local function box_count(species)
	local count = 0
	for i = 0, 29 do
		local actual = read8(W.bills_box_list + i * 2)
		if actual == 0xff then
			break
		end
		if actual == species then
			count = count + 1
		end
	end
	return count
end

local function start_round1_and_lose()
	local start_runs = read16(W.runs_hi)
	local start_losses = read16(W.losses_hi)
	local saw_battle = false
	local saw_prompt = false
	local saw_stored = false

	stand_at_reception()
	for i = 1, 18000 do
		if read8(W.battle_mode) == BATTLEMODE_TRAINER then
			saw_battle = true
			loss_forcing = true
		else
			loss_forcing = false
		end

		local text_addr = read16le(W.script_text_addr)
		if text_addr == W.loss_keep_prompt then
			saw_prompt = true
			write8(W.party_menu_cursor, 1)
		elseif text_addr == W.loss_keep_stored then
			saw_stored = true
		end

		if in_hub()
			and read16(W.runs_hi) == start_runs + 1
			and read16(W.losses_hi) == start_losses + 1
			and read8(W.battle_mode) == 0 then
			if not saw_battle then
				fail("FAILED_NO_TRAINER_BATTLE")
			end
			log(string.format(
				"loss_text_seen prompt=%s stored=%s",
				tostring(saw_prompt or observed_loss_prompt),
				tostring(saw_stored or observed_loss_stored)
			))
			if read8(W.party_count) ~= 1 then
				fail("FAILED_PARTY_COUNT_" .. read8(W.party_count))
			end
			if read8(W.party_mon1 + MON_SPECIES) ~= PIDGEY then
				fail("FAILED_CARRIED_SPECIES_" .. read8(W.party_mon1 + MON_SPECIES))
			end
			wait_for_idle()
			open_pc_to_box_ui()
			if box_count(EEVEE) ~= 3 then
				fail("FAILED_EEVEE_BOX_COUNT_" .. box_count(EEVEE))
			end
			if box_count(CHARIZARD) == 0 then
				fail("FAILED_CHARIZARD_NOT_BOXED")
			end
			pulse(DOWN, 10, 180)
			pulse(DOWN, 10, 180)
			verify_selected_box_mon(EEVEE, 55, "protected_eevee")
			pulse(RIGHT, 10, 180)
			verify_selected_box_mon(CHARIZARD, 55, "protected_charizard")
			if box_count(PIDGEY) ~= 0 then
				fail("FAILED_SELECTED_MON_BOXED")
			end
			if box_count(RATTATA) ~= 0 or box_count(GEODUDE) ~= 0 or box_count(SENTRET) ~= 0 then
				fail("FAILED_UNPROTECTED_RUN_MON_BOXED")
			end
			state_line("VERIFIED_LOSS_KEEP_POLICY")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			return
		end

		if in_hub()
			and read8(W.battle_mode) == 0
			and read8(W.script_flags) == 0
			and read8(W.script_mode) == 0
			and read16(W.runs_hi) == start_runs then
			local keys = move_toward(12, 8)
			if keys == 0 then
				write8(W.player_direction, OW_UP)
				pulse(A)
			else
				run_frames(keys, 1)
			end
		else
			pulse(A)
		end
		if i % 300 == 0 then
			state_line("loss_policy_wait")
		end
	end
	fail("FAILED_LOSS_POLICY_TIMEOUT")
end

log("Safari Gauntlet trainer-loss keep-policy verifier loaded")
state_line("initial")
boot_to_hub()
stand_at_reception()
start_gauntlet()
seed_full_loss_party()
finish_draft_to_round1()
start_round1_and_lose()
