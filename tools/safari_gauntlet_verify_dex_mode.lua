local mode = SAFARI_GAUNTLET_DEX_MODE or "national"
assert(mode == "johto" or mode == "national", "unknown dex mode: " .. tostring(mode))
local direct_pool = SAFARI_GAUNTLET_DEX_DIRECT_POOL or false

local log_suffix = direct_pool and ("dex-pool-" .. mode) or ("dex-" .. mode)
local log_path = "/tmp/safari-gauntlet-" .. log_suffix .. ".log"
local screenshot_path = "/tmp/safari-gauntlet-" .. log_suffix .. ".png"

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
	party_count = 0xdcce,
	battle_mode = 0xd233,
	battle_type = 0xd236,
	enemy_species = 0xd209,
	enemy_form = 0xd213,
	enemy_level = 0xd219,
	enemy_hp = 0xd21c,
	enemy_attack = 0xd220,
	enemy_defense = 0xd222,
	enemy_speed = 0xd224,
	enemy_sp_atk = 0xd226,
	enemy_sp_def = 0xd228,
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
local SAFARI_GAUNTLET_JOHTO_POOL_COUNT = 251
local EXTSPECIES_MASK = 0x20
local FORM_AND_EXT_MASK = 0x3f
local OW_UP = 0x04
local OW_DOWN = 0x00

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local phase = "boot"
local phase_frame = 0
local last_log = 0
local encounters = 0
local outside_johto_seen = false
local battle_seen = false
local seen = {}
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
	log(string.format(
		"%s mode=%s crash=%d map=%d/%d xy=%d,%d party=%d battle=%d step=%d settings=%02x encounters=%d outside_johto=%d",
		prefix,
		mode,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.party_count),
		read8(W.battle_mode),
		read8(W.step),
		read8(W.settings),
		encounters,
		outside_johto_seen and 1 or 0
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

local function move_from_settings_to_reception()
	if read8(W.x) < 10 then
		return RIGHT
	elseif read8(W.y) > 9 then
		return UP
	elseif read8(W.x) < 12 then
		return RIGHT
	elseif read8(W.x) > 12 then
		return LEFT
	elseif read8(W.y) > 8 then
		return UP
	elseif read8(W.y) < 8 then
		return DOWN
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

local function setting_matches()
	local national = (read8(W.settings) & SAFARI_GAUNTLET_SETTINGS_NATIONAL) ~= 0
	return (mode == "national" and national) or (mode == "johto" and not national)
end

local function apply_direct_pool_setting()
	local settings = read8(W.settings) | SAFARI_GAUNTLET_SETTINGS_INITIALIZED
	if mode == "national" then
		settings = settings | SAFARI_GAUNTLET_SETTINGS_NATIONAL
	else
		settings = settings & (0xff ~ SAFARI_GAUNTLET_SETTINGS_NATIONAL)
	end
	write8(W.settings, settings)
end

local function drive_settings_menu()
	if phase_frame < 12 then
		return DOWN
	elseif phase_frame < 72 then
		return 0
	elseif phase_frame < 84 then
		return A
	elseif phase_frame < 150 then
		return 0
	elseif phase_frame < 162 then
		return A
	elseif phase_frame < 220 then
		return 0
	elseif mode == "national" and phase_frame < 232 then
		return DOWN
	elseif mode == "national" and phase_frame < 282 then
		return 0
	elseif mode == "national" and phase_frame < 294 then
		return A
	elseif mode == "johto" and phase_frame < 232 then
		return A
	elseif phase_frame < 360 then
		return 0
	elseif phase_frame < 372 then
		return A
	elseif phase_frame < 430 then
		return 0
	elseif phase_frame < 442 then
		return DOWN
	elseif phase_frame < 470 then
		return 0
	elseif phase_frame < 482 then
		return DOWN
	elseif phase_frame < 510 then
		return 0
	elseif phase_frame < 522 then
		return DOWN
	elseif phase_frame < 550 then
		return 0
	elseif phase_frame < 562 then
		return DOWN
	elseif phase_frame < 620 then
		return 0
	elseif phase_frame < 632 then
		return A
	elseif phase_frame < 760 then
		return 0
	elseif phase_frame < 1040 then
		return pulse(B, 16, 4)
	end
	return 0
end

local function drive_field()
	write8(W.wild_cooldown, 0)
	write16(W.time_remaining, 0x03ff)
	local x = read8(W.x)
	local y = read8(W.y)
	if y >= 24 then
		if x < 20 then
			return RIGHT
		end
		return UP
	end
	local t = phase_frame % 160
	if t < 40 then
		return UP
	elseif t < 80 then
		return RIGHT
	elseif t < 120 then
		return DOWN
	end
	return LEFT
end

local function record_encounter()
	local species = read8(W.enemy_species)
	local form = read8(W.enemy_form)
	local level = read8(W.enemy_level)
	local catch_rate = read8(W.enemy_catch_rate)
	if species == 0 or level == 0 or catch_rate == 0 then
		return
	end
	local key = string.format("%02x:%02x", species, form & FORM_AND_EXT_MASK)
	if seen[key] then
		return
	end
	seen[key] = true
	encounters = encounters + 1
	local outside = (form & EXTSPECIES_MASK) ~= 0 or species > SAFARI_GAUNTLET_JOHTO_POOL_COUNT
	if outside then
		outside_johto_seen = true
	end
	log(string.format("ENCOUNTER mode=%s species=%02x form=%02x outside_johto=%d encounters=%d", mode, species, form, outside and 1 or 0, encounters))
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
			if direct_pool then
				apply_direct_pool_setting()
				set_phase("move_reception")
			else
				set_phase("move_settings")
			end
		else
			keys = drive_boot()
		end
	elseif phase == "move_settings" then
		keys = move_toward(9, 10)
		if keys == 0 then
			write8(W.player_direction, OW_DOWN)
			set_phase("settings_menu")
		end
	elseif phase == "settings_menu" then
		keys = drive_settings_menu()
		if phase_frame > 1080 and setting_matches() then
			set_phase("move_reception")
		elseif phase_frame > 1320 then
			if setting_matches() then
				set_phase("move_reception")
			else
				finish("FAILED_DEX_SETTING_NOT_SAVED")
				return
			end
		end
	elseif phase == "move_reception" then
		keys = move_from_settings_to_reception()
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
		if read8(W.battle_mode) == BATTLEMODE_WILD then
			if not battle_seen then
				record_encounter()
				battle_seen = true
				if mode == "johto" and outside_johto_seen then
					finish("FAILED_JOHTO_POOL_OUTSIDE_JOHTO")
					return
				end
				if mode == "national" and outside_johto_seen then
					finish("VERIFIED_DEX_MODE_NATIONAL")
					return
				end
			end
			write16(W.enemy_hp, 0)
			write16(W.enemy_attack, 1)
			write16(W.enemy_defense, 1)
			write16(W.enemy_speed, 1)
			write16(W.enemy_sp_atk, 1)
			write16(W.enemy_sp_def, 1)
			keys = pulse(A, 8, 4)
		else
			battle_seen = false
			if mode == "johto" and encounters >= 20 and not outside_johto_seen then
				finish("VERIFIED_DEX_MODE_JOHTO")
				return
			end
			if mode == "national" and encounters >= 80 and not outside_johto_seen then
				finish("FAILED_NATIONAL_POOL_NO_OUTSIDE_JOHTO")
				return
			end
			keys = drive_field()
		end
	end

	if frame - frame0 > 180000 then
		finish("FAILED_TIMEOUT")
		return
	end

	phase_frame = phase_frame + 1
	apply_keys(keys)
end)

log("Safari Gauntlet dex mode verifier loaded mode=" .. mode .. " direct_pool=" .. tostring(direct_pool))
state_line("initial")
