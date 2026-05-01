local log_path = "/tmp/safari-gauntlet-run.log"
local screenshot_path = "/tmp/safari-gauntlet-run.png"
local post_draft_screenshot_path = "/tmp/safari-gauntlet-post-draft-return.png"

local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)
local B = bit(KEY.B)
local START = bit(KEY.START)
local RIGHT = bit(KEY.RIGHT)
local UP = bit(KEY.UP)
local DOWN = bit(KEY.DOWN)

local W = {
	map_group = 0xdcac,
	map_number = 0xdcad,
	map_status = 0xd431,
	map_event_status = 0xd432,
	script_flags = 0xd433,
	script_mode = 0xd436,
	script_running = 0xd437,
	script_delay = 0xd460,
	script_text_bank = 0xd461,
	script_text_addr = 0xd462,
	game_logic_paused = 0xcdcc,
	bg_map_mode = 0xffbe,
	cgb_pal_update = 0xffd4,
	script_bank = 0xffeb,
	script_pos = 0xffec,
	crash_code = 0xffe5,
	tilemap = 0xc440,
	options2 = 0xcff5,
	y = 0xdcae,
		x = 0xdcaf,
		player_direction = 0xd4d4,
		player_gender = 0xd47a,
	party_count = 0xdcce,
	battle_mode = 0xd233,
	battle_type = 0xd236,
	enemy_level = 0xd219,
	ot_party_mon1_level = 0xd2aa,
	ot_party_count = 0xd283,
	ot_party_nicknames = 0xd3ed,
	other_trainer_class = 0xd235,
	other_trainer_id = 0xd237,
	cur_battle_mon = 0xd0da,
	cur_party_mon = 0xd10c,
	party_menu_cursor = 0xd0de,
	battle_menu_cursor = 0xd0d8,
	menu_cursor_buffer = 0xce2f,
	menu_cursor_y = 0xce50,
	battle_mon_moves = 0xc747,
	battle_mon_hp = 0xc758,
	battle_mon_max_hp = 0xc75a,
	battle_mon_attack = 0xc75c,
	battle_mon_defense = 0xc75e,
	battle_mon_speed = 0xc760,
	battle_mon_sp_atk = 0xc762,
	battle_mon_sp_def = 0xc764,
	battle_mon_pp = 0xc750,
	enemy_hp = 0xd21c,
	enemy_max_hp = 0xd21e,
	enemy_attack = 0xd220,
	enemy_defense = 0xd222,
	enemy_speed = 0xd224,
	enemy_sp_atk = 0xd226,
	enemy_sp_def = 0xd228,
	enemy_catch_rate = 0xd231,
	safari_balls = 0xdc92,
	num_balls = 0xd90b,
	balls = 0xd90c,
	party_species = 0xdccf,
	party_mon1 = 0xdcd6,
	johto_badges = 0xd7ee,
	bp_hi = 0xdc88,
	runs_hi = 0xdb99,
	wins_hi = 0xdb9b,
	losses_hi = 0xdb9d,
	settings = 0xdba1,
	keep_count = 0xdba2,
	tm_shop_set = 0xdbc6,
	draft_attempts = 0xd7db,
	boss = 0xd7da,
	step = 0xd7dc,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local GROUP_SAFARI_ZONE = 32
local MAP_SAFARI_ZONE_HUB = 1
local SAFARI_GAUNTLET_STEP_DRAFT = 1
local BATTLETYPE_SAFARI = 7
local BATTLEMODE_WILD = 1
local BATTLEMODE_TRAINER = 2
local PARTYMON_HP_OFFSET = 0x22
local PARTYMON_MAX_HP_OFFSET = 0x24
local PARTYMON_PP_OFFSET = 0x16
local PARTYMON_STRUCT_LENGTH = 0x30
local MON_FORM_OFFSET = 0x15
local MON_LEVEL_OFFSET = 0x1f
local MON_NAME_LENGTH = 11
local TEXT_END = 0x53
local POKE_BALL = 1
local GREAT_BALL = 2
local ULTRA_BALL = 3
local MASTER_BALL = 4
local STRUGGLE = 0xff

local f = assert(io.open(log_path, "w"))
local draft_seeded = false
local supplies_seen = false
local single_draft_verified = false
local post_draft_return_seen = false
local victory_stats_seen = false
local trainer_level_seen = {}
local trainer_party_seen = {}
local trainer_seen = {}
local current_trainer_key = nil
local current_trainer_step = nil
local current_trainer_player_level_start = nil
local first_trainer_player_level = nil
local final_trainer_player_level = nil
local trainer_level_gain_total = 0
local trainer_level_gain_by_step = {}
local trainer_growth_summary_logged = false

local function wram_offset(addr)
	if addr >= 0xd000 and addr <= 0xdfff and emu.memory and emu.memory.wram then
		return 0x1000 + (addr - 0xd000) -- WRAM bank 1, where this build links WRAMX symbols.
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

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function read16(hi)
	return read8(hi) * 256 + read8(hi + 1)
end

local function write16(hi, value)
	write8(hi, value // 256)
	write8(hi + 1, value % 256)
end

local function ball_qty(item)
	local count = read8(W.num_balls)
	for i = 0, count - 1 do
		local slot = W.balls + i * 2
		if read8(slot) == item then
			return read8(slot + 1)
		end
	end
	return 0
end

local function check_supplies()
	if supplies_seen then
		return
	end
	if read8(W.party_count) == 0 then
		return
	end
	if ball_qty(MASTER_BALL) >= 1 and ball_qty(POKE_BALL) >= 20 and ball_qty(GREAT_BALL) >= 15 and ball_qty(ULTRA_BALL) >= 10 then
		supplies_seen = true
		log(string.format(
			"SUPPLIES_VERIFIED master=%d poke=%d great=%d ultra=%d",
			ball_qty(MASTER_BALL),
			ball_qty(POKE_BALL),
			ball_qty(GREAT_BALL),
			ball_qty(ULTRA_BALL)
		))
	end
end

local function keep_party_healthy()
	local battle_max = read16(W.battle_mon_max_hp)
	if battle_max > 0 then
		write16(W.battle_mon_max_hp, 999)
		write16(W.battle_mon_hp, 999)
	end
	write16(W.battle_mon_attack, 999)
	write16(W.battle_mon_defense, 999)
	write16(W.battle_mon_speed, 999)
	write16(W.battle_mon_sp_atk, 999)
	write16(W.battle_mon_sp_def, 999)
	for move = 0, 3 do
		write8(W.battle_mon_pp + move, 40)
	end
	local max_hp = read16(W.party_mon1 + PARTYMON_MAX_HP_OFFSET)
	if max_hp > 0 then
		write16(W.party_mon1 + PARTYMON_MAX_HP_OFFSET, 999)
		write16(W.party_mon1 + PARTYMON_HP_OFFSET, 999)
		for move = 0, 3 do
			write8(W.party_mon1 + PARTYMON_PP_OFFSET + move, 40)
		end
	end
end

local function seed_draft_party()
	-- Keep the natural one-mon draft. This verifies the ladder gate no longer
	-- requires an arbitrary four-Pokemon team.
	write8(W.party_count, 1)
	local species = read8(W.party_mon1)
	for i = 0, 5 do
		local addr = W.party_species + i
		if i < 1 then
			write8(addr, species)
		else
			write8(addr, 0xff)
		end
	end
	single_draft_verified = true
end

local function state_line(prefix)
	log(string.format(
			"%s map=%d/%d xy=%d,%d dir=%02x map_status=%02x map_event=%02x script_flags=%02x script_mode=%02x script_running=%02x script_delay=%02x hscript=%02x:%04x text=%02x:%04x bgmode=%02x pal=%02x paused=%02x crash=%02x gender=%d badges=%02x party=%d battle=%d enemy_level=%d ot_level=%d step=%d attempts=%d boss=%d tmset=%d settings=%02x runs=%d wins=%d losses=%d keep=%d bp=%d",
		prefix,
		read8(W.map_group),
			read8(W.map_number),
			read8(W.x),
			read8(W.y),
			read8(W.player_direction),
			read8(W.map_status),
			read8(W.map_event_status),
			read8(W.script_flags),
			read8(W.script_mode),
			read8(W.script_running),
			read8(W.script_delay),
			read8(W.script_bank),
			read8(W.script_pos) + read8(W.script_pos + 1) * 256,
			read8(W.script_text_bank),
			read8(W.script_text_addr) + read8(W.script_text_addr + 1) * 256,
			read8(W.bg_map_mode),
			read8(W.cgb_pal_update),
			read8(W.game_logic_paused),
			read8(W.crash_code),
			read8(W.player_gender),
		read8(W.johto_badges),
		read8(W.party_count),
		read8(W.battle_mode),
		read8(W.enemy_level),
		read8(W.ot_party_mon1_level),
		read8(W.step),
		read8(W.draft_attempts),
		read8(W.boss),
		read8(W.tm_shop_set),
		read8(W.settings),
		read16(W.runs_hi),
		read16(W.wins_hi),
		read16(W.losses_hi),
		read8(W.keep_count),
		read16(W.bp_hi)
	))
end

local function tile_sequence_seen(sequence)
	for y = 0, 17 do
		for x = 0, 20 - #sequence do
			local matched = true
			for i, tile in ipairs(sequence) do
				if read8(W.tilemap + y * 20 + x + i - 1) ~= tile then
					matched = false
					break
				end
			end
			if matched then
				return true
			end
		end
	end
	return false
end

local function bsod_seen()
	return tile_sequence_seen({ 0x84, 0x91, 0x91, 0x8e, 0x91 }) -- ERROR
end

local TRAINER_LEVEL_RANGES = {
	[2] = { 50, 53 },
	[3] = { 52, 55 },
	[4] = { 54, 57 },
	[5] = { 56, 59 },
	[6] = { 57, 60 },
}

local TRAINER_PARTY_MINIMUMS = {
	[2] = 3,
	[3] = 4,
	[4] = 5,
	[5] = 5,
}

local TRAINER_PARTY_EXACT_SIZES = {
	[2] = 3,
	[3] = 4,
	[4] = 5,
	[5] = 5,
}

local function trainer_levels_complete()
	for step = 2, 6 do
		if not trainer_level_seen[step] then
			return false
		end
	end
	return true
end

local function trainer_name_addr(index)
	return W.ot_party_nicknames + index * MON_NAME_LENGTH
end

local function trainer_name_hex(index)
	local addr = trainer_name_addr(index)
	local parts = {}
	for i = 0, MON_NAME_LENGTH - 1 do
		parts[#parts + 1] = string.format("%02x", read8(addr + i))
	end
	return table.concat(parts, "")
end

local function trainer_name_has_terminator(index)
	local addr = trainer_name_addr(index)
	for i = 0, MON_NAME_LENGTH - 1 do
		if read8(addr + i) == TEXT_END then
			return true
		end
	end
	return false
end

local stop_with_screenshot

local function verify_trainer_nicknames(step, party_count)
	for i = 0, party_count - 1 do
		if read8(trainer_name_addr(i)) == 0 or not trainer_name_has_terminator(i) then
			stop_with_screenshot(string.format("FAILED_TRAINER_NICKNAME step=%d slot=%d name=%s", step, i + 1, trainer_name_hex(i)))
			return false
		end
	end
	return true
end

local function trainer_species_addr(index)
	return W.ot_party_mon1_level - MON_LEVEL_OFFSET + index * PARTYMON_STRUCT_LENGTH
end

local function verify_trainer_species_unique(step, party_count)
	local seen = {}
	for i = 0, party_count - 1 do
		local addr = trainer_species_addr(i)
		local species = read8(addr)
		local extspecies = read8(addr + MON_FORM_OFFSET) & 0xe0
		local key = string.format("%02x:%02x", species, extspecies)
		if seen[key] then
			stop_with_screenshot(string.format("FAILED_TRAINER_DUPLICATE_SPECIES step=%d slot=%d species=%s", step, i + 1, key))
			return false
		end
		seen[key] = true
	end
	return true
end

local cbid
function stop_with_screenshot(label)
	state_line(label)
	emu:screenshot(screenshot_path)
	log("screenshot=" .. screenshot_path)
	callbacks:remove(cbid)
end

local function make_battles_fast()
	local mode = read8(W.battle_mode)
	if mode == 0 then
		return
	end
	keep_party_healthy()
	write8(W.battle_menu_cursor, 1)
	write8(W.battle_menu_cursor + 1, 0)
	write8(W.menu_cursor_buffer, 1)
	write8(W.menu_cursor_buffer + 1, 0)
	local count = read8(W.party_count)
	if count > 1 then
		local next_mon = ((read8(W.cur_battle_mon) + 1) % count) + 1
		write8(W.party_menu_cursor, next_mon)
	end
	if mode == BATTLEMODE_WILD then
		write16(W.enemy_hp, 0)
	elseif mode == BATTLEMODE_TRAINER then
		write16(W.enemy_hp, 0)
	end
	write16(W.enemy_attack, 1)
	write16(W.enemy_defense, 1)
	write16(W.enemy_speed, 1)
	write16(W.enemy_sp_atk, 1)
	write16(W.enemy_sp_def, 1)
end

local frame0 = emu:currentFrame()
local last_log = 0
local phase = "boot"
local phase_frame = 0
local hub_seen = false

local function pulse(key, period, width)
	local t = phase_frame % period
	if t < width then
		return key
	end
	return 0
end

local function apply_keys(keys)
	for _, key in ipairs({
		KEY.A,
		KEY.B,
		KEY.SELECT,
		KEY.START,
		KEY.RIGHT,
		KEY.LEFT,
		KEY.UP,
		KEY.DOWN,
	}) do
		emu:clearKey(key)
		if (keys & bit(key)) ~= 0 then
			emu:addKey(key)
		end
	end
end

local function set_phase(next_phase)
	if phase ~= next_phase then
		phase = next_phase
		phase_frame = 0
		state_line("phase=" .. phase)
	end
end

local function drive_boot()
	local t = phase_frame % 90
	if t < 12 then
		return START
	elseif t < 28 then
		return A
	elseif t < 42 then
		return B
	elseif t < 58 then
		return A
	end
	return pulse(A, 120, 60)
end

cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local group = read8(W.map_group)
	local map = read8(W.map_number)
	local keys = 0

	if group == 0 and map == 0 and phase == "battle_factory" then
		group = GROUP_BATTLE_FACTORY
		map = MAP_BATTLE_FACTORY_1F
	end

	if hub_seen or group == GROUP_BATTLE_FACTORY or read8(W.party_count) > 0 then
		make_battles_fast()
		write8(W.options2, read8(W.options2) & 0x3f)
	end
	if read8(W.crash_code) ~= 0 or bsod_seen() then
		stop_with_screenshot("FAILED_CRASH")
		return
	end
	if read8(W.battle_mode) == BATTLEMODE_TRAINER then
		local step = read8(W.step)
		local range = TRAINER_LEVEL_RANGES[step]
		local level = read8(W.ot_party_mon1_level)
		local party_min = TRAINER_PARTY_MINIMUMS[step]
		local party_count = read8(W.ot_party_count)
		local trainer_key = string.format("%02x:%02x", read8(W.other_trainer_class), read8(W.other_trainer_id))
		if range and level > 0 then
			if level < range[1] or level > range[2] then
				stop_with_screenshot(string.format("FAILED_TRAINER_LEVEL step=%d level=%d expected=%d-%d", step, level, range[1], range[2]))
				return
			end
			if current_trainer_key ~= trainer_key then
				current_trainer_key = trainer_key
				current_trainer_step = step
				current_trainer_player_level_start = read8(W.party_mon1 + MON_LEVEL_OFFSET)
				first_trainer_player_level = first_trainer_player_level or current_trainer_player_level_start
				log(string.format(
					"PLAYER_LEVEL_BEFORE_TRAINER step=%d class_id=%s level=%d",
					step,
					trainer_key,
					current_trainer_player_level_start
				))
				if not trainer_seen[trainer_key] then
					trainer_seen[trainer_key] = true
					log(string.format("TRAINER_UNIQUE class_id=%s step=%d", trainer_key, step))
				else
					stop_with_screenshot(string.format("FAILED_REPEAT_TRAINER class_id=%s step=%d", trainer_key, step))
					return
				end
			end
			if not trainer_level_seen[step] then
				trainer_level_seen[step] = true
				log(string.format("TRAINER_LEVEL_VERIFIED step=%d level=%d expected=%d-%d", step, level, range[1], range[2]))
			end
		end
		if party_min and party_count > 0 then
			if party_count < party_min then
				stop_with_screenshot(string.format("FAILED_TRAINER_PARTY_SIZE step=%d count=%d expected_min=%d", step, party_count, party_min))
				return
			end
			local exact_size = TRAINER_PARTY_EXACT_SIZES[step]
			if exact_size and party_count ~= exact_size then
				stop_with_screenshot(string.format("FAILED_TRAINER_PARTY_EXACT_SIZE step=%d count=%d expected=%d", step, party_count, exact_size))
				return
			end
			if not verify_trainer_nicknames(step, party_count) then
				return
			end
			if exact_size and not verify_trainer_species_unique(step, party_count) then
				return
			end
			if not trainer_party_seen[step] then
				trainer_party_seen[step] = true
				log(string.format("TRAINER_PARTY_SIZE_VERIFIED step=%d count=%d expected_min=%d", step, party_count, party_min))
				log(string.format("TRAINER_NICKNAMES_VERIFIED step=%d count=%d", step, party_count))
				if exact_size then
					log(string.format("TRAINER_SPECIES_VARIETY_VERIFIED step=%d count=%d", step, party_count))
				end
			end
		end
	else
		if current_trainer_key then
			local after = read8(W.party_mon1 + MON_LEVEL_OFFSET)
			local before = current_trainer_player_level_start or after
			local gained = after - before
			local step = current_trainer_step or read8(W.step)
			trainer_level_gain_total = trainer_level_gain_total + gained
			trainer_level_gain_by_step[step] = (trainer_level_gain_by_step[step] or 0) + gained
			final_trainer_player_level = after
			log(string.format(
				"PLAYER_LEVEL_AFTER_TRAINER step=%d class_id=%s before=%d after=%d gained=%d total_gained=%d",
				step,
				current_trainer_key,
				before,
				after,
				gained,
				trainer_level_gain_total
			))
		end
		current_trainer_key = nil
		current_trainer_step = nil
		current_trainer_player_level_start = nil
	end
	check_supplies()
	if not draft_seeded
		and supplies_seen
		and group == GROUP_SAFARI_ZONE
		and map == MAP_SAFARI_ZONE_HUB
		and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT
		and read8(W.battle_mode) == 0
		and read8(W.party_count) > 0 then
		seed_draft_party()
		draft_seeded = true
		state_line("DRAFT_SINGLE_MON_VERIFIED")
	end

	if frame - last_log > 300 then
		last_log = frame
		state_line("tick")
	end

	if read16(W.runs_hi) >= 1 and read16(W.wins_hi) >= 1 and read8(W.keep_count) >= 1 and read16(W.bp_hi) >= 18 and (read8(W.johto_badges) & 0x80) ~= 0 and read8(W.party_count) == 1 and supplies_seen and single_draft_verified and trainer_levels_complete() then
		if not victory_stats_seen then
			victory_stats_seen = true
			state_line("VICTORY_STATS_SEEN")
		end
	end

	if victory_stats_seen and read8(W.script_running) == 0 and read8(W.battle_mode) == 0 and read8(W.map_status) == 2 then
		if not trainer_growth_summary_logged then
			trainer_growth_summary_logged = true
			log(string.format(
				"TRAINER_LEVEL_GROWTH_SUMMARY start=%s final=%s total=%d round1=%d round2=%d round3=%d round4=%d boss=%d",
				tostring(first_trainer_player_level),
				tostring(final_trainer_player_level),
				trainer_level_gain_total,
				trainer_level_gain_by_step[2] or 0,
				trainer_level_gain_by_step[3] or 0,
				trainer_level_gain_by_step[4] or 0,
				trainer_level_gain_by_step[5] or 0,
				trainer_level_gain_by_step[6] or 0
			))
		end
		state_line("VERIFIED_RUN")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
		return
	end

	if read8(W.battle_mode) ~= 0 then
		set_phase("battle")
		write8(W.battle_menu_cursor, 1)
		write8(W.battle_menu_cursor + 1, 0)
		write8(W.menu_cursor_buffer, 1)
		write8(W.menu_cursor_buffer + 1, 0)
		keys = pulse(A, 8, 4)
	elseif group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F then
		set_phase("battle_factory")
		if not hub_seen then
			hub_seen = true
			state_line("HUB_REACHED")
		end
		if draft_seeded and not post_draft_return_seen and read8(W.step) == 2 and read8(W.map_status) == 2 then
			post_draft_return_seen = true
			state_line("POST_DRAFT_RETURN")
			emu:screenshot(post_draft_screenshot_path)
			log("post_draft_screenshot=" .. post_draft_screenshot_path)
		end
		if read8(W.map_status) ~= 2 then
			keys = 0
		elseif read8(W.x) < 12 then
			keys = RIGHT
		elseif read8(W.x) > 12 then
			keys = bit(KEY.LEFT)
		elseif read8(W.y) < 8 then
			keys = DOWN
		elseif read8(W.y) > 8 then
			keys = UP
		elseif read8(W.player_direction) ~= 0x04 then
			write8(W.player_direction, 0x04)
			keys = 0
		elseif phase_frame < 600 and draft_seeded and read8(W.step) == 2 then
			keys = 0
		elseif phase_frame < 90 then
			keys = 0
		else
			keys = pulse(A, 12, 4)
		end
	elseif group == GROUP_SAFARI_ZONE and map == MAP_SAFARI_ZONE_HUB and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT then
		set_phase("draft_exit")
		if read8(W.map_status) ~= 2 then
			keys = 0
		elseif read8(W.y) < 26 then
			keys = DOWN
		elseif read8(W.y) > 26 then
			keys = UP
		else
			local t = phase_frame % 64
			if t < 16 then
				keys = UP
			elseif t < 32 then
				keys = DOWN
			elseif t < 48 then
				keys = UP
			else
				keys = A
			end
		end
	elseif group == GROUP_SAFARI_ZONE and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT then
		set_phase("field")
		if read8(W.map_status) ~= 2 then
			keys = 0
		elseif phase_frame % 90 < 30 then
			keys = DOWN
		elseif phase_frame % 90 < 60 then
			keys = RIGHT
		else
			keys = LEFT
		end
	else
		if hub_seen then
			set_phase("idle")
			keys = 0
		else
			set_phase("boot")
			keys = drive_boot()
		end
	end

	if frame - frame0 > 300000 then
		state_line("FAILED_TIMEOUT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
		return
	end

	phase_frame = phase_frame + 1
	apply_keys(keys)
end)

log("Safari Gauntlet full-run verifier loaded")
state_line("initial")
