local log_path = "/tmp/safari-gauntlet-move-right.log"
local screenshot_path = "/tmp/safari-gauntlet-move-right.png"

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
	player_direction = 0xd4d4,
	crash_code = 0xffe5,
	party_count = 0xdcce,
	step = 0xd7dc,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local phase = "boot"
local phase_frame = 0
local last_log = 0
local max_x = 0

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
		"%s crash=%d map=%d/%d xy=%d,%d dir=%02x party=%d step=%d",
		prefix,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_direction),
		read8(W.party_count),
		read8(W.step)
	))
end

local function set_phase(next_phase)
	if phase ~= next_phase then
		phase = next_phase
		phase_frame = 0
		state_line("phase=" .. phase)
	end
end

local function apply_keys(keys)
	emu:clearKeys(0xffffffff)
	if keys ~= 0 then
		emu:addKeys(keys)
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

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local keys = 0
	local group = read8(W.map_group)
	local map = read8(W.map_number)
	local x = read8(W.x)

	if x > max_x then
		max_x = x
	end

	if read8(W.crash_code) ~= 0 then
		state_line("FAILED_CRASH")
		log("max_x=" .. max_x)
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	if frame - last_log > 180 then
		last_log = frame
		state_line("tick")
	end

	if group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F then
		if phase == "boot" then
			set_phase("move_to_right")
		end

		if phase == "move_to_right" then
			keys = move_toward(20, 9)
			if keys == 0 then
				set_phase("jiggle")
			end
		elseif phase == "jiggle" then
			local t = phase_frame % 120
			if t < 30 then
				keys = LEFT
			elseif t < 60 then
				keys = RIGHT
			elseif t < 90 then
				keys = UP
			else
				keys = DOWN
			end

			if phase_frame > 480 then
				state_line("VERIFIED_MOVE_RIGHT")
				log("max_x=" .. max_x)
				emu:screenshot(screenshot_path)
				log("screenshot=" .. screenshot_path)
				apply_keys(0)
				callbacks:remove(cbid)
				return
			end
		end
	else
		set_phase("boot")
		keys = drive_boot()
	end

	if frame - frame0 > 90000 then
		state_line("FAILED_TIMEOUT")
		log("max_x=" .. max_x)
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	phase_frame = phase_frame + 1
	apply_keys(keys)
end)

log("Safari Gauntlet move-right verifier loaded")
state_line("initial")
