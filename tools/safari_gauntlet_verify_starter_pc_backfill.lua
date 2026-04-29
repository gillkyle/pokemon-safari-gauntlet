local log_path = "/tmp/safari-gauntlet-starter-pc-backfill.log"
local screenshot_path = "/tmp/safari-gauntlet-starter-pc-backfill.png"
local pc_menu_screenshot = "/tmp/safari-gauntlet-starter-pc-backfill-pc-menu.png"
local bills_menu_screenshot = "/tmp/safari-gauntlet-starter-pc-backfill-bills-menu.png"
local storage_text_screenshot = "/tmp/safari-gauntlet-starter-pc-backfill-storage-text.png"

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
local OW_UP = 0x04
local STARTER_PC_SEEDED_MASK = 0x40

local EEVEE = 133
local BULBASAUR = 1
local CHARMANDER = 4
local SQUIRTLE = 7
local CHIKORITA = 152
local CYNDAQUIL = 155
local TOTODILE = 158

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
	player_direction = S.wPlayerDirection,
	options2 = S.wOptions2,
	party_count = S.wPartyCount,
	map_status = S.wMapStatus,
	script_flags = S.wScriptFlags,
	script_mode = S.wScriptMode,
	settings = S.wSafariGauntletSettings,
	step = S.wSafariGauntletStep,
	cur_box = S.wCurBox,
	bills_box_list = S.wBillsPC_BoxList,
	crash_code = S.hCrashCode,
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

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function state_line(prefix)
	log(string.format(
		"%s crash=%02x map=%d/%d xy=%d,%d status=%02x script=%02x/%02x party=%d step=%d cur_box=%d settings=%02x",
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
		read8(W.cur_box),
		read8(W.settings)
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
	run_frames(0, up_frames or 24)
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

local function stand_at_pc()
	for i = 1, 2400 do
		local keys = move_toward(5, 8)
		if keys == 0 then
			write8(W.player_direction, OW_UP)
			state_line("pc_ready")
			return
		end
		run_frames(keys, 1)
		if i % 300 == 0 then
			state_line("move_wait")
		end
	end
	fail("FAILED_REACH_PC")
end

local function simulate_existing_save_needing_backfill()
	write8(W.settings, read8(W.settings) & 0xbf)
	write8(W.cur_box, 1)
	state_line("simulated_existing_save_missing_marker")
end

local function open_pc_to_box_ui()
	pulse(A, 10, 70)
	emu:screenshot(pc_menu_screenshot)
	log("pc_menu_screenshot=" .. pc_menu_screenshot)
	pulse(A, 10, 70)
	emu:screenshot(bills_menu_screenshot)
	log("bills_menu_screenshot=" .. bills_menu_screenshot)
	pulse(A, 10, 360)
	emu:screenshot(storage_text_screenshot)
	log("storage_text_screenshot=" .. storage_text_screenshot)
	pulse(A, 10, 600)
	pulse(A, 10, 600)
	emu:screenshot(screenshot_path)
	log("screenshot=" .. screenshot_path)
end

local function verify_box_contents()
	local expected = {
		EEVEE,
		EEVEE,
		BULBASAUR,
		CHARMANDER,
		SQUIRTLE,
		CHIKORITA,
		CYNDAQUIL,
		TOTODILE,
	}
	if (read8(W.settings) & STARTER_PC_SEEDED_MASK) == 0 then
		fail("FAILED_STARTER_PC_MARKER_NOT_SET")
	end
	for i, species in ipairs(expected) do
		local actual = read8(W.bills_box_list + (i - 1) * 2)
		if actual ~= species then
			fail(string.format("FAILED_BACKFILL_SLOT_%d_EXPECTED_%d_GOT_%d", i, species, actual))
		end
	end
	state_line("VERIFIED_STARTER_PC_BACKFILL")
end

log("Safari Gauntlet starter PC backfill verifier loaded")
state_line("initial")
boot_to_hub()
simulate_existing_save_needing_backfill()
stand_at_pc()
open_pc_to_box_ui()
verify_box_contents()
apply_keys(0)
