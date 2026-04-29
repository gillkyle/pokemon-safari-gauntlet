local log_path = "/tmp/safari-gauntlet-pc-locked-midrun.log"
local screenshot_path = "/tmp/safari-gauntlet-pc-locked-midrun.png"

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
			symbols[name .. "_bank"] = tonumber(bank, 16)
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
	script_text_addr = S.wScriptTextAddr,
	player_direction = S.wPlayerDirection,
	options2 = S.wOptions2,
	crash_code = S.hCrashCode,
	party_count = S.wPartyCount,
	step = S.wSafariGauntletStep,
	pc_blocked_text = S.SafariGauntletPCBlockedDuringRunText,
	pc_open_text = S.SafariGauntletKeepBoxOpenPCText,
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

local function read16(hi)
	return read8(hi) * 256 + read8(hi + 1)
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
		"%s crash=%02x map=%d/%d xy=%d,%d status=%02x script=%02x/%02x text=%04x party=%d step=%d",
		prefix,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.map_status),
		read8(W.script_flags),
		read8(W.script_mode),
		read16le(W.script_text_addr),
		read8(W.party_count),
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

local function stand_at_pc(target)
	for i = 1, 2400 do
		local keys = move_toward(target.x, target.y)
		if keys == 0 then
			write8(W.player_direction, OW_UP)
			state_line(target.name .. "_ready")
			return
		end
		run_frames(keys, 1)
		if i % 300 == 0 then
			state_line("pc_move_wait")
		end
	end
	fail("FAILED_REACH_PC")
end

local function wait_until_ready()
	for i = 1, 900 do
		if read8(W.script_flags) == 0 and read8(W.script_mode) == 0 then
			return
		end
		if i % 45 == 0 then
			pulse(B, 8, 20)
		elseif i % 75 == 0 then
			pulse(A, 8, 20)
		else
			run_frames(0, 1)
		end
	end
	fail("FAILED_SCRIPT_DID_NOT_CLOSE")
end

local function verify_one_pc_locked(target)
	stand_at_pc(target)
	for i = 1, 2400 do
		pulse(A)
		local text_addr = read16le(W.script_text_addr)
		if text_addr == W.pc_open_text then
			fail("FAILED_PC_OPEN_TEXT_DURING_RUN_" .. target.name)
		end
		if text_addr == W.pc_blocked_text then
			state_line("VERIFIED_PC_BLOCKED_TEXT_" .. target.name)
			pulse(B)
			wait_until_ready()
			if read8(W.step) ~= SAFARI_GAUNTLET_STEP_ROUND1 then
				fail("FAILED_STEP_CHANGED")
			end
			apply_keys(0)
			return
		end
		if i % 120 == 0 then
			state_line(target.name .. "_lock_wait")
		end
	end
	fail("FAILED_PC_LOCK_TIMEOUT_" .. target.name)
end

local function verify_pc_locked()
	write8(W.step, SAFARI_GAUNTLET_STEP_ROUND1)
	verify_one_pc_locked({ name = "left_pc", x = 5, y = 8 })
	verify_one_pc_locked({ name = "box_computer", x = 9, y = 8 })
	state_line("VERIFIED_PC_BLOCKED_TEXT_ALL")
	emu:screenshot(screenshot_path)
	log("screenshot=" .. screenshot_path)
end

log("Safari Gauntlet active-run PC lock verifier loaded")
state_line("initial")
boot_to_hub()
verify_pc_locked()
