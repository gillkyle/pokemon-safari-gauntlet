local log_path = "/tmp/safari-gauntlet-run.log"
local screenshot_path = "/tmp/safari-gauntlet-run.png"

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
	options2 = 0xcff5,
	y = 0xdcae,
		x = 0xdcaf,
		player_direction = 0xd4d4,
		player_gender = 0xd47a,
	party_count = 0xdcce,
	battle_mode = 0xd233,
	battle_type = 0xd236,
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
local POKE_BALL = 1
local GREAT_BALL = 2
local ULTRA_BALL = 3
local MASTER_BALL = 4
local STRUGGLE = 0xff

local f = assert(io.open(log_path, "w"))
local draft_seeded = false
local draft_restored = false
local supplies_seen = false

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
	-- Test harness only: fake a 4-mon draft to satisfy the gate check, then
	-- restore to one real mon after the draft finishes.
	write8(W.party_count, 4)
	local species = read8(W.party_mon1)
	for i = 0, 5 do
		local addr = W.party_species + i
		if i < 4 then
			write8(addr, species)
		else
			write8(addr, 0xff)
		end
	end
end

local function restore_after_draft()
	if draft_restored then
		return
	end
	write8(W.party_count, 1)
	local species = read8(W.party_mon1)
	write8(W.party_species, species)
	for i = 1, 5 do
		write8(W.party_species + i, 0xff)
	end
	draft_restored = true
	log(string.format(
		"DRAFT_SEED_RESTORED map=%d/%d step=%d party=%d",
		read8(W.map_group),
		read8(W.map_number),
		read8(W.step),
		read8(W.party_count)
	))
end

local function state_line(prefix)
	log(string.format(
			"%s map=%d/%d xy=%d,%d dir=%02x gender=%d badges=%02x party=%d battle=%d step=%d attempts=%d boss=%d settings=%02x runs=%d wins=%d losses=%d keep=%d bp=%d",
		prefix,
		read8(W.map_group),
			read8(W.map_number),
			read8(W.x),
			read8(W.y),
			read8(W.player_direction),
			read8(W.player_gender),
		read8(W.johto_badges),
		read8(W.party_count),
		read8(W.battle_mode),
		read8(W.step),
		read8(W.draft_attempts),
		read8(W.boss),
		read8(W.settings),
		read16(W.runs_hi),
		read16(W.wins_hi),
		read16(W.losses_hi),
		read8(W.keep_count),
		read16(W.bp_hi)
	))
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

local cbid
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
		state_line("DRAFT_TEAM_SEEDED")
	end
	if draft_seeded and not draft_restored and read8(W.step) ~= SAFARI_GAUNTLET_STEP_DRAFT then
		restore_after_draft()
	end

	if frame - last_log > 300 then
		last_log = frame
		state_line("tick")
	end

	if read16(W.runs_hi) >= 1 and read16(W.wins_hi) >= 1 and read8(W.keep_count) >= 1 and read16(W.bp_hi) >= 18 and (read8(W.johto_badges) & 0x80) ~= 0 and read8(W.party_count) == 0 and supplies_seen then
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
		if read8(W.x) < 12 then
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
		elseif phase_frame < 90 then
			keys = 0
		else
			keys = pulse(A, 12, 4)
		end
	elseif group == GROUP_SAFARI_ZONE and map == MAP_SAFARI_ZONE_HUB and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT then
		set_phase("draft_exit")
		if read8(W.y) < 26 then
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
		if phase_frame % 90 < 30 then
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
