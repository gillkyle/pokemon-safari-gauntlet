local log_path = "/tmp/safari-gauntlet-nurse-heal.log"
local screenshot_path = "/tmp/safari-gauntlet-nurse-heal.png"

local repo = "/Users/kyle/dev/pokecrystal"
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

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local SAFARI_GAUNTLET_STEP_ROUND1 = 2
local OW_UP = 0x04

local f = assert(io.open(log_path, "w"))

local function read_file(path)
	local fh = assert(io.open(path, "r"))
	local text = fh:read("*a")
	fh:close()
	return text
end

local function load_symbols()
	local symbols = {}
	for line in read_file(repo .. "/polishedcrystal-3.2.3.sym"):gmatch("[^\n]+") do
		local bank, addr, name = line:match("^(%x%x):(%x%x%x%x)%s+([%w_.$]+)$")
		if bank and addr and name then
			symbols[name] = tonumber(addr, 16)
		end
	end
	return symbols
end

local S = load_symbols()
local W = {
	map_group = S.wMapGroup,
	map_number = S.wMapNumber,
	y = S.wYCoord,
	x = S.wXCoord,
	map_status = S.wMapStatus,
	script_flags = S.wScriptFlags,
	script_mode = S.wScriptMode,
	player_direction = S.wPlayerDirection,
	options2 = S.wOptions2,
	crash_code = S.hCrashCode,
	party_count = S.wPartyCount,
	step = S.wSafariGauntletStep,
	hp = S.wPartyMon1HP,
	max_hp = S.wPartyMon1MaxHP,
	status = S.wPartyMon1Status,
}

for name, value in pairs(W) do
	assert(value ~= nil, "missing symbol " .. name)
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

local function write8(addr, value)
	local offset = wram_offset(addr)
	if offset then
		emu.memory.wram:write8(offset, value & 0xff)
	else
		emu:write8(addr, value & 0xff)
	end
end

local function read16be(addr)
	return read8(addr) * 256 + read8(addr + 1)
end

local function write16be(addr, value)
	write8(addr, (value >> 8) & 0xff)
	write8(addr + 1, value & 0xff)
end

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function state_line(prefix)
	log(string.format(
		"%s crash=%02x map=%d/%d xy=%d,%d status=%02x script=%02x/%02x party=%d step=%d hp=%d/%d mon_status=%02x",
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
		read8(W.step),
		read16be(W.hp),
		read16be(W.max_hp),
		read8(W.status)
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

local function pulse(keys, down_frames, up_frames)
	run_frames(keys, down_frames or 8)
	run_frames(0, up_frames or 22)
end

local function in_hub()
	return read8(W.map_group) == GROUP_BATTLE_FACTORY
		and read8(W.map_number) == MAP_BATTLE_FACTORY_1F
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

local function stand_at_nurse()
	for i = 1, 2400 do
		local keys = move_toward(6, 8)
		if keys == 0 then
			write8(W.player_direction, OW_UP)
			state_line("nurse_ready")
			return
		end
		run_frames(keys, 1)
		if i % 300 == 0 then
			state_line("nurse_move_wait")
		end
	end
	fail("FAILED_REACH_NURSE")
end

local function verify_nurse_heal()
	write8(W.step, SAFARI_GAUNTLET_STEP_ROUND1)
	write16be(W.hp, 1)
	write8(W.status, 0x08)
	stand_at_nurse()
	pulse(A, 10, 20)

	local saw_heal = false
	for i = 1, 3600 do
		if i % 45 == 0 then
			pulse(A, 8, 20)
		else
			run_frames(0, 1)
		end

		if read16be(W.hp) == read16be(W.max_hp) and read8(W.status) == 0 then
			saw_heal = true
		end

		if saw_heal and read8(W.script_flags) == 0 and read8(W.script_mode) == 0 then
			pulse(B, 8, 30)
			state_line("VERIFIED_NURSE_HEAL")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			if read8(W.step) ~= SAFARI_GAUNTLET_STEP_ROUND1 then
				fail("FAILED_STEP_CHANGED")
			end
			apply_keys(0)
			return
		end

		if i % 300 == 0 then
			state_line("nurse_heal_wait")
		end
	end

	fail("FAILED_NURSE_HEAL_TIMEOUT")
end

log("Safari Gauntlet nurse heal verifier loaded")
state_line("initial")
boot_to_hub()
verify_nurse_heal()
