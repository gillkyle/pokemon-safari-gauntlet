local log_path = "/tmp/safari-gauntlet-start-menu-party.log"
local screenshot_path = "/tmp/safari-gauntlet-start-menu-party.png"

local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)
local B = bit(KEY.B)
local START = bit(KEY.START)

local W = {
	map_group = 0xdcac,
	map_number = 0xdcad,
	y = 0xdcae,
	x = 0xdcaf,
	player_direction = 0xd4d4,
	script_flags = 0xd433,
	script_mode = 0xd436,
	crash_code = 0xffe5,
	party_count = 0xdcce,
	step = 0xd7dc,
	settings = 0xdba1,
	keep_count = 0xdba2,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local OW_DOWN = 0x00

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local phase = "boot"
local phase_frame = 0
local phase_start_frame = frame0
local last_log = 0

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

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function state_line(prefix)
	log(string.format(
		"%s crash=%d map=%d/%d xy=%d,%d dir=%02x script=%02x/%02x party=%d step=%d",
		prefix,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_direction),
		read8(W.script_flags),
		read8(W.script_mode),
		read8(W.party_count),
		read8(W.step)
	))
	log(string.format(
		"state settings=%02x keep=%d",
		read8(W.settings),
		read8(W.keep_count)
	))
end

local function apply_keys(keys)
	emu:setKeys(keys)
	for _, key in ipairs({ KEY.A, KEY.B, KEY.SELECT, KEY.START, KEY.LEFT, KEY.RIGHT, KEY.UP, KEY.DOWN }) do
		emu:clearKey(key)
		if (keys & bit(key)) ~= 0 then
			emu:addKey(key)
		end
	end
end

local function in_hub()
	return read8(W.map_group) == GROUP_BATTLE_FACTORY
		and read8(W.map_number) == MAP_BATTLE_FACTORY_1F
end

local function set_phase(next_phase)
	if phase ~= next_phase then
		phase = next_phase
		phase_frame = 0
		phase_start_frame = emu:currentFrame()
		state_line("phase=" .. phase)
	end
end

local function drive_boot()
	local t = phase_frame % 90
	if t < 12 then
		return START
	elseif t < 36 then
		return A
	elseif t < 48 then
		return B
	elseif t < 72 then
		return A
	end
	return 0
end

local cbid
cbid = callbacks:add("keysRead", function()
	local frame = emu:currentFrame()
	local elapsed = frame - phase_start_frame
	local keys = 0

	if read8(W.crash_code) ~= 0 then
		state_line("FAILED_CRASH")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	if frame - last_log > 300 then
		last_log = frame
		state_line("tick")
	end

	if phase == "boot" then
		keys = drive_boot()
		if in_hub()
			and read8(W.x) == 11
			and read8(W.y) == 8
			and read8(W.player_direction) == OW_DOWN
			and read8(W.script_flags) == 0
			and read8(W.script_mode) == 0
			and read8(W.step) == 0 then
			set_phase("settle")
		end
	elseif phase == "settle" then
		if elapsed > 90 then
			set_phase("open_start")
		end
	elseif phase == "open_start" then
		if elapsed < 30 then
			keys = START
		elseif elapsed > 150 then
			set_phase("select_pokemon")
		end
	elseif phase == "select_pokemon" then
		if elapsed > 30 and elapsed < 300 then
			keys = A
		elseif read8(W.party_count) >= 1 then
			state_line("VERIFIED_START_MENU_POKEMON_SEEDS_PARTY")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			callbacks:remove(cbid)
			return
		elseif elapsed > 900 then
			if read8(W.party_count) >= 1 then
				state_line("VERIFIED_START_MENU_POKEMON_SEEDS_PARTY")
			else
				state_line("FAILED_START_MENU_POKEMON_NO_PARTY")
			end
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			callbacks:remove(cbid)
			return
		end
	end

	if frame - frame0 > 90000 then
		state_line("FAILED_TIMEOUT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	phase_frame = phase_frame + 1
	apply_keys(keys)
end)

log("Safari Gauntlet start-menu party verifier loaded")
state_line("initial")
