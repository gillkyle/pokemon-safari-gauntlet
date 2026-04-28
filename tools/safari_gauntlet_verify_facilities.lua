local log_path = "/tmp/safari-gauntlet-facilities.log"
local keepbox_screenshot = "/tmp/safari-gauntlet-keepbox.png"
local tutor_screenshot = "/tmp/safari-gauntlet-movetutor.png"
local tm_screenshot = "/tmp/safari-gauntlet-tmvendor.png"
local clerk_screenshot = "/tmp/safari-gauntlet-clerk.png"

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
		return B
	elseif t < 72 then
		return A
	end
	return 0
end

local phase = "boot"
local phase_frame = 0
local frame0 = emu:currentFrame()

mute_audio()

local function set_phase(next_phase)
	if phase ~= next_phase then
		phase = next_phase
		phase_frame = 0
		state_line("phase=" .. phase)
	end
end

local function move_toward(tx, ty, prefer_x)
	local x = read8(W.x)
	local y = read8(W.y)
	if prefer_x then
		if x < tx then
			return RIGHT
		elseif x > tx then
			return LEFT
		elseif y < ty then
			return DOWN
		elseif y > ty then
			return UP
		end
	else
		if y < ty then
			return DOWN
		elseif y > ty then
			return UP
		elseif x < tx then
			return RIGHT
		elseif x > tx then
			return LEFT
		end
	end
	return 0
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
		set_phase("move_keepbox")
	end

	if phase == "move_keepbox" then
		keys = move_toward(8, 9, false)
		if keys == 0 then
			set_phase("talk_keepbox")
		end
	elseif phase == "talk_keepbox" then
		if phase_frame < 16 then
			keys = UP
		elseif phase_frame < 36 then
			keys = A
		elseif phase_frame == 72 then
			emu:screenshot(keepbox_screenshot)
			log("keepbox_screenshot=" .. keepbox_screenshot)
		elseif phase_frame < 240 then
			keys = B
		elseif phase_frame > 260 then
			set_phase("move_tutor")
		end
	elseif phase == "move_tutor" then
		keys = move_toward(15, 9, true)
		if keys == 0 then
			set_phase("talk_tutor")
		end
	elseif phase == "talk_tutor" then
		if phase_frame < 16 then
			keys = UP
		elseif phase_frame < 36 then
			keys = A
		elseif phase_frame == 72 then
			emu:screenshot(tutor_screenshot)
			log("tutor_screenshot=" .. tutor_screenshot)
		elseif phase_frame < 220 then
			keys = B
		elseif phase_frame > 240 then
			set_phase("move_tm")
		end
	elseif phase == "move_tm" then
		keys = move_toward(24, 9, true)
		if keys == 0 then
			set_phase("talk_tm")
		end
	elseif phase == "talk_tm" then
		if phase_frame < 16 then
			keys = UP
		elseif phase_frame < 36 then
			keys = A
		elseif phase_frame == 72 then
			emu:screenshot(tm_screenshot)
			log("tm_screenshot=" .. tm_screenshot)
		elseif phase_frame > 100 then
			set_phase("close_tm")
		end
	elseif phase == "close_tm" then
		if phase_frame < 120 then
			keys = A
		elseif phase_frame < 300 then
			keys = B
		else
			set_phase("move_clerk")
		end
	elseif phase == "move_clerk" then
		keys = move_toward(18, 7, true)
		if keys == 0 then
			set_phase("talk_clerk")
		end
	elseif phase == "talk_clerk" then
		if phase_frame < 16 then
			keys = UP
		elseif phase_frame < 36 then
			keys = A
		elseif phase_frame == 72 then
			emu:screenshot(clerk_screenshot)
			log("clerk_screenshot=" .. clerk_screenshot)
		elseif phase_frame > 110 then
			state_line("VERIFIED_FACILITIES")
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

log("Safari Gauntlet facilities verifier loaded")
state_line("initial")
