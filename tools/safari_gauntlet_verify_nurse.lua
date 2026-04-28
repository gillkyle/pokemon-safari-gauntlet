local log_path = "/tmp/safari-gauntlet-nurse.log"
local screenshot_path = "/tmp/safari-gauntlet-nurse.png"

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
	y = 0xdcae,
	x = 0xdcaf,
	map_status = 0xd431,
	player_direction = 0xd4d4,
	script_flags = 0xd433,
	script_mode = 0xd436,
	party_count = 0xdcce,
	crash_code = 0xffe5,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17

local f = assert(io.open(log_path, "w"))

local function mute_audio()
	pcall(function() emu:setVolume(0) end)
	pcall(function() emu.audio:setVolume(0) end)
	pcall(function() emu.audio:setMuted(true) end)
end

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
		"%s crash=%d map=%d/%d xy=%d,%d dir=%02x status=%02x script=%02x/%02x party=%d",
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
		read8(W.party_count)
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

local function drive_boot(frame)
	if frame > 1500 then
		return 0
	end
	local t = frame % 90
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

local function move_toward(tx, ty)
	local x = read8(W.x)
	local y = read8(W.y)
	if x < tx then
		return RIGHT
	elseif x > tx then
		return LEFT
	elseif y < ty then
		return DOWN
	elseif y > ty then
		return UP
	end
	return 0
end

mute_audio()

local phase = "boot"
local phase_frame = 0
local frame0 = emu:currentFrame()
local phase_start_frame = frame0
local min_boot_frames = 1200
local move_index = 1
local waypoints = {
	{11, 9},
	{6, 9},
	{6, 8},
}

local function set_phase(next_phase)
	if phase ~= next_phase then
		phase = next_phase
		phase_frame = 0
		phase_start_frame = emu:currentFrame()
		state_line("phase=" .. phase)
	end
end

local function move_waypoints()
	local target = waypoints[move_index]
	if not target then
		return 0
	end
	local keys = move_toward(target[1], target[2])
	if keys == 0 then
		move_index = move_index + 1
		return move_waypoints()
	end
	return keys
end

local cbid
cbid = callbacks:add("keysRead", function()
	local frame = emu:currentFrame()
	local elapsed = frame - phase_start_frame
	local keys = 0
	local in_hub = read8(W.map_group) == GROUP_BATTLE_FACTORY and read8(W.map_number) == MAP_BATTLE_FACTORY_1F
	local ready = in_hub and read8(W.map_status) == 2 and read8(W.script_flags) == 0 and read8(W.script_mode) == 0

	if read8(W.crash_code) ~= 0 then
		state_line("FAILED_CRASH")
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	if not in_hub then
		keys = drive_boot(frame - frame0)
		apply_keys(keys)
		return
	end

	if phase ~= "talk" and ((frame - frame0) < min_boot_frames or not ready) then
		apply_keys(0)
		return
	end

	if phase == "boot" then
		set_phase("move")
	elseif phase == "move" then
		keys = move_waypoints()
		if keys == 0 then
			set_phase("talk")
		end
	elseif phase == "talk" then
		if elapsed < 30 then
			keys = UP
		elseif elapsed < 90 then
			keys = 0
		elseif elapsed < 160 then
			keys = A
		elseif elapsed > 300 then
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			state_line("VERIFIED_NURSE")
			apply_keys(0)
			callbacks:remove(cbid)
			return
		end
	end

	if frame - frame0 > 70000 then
		state_line("FAILED_TIMEOUT")
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	apply_keys(keys)
	phase_frame = phase_frame + 1
end)

log("Safari Gauntlet nurse verifier loaded")
state_line("initial")
