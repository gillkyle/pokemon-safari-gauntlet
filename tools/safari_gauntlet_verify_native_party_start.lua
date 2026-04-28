local log_path = "/tmp/safari-gauntlet-native-party-start.log"
local screenshot_path = "/tmp/safari-gauntlet-native-party-start.png"

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
	party_count = 0xdcce,
	party_mon1_species = 0xdcd6,
	party_mon1_form = 0xdceb,
	party_mon1_level = 0xdcf5,
	map_status = 0xd431,
	step = 0xd7dc,
	player_direction = 0xd4d4,
	script_flags = 0xd433,
	script_mode = 0xd436,
	crash_code = 0xffe5,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local GROUP_SAFARI_ZONE = 32
local MAP_SAFARI_ZONE_HUB = 1
local SAFARI_GAUNTLET_STEP_DRAFT = 1
local BULBASAUR = 1
local EEVEE = 133
local OW_UP = 0x04

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
		"%s crash=%d map=%d/%d xy=%d,%d status=%02x script=%02x/%02x party=%d species=%d level=%d step=%d",
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
		read8(W.party_mon1_species),
		read8(W.party_mon1_level),
		read8(W.step)
	))
end

local function apply_keys(keys)
	emu:clearKeys(0xffffffff)
	if keys ~= 0 then
		emu:addKeys(keys)
	end
end

local function fail(reason)
	state_line(reason)
	emu:screenshot(screenshot_path)
	log("screenshot=" .. screenshot_path)
	apply_keys(0)
	error(reason)
end

local function run_frames(keys, frames)
	apply_keys(keys)
	for _ = 1, frames do
		write8(W.options2, read8(W.options2) & 0x3f)
		emu:runFrame()
		if read8(W.crash_code) ~= 0 then
			fail("FAILED_CRASH")
		end
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

local function in_draft()
	return read8(W.map_group) == GROUP_SAFARI_ZONE
		and read8(W.map_number) == MAP_SAFARI_ZONE_HUB
		and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT
end

local function boot_to_hub()
	for _ = 1, 80 do
		pulse(START)
		pulse(A)
		pulse(B)
		pulse(A)
		if in_hub() then
			break
		end
	end

	local hub_frame = nil
	for i = 1, 9000 do
		run_frames(0, 1)
		if in_hub() and not hub_frame then
			hub_frame = emu:currentFrame()
			state_line("hub_seen")
		end
		if in_hub()
			and hub_frame
			and emu:currentFrame() - hub_frame > 180
			and read8(W.map_status) == 2
			and read8(W.script_flags) == 0
			and read8(W.script_mode) == 0
			and read8(W.party_count) == 1 then
			state_line("hub_ready")
			return
		end
		if i % 300 == 0 then
			state_line("boot_wait")
		end
	end
	fail("FAILED_BOOT_TO_HUB")
end

local function move_toward(tx, ty)
	if read8(W.x) < tx then
		return RIGHT
	elseif read8(W.x) > tx then
		return LEFT
	elseif read8(W.y) < ty then
		return DOWN
	elseif read8(W.y) > ty then
		return UP
	end
	return 0
end

local function stand_at_reception()
	for i = 1, 2400 do
		local keys = move_toward(12, 8)
		if keys == 0 then
			write8(W.player_direction, OW_UP)
			state_line("reception_ready")
			return
		end
		run_frames(keys, 1)
		if i % 300 == 0 then
			state_line("move_wait")
		end
	end
	fail("FAILED_REACH_RECEPTION")
end

local function seed_native_party_lead()
	if read8(W.party_mon1_species) ~= EEVEE then
		fail("FAILED_EXPECTED_BOOT_EEVEE")
	end
	write8(W.party_mon1_species, BULBASAUR)
	write8(W.party_mon1_form, 0)
	write8(W.party_mon1_level, 44)
	state_line("seeded_bulbasaur_lead")
end

local function start_gauntlet()
	for i = 1, 900 do
		if in_draft() then
			if read8(W.party_mon1_species) ~= BULBASAUR then
				fail("FAILED_PARTY_LEAD_REGENERATED")
			end
			if read8(W.party_mon1_level) ~= 55 then
				fail("FAILED_PARTY_LEAD_NOT_NORMALIZED")
			end
			state_line("VERIFIED_NATIVE_PARTY_START")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			return
		end
		if i % 60 == 0 then
			state_line("start_wait")
		end
		pulse(A)
	end
	fail("FAILED_START_DRAFT")
end

log("Safari Gauntlet native party start verifier loaded")
state_line("initial")
boot_to_hub()
seed_native_party_lead()
stand_at_reception()
start_gauntlet()
