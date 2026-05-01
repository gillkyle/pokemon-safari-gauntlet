local log_path = "/tmp/safari-gauntlet-existing-save-load.log"
local screenshot_path = "/tmp/safari-gauntlet-existing-save-load.png"
local crash_screenshot_path = "/tmp/safari-gauntlet-existing-save-load-crash.png"

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
	map_status = 0xd431,
	player_direction = 0xd4d4,
	options2 = 0xcff5,
	script_flags = 0xd433,
	script_mode = 0xd436,
	crash_code = 0xffe5,
	tilemap = 0xc440,
	party_count = 0xdcce,
	battle_mode = 0xd233,
	step = 0xd7dc,
	time_remaining = 0xdc93,
	settings = 0xdba1,
	keep_count = 0xdba2,
	runs_hi = 0xdb99,
	wins_hi = 0xdb9b,
	bp_hi = 0xdc88,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local GROUP_SAFARI_ZONE = 32

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local phase = "boot"
local phase_frame = 0
local stable_loaded_frame = nil
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

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function state_line(prefix)
	log(string.format(
		"%s crash=%02x map=%d/%d xy=%d,%d dir=%02x status=%02x script=%02x/%02x party=%d battle=%d step=%d steps_left=%d settings=%02x keep=%d runs=%d wins=%d bp=%d",
		prefix,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_direction),
		read8(W.map_status),
		read8(W.script_flags),
		read8(W.script_mode),
		read8(W.party_count),
		read8(W.battle_mode),
		read8(W.step),
		read16(W.time_remaining),
		read8(W.settings),
		read8(W.keep_count),
		read16(W.runs_hi),
		read16(W.wins_hi),
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

local function apply_keys(keys)
	for _, key in ipairs({ KEY.A, KEY.B, KEY.SELECT, KEY.START, KEY.LEFT, KEY.RIGHT, KEY.UP, KEY.DOWN }) do
		emu:clearKey(key)
		if (keys & bit(key)) ~= 0 then
			emu:addKey(key)
		end
	end
end

local function drive_continue()
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

local function drive_loaded_map()
	local group = read8(W.map_group)
	local map = read8(W.map_number)
	local x = read8(W.x)
	local y = read8(W.y)

	if read8(W.battle_mode) ~= 0 or read8(W.script_flags) ~= 0 or read8(W.script_mode) ~= 0 then
		return A
	end
	if group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F then
		if x < 12 then
			return RIGHT
		elseif x > 12 then
			return LEFT
		elseif y < 8 then
			return DOWN
		elseif y > 8 then
			return UP
		end
		return 0
	elseif group == GROUP_SAFARI_ZONE then
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
	return 0
end

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local keys = 0
	local group = read8(W.map_group)
	local map = read8(W.map_number)
	local loaded = (group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F) or group == GROUP_SAFARI_ZONE

	write8(W.options2, read8(W.options2) & 0x3f)

	if read8(W.crash_code) ~= 0 or bsod_seen() then
		state_line("FAILED_CRASH")
		emu:screenshot(crash_screenshot_path)
		log("screenshot=" .. crash_screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	if frame - last_log > 300 then
		last_log = frame
		state_line("tick")
	end

	if loaded and not stable_loaded_frame and read8(W.map_status) == 2 then
		stable_loaded_frame = frame
		phase = "loaded"
		phase_frame = 0
		state_line("loaded")
	end

	if phase == "loaded" then
		keys = drive_loaded_map()
		if group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F and frame - stable_loaded_frame > 300 then
			state_line("VERIFIED_EXISTING_SAVE_LOAD")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			callbacks:remove(cbid)
			return
		elseif group == GROUP_SAFARI_ZONE and read8(W.step) ~= 1 then
			state_line("FAILED_INACTIVE_SAFARI_SAVE_NOT_RECOVERED")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			callbacks:remove(cbid)
			return
		elseif group == GROUP_SAFARI_ZONE and frame - stable_loaded_frame > 1200 then
			state_line("VERIFIED_EXISTING_SAVE_LOAD_ACTIVE_DRAFT")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			callbacks:remove(cbid)
			return
		end
	else
		keys = drive_continue()
	end

	if frame - frame0 > 30000 then
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

log("Safari Gauntlet existing-save load verifier loaded")
state_line("initial")
