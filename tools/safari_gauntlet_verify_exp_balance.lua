local log_path = "/tmp/safari-gauntlet-exp-balance.log"
local screenshot_path = "/tmp/safari-gauntlet-exp-balance.png"

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

local W = {
	map_group = 0xdcac,
	map_number = 0xdcad,
	y = 0xdcae,
	x = 0xdcaf,
	player_direction = 0xd4d4,
	options2 = 0xcff5,
	initial_options = 0xcff6,
	initial_options2 = 0xcff7,
	party_count = 0xdcce,
	party_mon1_item = 0xdcd7,
	party_mon1_exp = 0xdcde,
	battle_mode = 0xd233,
	battle_type = 0xd236,
	enemy_level = 0xd219,
	enemy_hp = 0xd21c,
	enemy_base_exp = 0xd232,
	enemy_catch_rate = 0xd231,
	map_status = 0xd431,
	script_flags = 0xd433,
	script_mode = 0xd436,
	settings = 0xdba1,
	step = 0xd7dc,
	time_remaining = 0xdc93,
	wild_cooldown = 0xd464,
	crash_code = 0xffe5,
	tilemap = 0xc440,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local GROUP_SAFARI_ZONE = 32
local SAFARI_GAUNTLET_STEP_DRAFT = 1
local BATTLEMODE_WILD = 1
local SAFARI_GAUNTLET_SETTINGS_NATIONAL = 0x01
local SAFARI_GAUNTLET_SETTINGS_INITIALIZED = 0x20
local SCALED_EXP_OPT = 0x40
local TRADED_AS_OT_OPT = 0x10
local NO_EXP_OPT = 0x04
local CONTROLLED_BASE_EXP = 100
local CONTROLLED_LEVEL = 50
local EXPECTED_EXP = 1785
local OW_UP = 0x04

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local phase = "boot"
local phase_frame = 0
local last_log = 0
local exp_before = nil
local forced_frame = nil
local cbid

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

local function write16(hi, value)
	write8(hi, value // 256)
	write8(hi + 1, value % 256)
end

local function read24(hi)
	return read8(hi) * 65536 + read8(hi + 1) * 256 + read8(hi + 2)
end

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
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
	return tile_sequence_seen({ 0x84, 0x91, 0x91, 0x8e, 0x91 })
end

local function state_line(prefix)
	local delta = 0
	if exp_before then
		delta = read24(W.party_mon1_exp) - exp_before
	end
	log(string.format(
		"%s crash=%d map=%d/%d xy=%d,%d party=%d battle=%d type=%d step=%d enemy_level=%d enemy_base_exp=%d enemy_hp=%d exp_before=%s exp_now=%d delta=%d",
		prefix,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.party_count),
		read8(W.battle_mode),
		read8(W.battle_type),
		read8(W.step),
		read8(W.enemy_level),
		read8(W.enemy_base_exp),
		read16(W.enemy_hp),
		exp_before and tostring(exp_before) or "nil",
		read24(W.party_mon1_exp),
		delta
	))
end

local function apply_keys(keys)
	for _, key in ipairs({ KEY.A, KEY.B, KEY.SELECT, KEY.START, KEY.LEFT, KEY.RIGHT, KEY.UP, KEY.DOWN }) do
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

local function pulse(key, period, width)
	if phase_frame % period < width then
		return key
	end
	return 0
end

local function finish(label)
	state_line(label)
	emu:screenshot(screenshot_path)
	log("screenshot=" .. screenshot_path)
	apply_keys(0)
	callbacks:remove(cbid)
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
	return 0
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

local function in_hub()
	return read8(W.map_group) == GROUP_BATTLE_FACTORY
		and read8(W.map_number) == MAP_BATTLE_FACTORY_1F
end

local function in_draft()
	return read8(W.map_group) == GROUP_SAFARI_ZONE
		and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT
end

local function prepare_exp_options()
	write8(W.initial_options, (read8(W.initial_options) & (0xff ~ SCALED_EXP_OPT)) | TRADED_AS_OT_OPT)
	write8(W.initial_options2, read8(W.initial_options2) & (0xff ~ NO_EXP_OPT))
	write8(W.party_mon1_item, 0)
	write8(W.settings, read8(W.settings) | SAFARI_GAUNTLET_SETTINGS_NATIONAL | SAFARI_GAUNTLET_SETTINGS_INITIALIZED)
end

local function drive_field()
	write8(W.wild_cooldown, 0)
	write16(W.time_remaining, 0x03ff)
	local t = phase_frame % 240
	if t < 80 then
		return UP
	elseif t < 160 then
		return LEFT
	end
	return RIGHT
end

cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local keys = 0

	write8(W.options2, read8(W.options2) & 0x3f)
	if read8(W.crash_code) ~= 0 or bsod_seen() then
		finish("FAILED_CRASH")
		return
	end

	if frame - last_log > 300 then
		last_log = frame
		state_line("tick")
	end

	if phase == "boot" then
		if in_hub()
			and read8(W.map_status) == 2
			and read8(W.script_flags) == 0
			and read8(W.script_mode) == 0
			and read8(W.party_count) > 0 then
			prepare_exp_options()
			set_phase("move_reception")
		else
			keys = drive_boot()
		end
	elseif phase == "move_reception" then
		keys = move_toward(12, 6)
		if keys == 0 then
			write8(W.player_direction, OW_UP)
			set_phase("start")
		end
	elseif phase == "start" then
		if in_draft() and read8(W.party_count) > 0 then
			set_phase("field")
		else
			keys = pulse(A, 12, 4)
		end
	elseif phase == "field" then
		if read8(W.battle_mode) == BATTLEMODE_WILD
			and read8(W.enemy_level) > 0
			and read8(W.enemy_catch_rate) > 0
			and read16(W.enemy_hp) > 0 then
			exp_before = read24(W.party_mon1_exp)
			write8(W.enemy_base_exp, CONTROLLED_BASE_EXP)
			write8(W.enemy_level, CONTROLLED_LEVEL)
			write16(W.enemy_hp, 0)
			forced_frame = frame
			set_phase("battle")
		else
			keys = drive_field()
		end
	elseif phase == "battle" then
		keys = pulse(A, 8, 4)
		if exp_before and read8(W.battle_mode) == 0 and frame - forced_frame > 120 then
			local delta = read24(W.party_mon1_exp) - exp_before
			if delta >= EXPECTED_EXP - 1 and delta <= EXPECTED_EXP + 1 then
				finish("VERIFIED_EXP_BALANCE")
			else
				finish("FAILED_EXP_BALANCE_DELTA_" .. delta)
			end
			return
		end
	end

	if frame - frame0 > 120000 then
		finish("FAILED_TIMEOUT")
		return
	end

	phase_frame = phase_frame + 1
	apply_keys(keys)
end)

log("Safari Gauntlet EXP balance verifier loaded")
state_line("initial")
