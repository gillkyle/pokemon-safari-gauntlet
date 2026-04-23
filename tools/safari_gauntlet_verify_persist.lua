local log_path = "/tmp/safari-gauntlet-persist.log"
local screenshot_path = "/tmp/safari-gauntlet-persist.png"

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
	player_gender = 0xd47a,
	johto_badges = 0xd7ee,
	bp_hi = 0xdc88,
	runs_hi = 0xdb99,
	wins_hi = 0xdb9b,
	losses_hi = 0xdb9d,
	settings = 0xdba1,
	keep_count = 0xdba2,
	party_count = 0xdcce,
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

local function read16(hi)
	return read8(hi) * 256 + read8(hi + 1)
end

local function state_line(prefix)
	log(string.format(
		"%s map=%d/%d xy=%d,%d gender=%d badges=%02x settings=%02x runs=%d wins=%d losses=%d keep=%d bp=%d party=%d",
		prefix,
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_gender),
		read8(W.johto_badges),
		read8(W.settings),
		read16(W.runs_hi),
		read16(W.wins_hi),
		read16(W.losses_hi),
		read8(W.keep_count),
		read16(W.bp_hi),
		read8(W.party_count)
	))
end

local frame0 = emu:currentFrame()
local phase_frame = 0
local last_log = 0

local function drive_continue()
	local t = phase_frame % 90
	if t < 12 then
		return START
	elseif t < 30 then
		return A
	elseif t < 44 then
		return B
	elseif t < 60 then
		return A
	end
	return 0
end

local function apply_keys(keys)
	for _, key in ipairs({
		KEY.A,
		KEY.B,
		KEY.SELECT,
		KEY.START,
	}) do
		emu:clearKey(key)
		if (keys & bit(key)) ~= 0 then
			emu:addKey(key)
		end
	end
end

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local group = read8(W.map_group)
	local map = read8(W.map_number)

	if frame - last_log > 300 then
		last_log = frame
		state_line("tick")
	end

	if group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F then
		if read16(W.runs_hi) >= 1 and read16(W.wins_hi) >= 1 and read8(W.keep_count) >= 1 and read16(W.bp_hi) >= 18 and (read8(W.johto_badges) & 0x80) ~= 0 and read8(W.party_count) == 0 then
			state_line("VERIFIED_PERSIST")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			callbacks:remove(cbid)
			return
		end
	end

	if frame - frame0 > 36000 then
		state_line("FAILED_TIMEOUT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
		return
	end

	phase_frame = phase_frame + 1
	apply_keys(drive_continue())
end)

log("Safari Gauntlet persistence verifier loaded")
state_line("initial")
