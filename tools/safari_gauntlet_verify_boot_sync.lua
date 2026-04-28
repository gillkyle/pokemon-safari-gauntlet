local log_path = "/tmp/safari-gauntlet-boot-sync.log"
local screenshot_path = "/tmp/safari-gauntlet-boot-sync.png"

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
	script_flags = 0xd433,
	script_mode = 0xd436,
	crash_code = 0xffe5,
	party_count = 0xdcce,
	step = 0xd7dc,
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
		"%s crash=%d map=%d/%d xy=%d,%d dir=%02x script=%02x/%02x party=%d step=%d",
		prefix,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_direction),
		read8(W.script_flags),
		read8(W.script_mode),
		read8(W.party_count),
		read8(W.step)
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

local function run_frames(keys, frames)
	apply_keys(keys)
	for _ = 1, frames do
		emu:runFrame()
	end
	apply_keys(0)
end

local function pulse(keys)
	run_frames(keys, 8)
	run_frames(0, 22)
end

local function in_hub()
	return read8(W.map_group) == GROUP_BATTLE_FACTORY
		and read8(W.map_number) == MAP_BATTLE_FACTORY_1F
end

log("Safari Gauntlet synchronous boot verifier loaded")
state_line("initial")

-- Skip intro/title noise and choose New Game once, then release input. Holding
-- input during the overworld bootstrap can mask a real boot bug.
for _ = 1, 80 do
	pulse(START)
	pulse(A)
	pulse(B)
	pulse(A)
	if in_hub() then
		break
	end
end

local reached = false
local first_hub_frame = nil
for i = 1, 9000 do
	run_frames(0, 1)
	if i % 300 == 0 then
		state_line("wait")
	end
	if read8(W.crash_code) ~= 0 then
		state_line("FAILED_CRASH")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		return
	end
	if in_hub() and not first_hub_frame then
		first_hub_frame = emu:currentFrame()
		state_line("hub_seen")
	end
	if in_hub()
		and first_hub_frame
		and emu:currentFrame() - first_hub_frame > 240
		and read8(W.party_count) > 0 then
		reached = true
		break
	end
end

if reached then
	state_line("VERIFIED_BOOT_REACHED_HUB_WITH_PARTY")
else
	if in_hub() and read8(W.party_count) == 0 then
		state_line("FAILED_BOOT_NO_PARTY")
	else
		state_line("FAILED_BOOT_TIMEOUT")
	end
end
emu:screenshot(screenshot_path)
log("screenshot=" .. screenshot_path)
