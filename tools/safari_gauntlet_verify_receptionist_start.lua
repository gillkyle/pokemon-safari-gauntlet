local log_path = "/tmp/safari-gauntlet-receptionist-start.log"
local screenshot_path = "/tmp/safari-gauntlet-receptionist-start.png"
local crash_screenshot_path = "/tmp/safari-gauntlet-receptionist-start-crash.png"

local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)
local B = bit(KEY.B)
local START = bit(KEY.START)
local LEFT = bit(KEY.LEFT)
local RIGHT = bit(KEY.RIGHT)
local UP = bit(KEY.UP)
local DOWN = bit(KEY.DOWN)

local W = {
	map_group = 0xdcac,
	map_number = 0xdcad,
	map_status = 0xd431,
	script_flags = 0xd433,
	script_mode = 0xd436,
	script_running = 0xd437,
	script_delay = 0xd460,
	script_bank = 0xffeb,
	script_pos = 0xffec,
	crash_code = 0xffe5,
	tilemap = 0xc440,
	options2 = 0xcff5,
	y = 0xdcae,
	x = 0xdcaf,
	player_direction = 0xd4d4,
	party_count = 0xdcce,
	battle_mode = 0xd233,
	step = 0xd7dc,
	settings = 0xdba1,
	keep_count = 0xdba2,
	runs_hi = 0xdb99,
	wins_hi = 0xdb9b,
	bp_hi = 0xdc88,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local GROUP_SAFARI_ZONE = 32
local MAP_SAFARI_ZONE_HUB = 1
local SAFARI_GAUNTLET_STEP_DRAFT = 1
local RECEPTIONIST_X = 12
local RECEPTIONIST_Y = 8

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local phase = "boot"
local phase_start = frame0
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
		"%s map=%d/%d xy=%d,%d dir=%02x status=%02x script=%02x/%02x running=%02x delay=%02x hscript=%02x:%04x party=%d battle=%d step=%d settings=%02x keep=%d runs=%d wins=%d bp=%d crash=%02x",
		prefix,
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_direction),
		read8(W.map_status),
		read8(W.script_flags),
		read8(W.script_mode),
		read8(W.script_running),
		read8(W.script_delay),
		read8(W.script_bank),
		read8(W.script_pos) + read8(W.script_pos + 1) * 256,
		read8(W.party_count),
		read8(W.battle_mode),
		read8(W.step),
		read8(W.settings),
		read8(W.keep_count),
		read16(W.runs_hi),
		read16(W.wins_hi),
		read16(W.bp_hi),
		read8(W.crash_code)
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

local function pulse(mask, period, width)
	local t = (emu:currentFrame() - phase_start) % period
	if t < width then
		return mask
	end
	return 0
end

local function drive_continue()
	local t = (emu:currentFrame() - phase_start) % 90
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

local function move_to_receptionist()
	local x = read8(W.x)
	local y = read8(W.y)
	if x < RECEPTIONIST_X then
		return RIGHT
	elseif x > RECEPTIONIST_X then
		return LEFT
	elseif y < RECEPTIONIST_Y then
		return DOWN
	elseif y > RECEPTIONIST_Y then
		return UP
	elseif read8(W.player_direction) ~= 0x04 then
		write8(W.player_direction, 0x04)
		return 0
	end
	return 0
end

local function set_phase(next_phase)
	if phase ~= next_phase then
		phase = next_phase
		phase_start = emu:currentFrame()
		state_line("phase=" .. phase)
	end
end

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local group = read8(W.map_group)
	local map = read8(W.map_number)
	local keys = 0

	write8(W.options2, read8(W.options2) & 0x3f)

	if read8(W.crash_code) ~= 0 or bsod_seen() then
		state_line("FAILED_CRASH")
		emu:screenshot(crash_screenshot_path)
		log("screenshot=" .. crash_screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	if group == GROUP_SAFARI_ZONE and map == MAP_SAFARI_ZONE_HUB and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT and read8(W.map_status) == 2 then
		state_line("VERIFIED_RECEPTIONIST_START_DRAFT")
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

	if group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F and read8(W.map_status) == 2 then
		if phase == "boot" then
			set_phase("move")
		end
		if phase == "move" then
			keys = move_to_receptionist()
			if keys == 0 and read8(W.x) == RECEPTIONIST_X and read8(W.y) == RECEPTIONIST_Y then
				set_phase("talk")
			end
		elseif phase == "talk" then
			keys = pulse(A, 24, 6)
		end
	else
		keys = drive_continue()
	end

	if frame - phase_start > 9000 and phase == "talk" then
		state_line("FAILED_RECEPTIONIST_START_TIMEOUT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	if frame - frame0 > 40000 then
		state_line("FAILED_TIMEOUT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	apply_keys(keys)
end)

log("Safari Gauntlet receptionist start verifier loaded")
state_line("initial")
