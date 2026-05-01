local log_path = "/tmp/safari-gauntlet-bp-merchant-layout.log"
local screenshot_path = "/tmp/safari-gauntlet-bp-merchant-layout.png"
local crash_screenshot_path = "/tmp/safari-gauntlet-bp-merchant-layout-crash.png"

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
	crash_code = 0xffe5,
	tilemap = 0xc440,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local TARGET_X = 20
local TARGET_Y = 10
local WAYPOINTS = {
	{ 20, 8 },
	{ TARGET_X, TARGET_Y },
}

local f = assert(io.open(log_path, "w"))

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
		"%s map=%d/%d xy=%d,%d dir=%02x status=%02x script=%02x/%02x",
		prefix,
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_direction),
		read8(W.map_status),
		read8(W.script_flags),
		read8(W.script_mode)
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
	if y < ty then
		return DOWN
	elseif y > ty then
		return UP
	elseif x < tx then
		return RIGHT
	elseif x > tx then
		return LEFT
	end
	return 0
end

local phase = "boot"
local frame0 = emu:currentFrame()
local phase_start_frame = frame0
local min_boot_frames = 1200
local waypoint_index = 1

local function set_phase(next_phase)
	if phase ~= next_phase then
		phase = next_phase
		phase_start_frame = emu:currentFrame()
		state_line("phase=" .. phase)
	end
end

local function move_waypoints()
	local target = WAYPOINTS[waypoint_index]
	if not target then
		return 0
	end
	local keys = move_toward(target[1], target[2])
	if keys == 0 then
		waypoint_index = waypoint_index + 1
		return move_waypoints()
	end
	return keys
end

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local elapsed = frame - phase_start_frame
	local keys = 0
	local in_hub = read8(W.map_group) == GROUP_BATTLE_FACTORY and read8(W.map_number) == MAP_BATTLE_FACTORY_1F
	local ready = in_hub and read8(W.map_status) == 2 and read8(W.script_flags) == 0 and read8(W.script_mode) == 0

	if read8(W.crash_code) ~= 0 or bsod_seen() then
		state_line("FAILED_CRASH")
		emu:screenshot(crash_screenshot_path)
		log("screenshot=" .. crash_screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	if not in_hub then
		apply_keys(drive_boot(frame - frame0))
		return
	end

	if phase ~= "verify" and ((frame - frame0) < min_boot_frames or not ready) then
		apply_keys(0)
		return
	end

	if phase == "boot" then
		set_phase("move")
	end

	if phase == "move" then
		keys = move_waypoints()
		if keys == 0 then
			set_phase("verify")
		elseif frame % 300 == 0 then
			state_line("moving_to_former_floor_clerk_tile")
		end
	elseif phase == "verify" then
		if read8(W.x) ~= TARGET_X or read8(W.y) ~= TARGET_Y then
			state_line("FAILED_WRONG_TARGET_TILE")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			callbacks:remove(cbid)
			return
		end
		if elapsed > 120 then
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			state_line("VERIFIED_BP_MERCHANT_LAYOUT former_floor_tile_clear")
			apply_keys(0)
			callbacks:remove(cbid)
			return
		end
	end

	if frame - frame0 > 70000 then
		state_line("FAILED_TIMEOUT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	apply_keys(keys)
end)

log("Safari Gauntlet BP merchant layout verifier loaded")
state_line("initial")
