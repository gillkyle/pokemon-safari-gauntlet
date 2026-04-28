local log_path = "/tmp/safari-gauntlet-clerk-vendor.log"
local red_screenshot_path = "/tmp/safari-gauntlet-clerk-red.png"
local green_screenshot_path = "/tmp/safari-gauntlet-clerk-green.png"
local blue_screenshot_path = "/tmp/safari-gauntlet-clerk-blue.png"

local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)
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
	player_direction = 0xd4d4,
	crash_code = 0xffe5,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17

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
		"%s map=%d/%d xy=%d,%d dir=%02x",
		prefix,
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_direction)
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

local function drive_boot(frame)
	local t = frame % 90
	if t < 12 then
		return START
	elseif t < 36 then
		return A
	elseif t < 48 then
		return bit(KEY.B)
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
local phase_frame = 0
local frame0 = emu:currentFrame()

local function set_phase(next_phase)
	if phase ~= next_phase then
		phase = next_phase
		phase_frame = 0
		state_line("phase=" .. phase)
	end
end

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local keys = 0
	local in_hub = read8(W.map_group) == GROUP_BATTLE_FACTORY and read8(W.map_number) == MAP_BATTLE_FACTORY_1F

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

	if phase == "boot" then
		set_phase("move_red")
	end

	if phase == "move_red" then
		keys = move_toward(18, 9)
		if keys == 0 then
			set_phase("talk_red")
		end
	elseif phase == "talk_red" then
		if phase_frame < 16 then
			keys = UP
		elseif phase_frame >= 24 and phase_frame < 40 then
			keys = A
		elseif phase_frame == 84 then
			emu:screenshot(red_screenshot_path)
			log("red_screenshot=" .. red_screenshot_path)
			set_phase("close_red")
		end
	elseif phase == "close_red" then
		if phase_frame < 72 then
			keys = bit(KEY.B)
		else
			set_phase("move_green")
		end
	elseif phase == "move_green" then
		keys = move_toward(20, 9)
		if keys == 0 then
			set_phase("talk_green")
		end
	elseif phase == "talk_green" then
		if phase_frame < 16 then
			keys = UP
		elseif phase_frame >= 24 and phase_frame < 40 then
			keys = A
		elseif phase_frame == 84 then
			emu:screenshot(green_screenshot_path)
			log("green_screenshot=" .. green_screenshot_path)
			set_phase("close_green")
		end
	elseif phase == "close_green" then
		if phase_frame < 72 then
			keys = bit(KEY.B)
		else
			set_phase("move_blue")
		end
	elseif phase == "move_blue" then
		keys = move_toward(22, 9)
		if keys == 0 then
			set_phase("talk_blue")
		end
	elseif phase == "talk_blue" then
		if phase_frame < 16 then
			keys = UP
		elseif phase_frame >= 24 and phase_frame < 40 then
			keys = A
		elseif phase_frame == 84 then
			emu:screenshot(blue_screenshot_path)
			log("blue_screenshot=" .. blue_screenshot_path)
			state_line("VERIFIED_CLERK_VENDOR")
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

log("Safari Gauntlet clerk vendor verifier loaded")
state_line("initial")
