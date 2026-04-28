local log_path = "/tmp/safari-gauntlet-box-clear.log"
local screenshot_path = "/tmp/safari-gauntlet-box-clear.png"

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
	crash_code = 0xffe5,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local hub_frame = nil
local last_log = 0

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
		"%s crash=%d map=%d/%d xy=%d,%d dir=%02x",
		prefix,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_direction)
	))
end

local function apply_keys(keys)
	emu:clearKeys(0xffffffff)
	if keys ~= 0 then
		emu:addKeys(keys)
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

mute_audio()

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local keys = 0
	local in_hub = read8(W.map_group) == GROUP_BATTLE_FACTORY and read8(W.map_number) == MAP_BATTLE_FACTORY_1F

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

	if in_hub then
		if not hub_frame then
			hub_frame = frame
			state_line("hub_reached")
		end
		if frame - hub_frame > 120 then
			state_line("VERIFIED_BOX_CLEAR_VIEW")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			callbacks:remove(cbid)
			return
		end
	else
		keys = drive_boot(frame - frame0)
	end

	if frame - frame0 > 60000 then
		state_line("FAILED_TIMEOUT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	apply_keys(keys)
end)

log("Safari Gauntlet box-clear verifier loaded")
state_line("initial")
