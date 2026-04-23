local log_path = "/tmp/safari-gauntlet-hub-text.log"
local screenshot_path = "/tmp/safari-gauntlet-hub-text.png"

local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)
local B = bit(KEY.B)
local START = bit(KEY.START)
local UP = bit(KEY.UP)

local W = {
	map_group = 0xdcac,
	map_number = 0xdcad,
	y = 0xdcae,
	x = 0xdcaf,
	options2 = 0xcff5,
	player_direction = 0xd4d4,
	last_talked = 0xffc7,
	script_flags = 0xd433,
	script_mode = 0xd436,
	script_bank = 0xffeb,
	script_pos = 0xffec,
	crash_code = 0xffe5,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local hub_frame = nil
local opened_frame = nil
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

local function read16le(lo)
	return read8(lo) + read8(lo + 1) * 256
end

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function state_line(prefix)
	log(string.format(
		"%s crash=%d map=%d/%d xy=%d,%d dir=%02x talked=%d script=%02x/%02x pc=%02x:%04x",
		prefix,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_direction),
		read8(W.last_talked),
		read8(W.script_flags),
		read8(W.script_mode),
		read8(W.script_bank),
		read16le(W.script_pos)
	))
end

local function apply_keys(keys)
	for _, key in ipairs({KEY.A, KEY.B, KEY.SELECT, KEY.START, KEY.LEFT, KEY.RIGHT, KEY.UP, KEY.DOWN}) do
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
	elseif t < 28 then
		return A
	elseif t < 42 then
		return B
	elseif t < 58 then
		return A
	end
	return 0
end

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local keys = 0

	write8(W.options2, read8(W.options2) & 0x3f)

	if read8(W.crash_code) ~= 0 then
		state_line("FAILED_CRASH")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
		return
	end

	if frame - last_log > 120 then
		last_log = frame
		state_line("tick")
	end

	if read8(W.map_group) == GROUP_BATTLE_FACTORY and read8(W.map_number) == MAP_BATTLE_FACTORY_1F then
		if not hub_frame then
			hub_frame = frame
			state_line("hub_ready")
		end

		local elapsed = frame - hub_frame
		if elapsed < 30 then
			keys = 0
		elseif elapsed < 70 then
			keys = UP
		elseif not opened_frame and read8(W.script_flags) == 0 and read8(W.script_bank) == 0 then
			if elapsed % 12 < 5 then
				keys = A
			end
		elseif not opened_frame then
			opened_frame = frame
			state_line("text_opened")
		elseif opened_frame and frame - opened_frame > 45 then
			state_line("VERIFIED_HUB_TEXT_SCREENSHOT")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			callbacks:remove(cbid)
			return
		end
	else
		keys = drive_boot(frame - frame0)
	end

	if frame - frame0 > 120000 then
		state_line("FAILED_TIMEOUT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
		return
	end

	apply_keys(keys)
end)

log("Safari Gauntlet hub text verifier loaded")
state_line("initial")
