local log_path = "/tmp/safari-gauntlet-defaults.log"
local screenshot_path = "/tmp/safari-gauntlet-defaults.png"

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
	options2 = 0xcff5,
	initial_options = 0xcff6,
	party_count = 0xdcce,
	map_status = 0xd431,
	script_flags = 0xd433,
	script_mode = 0xd436,
	settings = 0xdba1,
	crash_code = 0xffe5,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local SAFARI_GAUNTLET_SETTINGS_NATIONAL = 0x01
local SAFARI_GAUNTLET_SETTINGS_INITIALIZED = 0x20
local PERFECT_IVS_OPT = 0x08
local TRADED_AS_OT_OPT = 0x10

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local hub_seen_frame = nil
local cbid

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

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function state_line(prefix)
	log(string.format(
		"%s crash=%d map=%d/%d xy=%d,%d status=%02x script=%02x/%02x party=%d settings=%02x init_opts=%02x",
		prefix,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.map_status),
		read8(W.script_flags),
		read8(W.script_mode),
		read8(W.party_count),
		read8(W.settings),
		read8(W.initial_options)
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

local function in_hub()
	return read8(W.map_group) == GROUP_BATTLE_FACTORY
		and read8(W.map_number) == MAP_BATTLE_FACTORY_1F
end

local function finish(label)
	state_line(label)
	emu:screenshot(screenshot_path)
	log("screenshot=" .. screenshot_path)
	apply_keys(0)
	callbacks:remove(cbid)
end

cbid = callbacks:add("keysRead", function()
	local frame = emu:currentFrame()
	local keys = 0

	write8(W.options2, read8(W.options2) & 0x3f)
	if read8(W.crash_code) ~= 0 then
		finish("FAILED_CRASH")
		return
	end

	if not in_hub() then
		keys = drive_boot(frame - frame0)
		apply_keys(keys)
		return
	end

	if not hub_seen_frame then
		hub_seen_frame = frame
		state_line("hub_seen")
	end

	if frame - hub_seen_frame > 240
		and read8(W.map_status) == 2
		and read8(W.script_flags) == 0
		and read8(W.script_mode) == 0
		and read8(W.party_count) > 0 then
		local settings = read8(W.settings)
		local initial_options = read8(W.initial_options)
		local ok = (settings & SAFARI_GAUNTLET_SETTINGS_NATIONAL) ~= 0
			and (settings & SAFARI_GAUNTLET_SETTINGS_INITIALIZED) ~= 0
			and (initial_options & PERFECT_IVS_OPT) ~= 0
			and (initial_options & TRADED_AS_OT_OPT) ~= 0
		if ok then
			finish("VERIFIED_DEFAULTS")
		else
			finish("FAILED_DEFAULTS")
		end
		return
	end

	if frame - frame0 > 70000 then
		finish("FAILED_TIMEOUT")
		return
	end

	apply_keys(0)
end)

log("Safari Gauntlet defaults verifier loaded")
state_line("initial")
