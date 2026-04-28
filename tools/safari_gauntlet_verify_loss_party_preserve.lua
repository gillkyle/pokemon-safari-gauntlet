local log_path = "/tmp/safari-gauntlet-loss-party-preserve.log"
local screenshot_path = "/tmp/safari-gauntlet-loss-party-preserve.png"
local pc_menu_screenshot = "/tmp/safari-gauntlet-loss-party-preserve-pc-menu.png"
local bills_menu_screenshot = "/tmp/safari-gauntlet-loss-party-preserve-bills-pc-menu.png"
local storage_text_screenshot = "/tmp/safari-gauntlet-loss-party-preserve-storage-text.png"
local box_ui_screenshot = "/tmp/safari-gauntlet-loss-party-preserve-box-ui.png"

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
	party_species = 0xdccf,
	party_mon1_species = 0xdcd6,
	party_mon1_form = 0xdceb,
	party_mon1_level = 0xdcf5,
	map_status = 0xd431,
	script_flags = 0xd433,
	script_mode = 0xd436,
	player_direction = 0xd4d4,
	crash_code = 0xffe5,
	safari_balls = 0xdc92,
	safari_time = 0xdc93,
	num_balls = 0xd90b,
	balls = 0xd90c,
	bills_box_list = 0xca0f,
	runs_hi = 0xdb99,
	losses_hi = 0xdb9d,
	step = 0xd7dc,
	battle_mode = 0xd233,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local GROUP_SAFARI_ZONE = 32
local MAP_SAFARI_ZONE_HUB = 1
local SAFARI_GAUNTLET_STEP_DRAFT = 1
local BULBASAUR = 1
local CHARMANDER = 4
local SQUIRTLE = 7
local EEVEE = 133
local CHIKORITA = 152
local CYNDAQUIL = 155
local TOTODILE = 158
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

local function read16(hi)
	return read8(hi) * 256 + read8(hi + 1)
end

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function state_line(prefix)
	log(string.format(
		"%s crash=%d map=%d/%d xy=%d,%d status=%02x script=%02x/%02x party=%d species=%d level=%d step=%d battle=%d balls=%d runs=%d losses=%d",
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
		read8(W.step),
		read8(W.battle_mode),
		read8(W.safari_balls),
		read16(W.runs_hi),
		read16(W.losses_hi)
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

local function seed_bulbasaur_lead()
	if read8(W.party_mon1_species) ~= EEVEE then
		fail("FAILED_EXPECTED_BOOT_EEVEE")
	end
	write8(W.party_mon1_species, BULBASAUR)
	write8(W.party_mon1_form, 0)
	write8(W.party_mon1_level, 55)
	state_line("seeded_bulbasaur_lead")
end

local function start_gauntlet()
	for i = 1, 1800 do
		if in_draft() then
			if read8(W.party_count) ~= 1 or read8(W.party_mon1_species) ~= BULBASAUR then
				fail("FAILED_RUN_DID_NOT_START_WITH_BULBASAUR")
			end
			state_line("draft_started_with_bulbasaur")
			return
		end
		if i % 120 == 0 then
			state_line("start_wait")
		end
		pulse(A)
	end
	fail("FAILED_START_DRAFT")
end

local function force_empty_draft_loss()
	write8(W.party_count, 0)
	write8(W.party_species, 0xff)
	write8(W.safari_balls, 0)
	write8(W.safari_time, 0)
	write8(W.safari_time + 1, 0)
	write8(W.num_balls, 0)
	write8(W.balls, 0xff)
	state_line("forced_empty_draft_loss_state")
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
			state_line("pc_move_wait")
		end
	end
	fail("FAILED_REACH_PC_AFTER_LOSS")
end

local function verify_starter_box_preserved()
	stand_at_pc()
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
	emu:screenshot(box_ui_screenshot)
	log("box_ui_screenshot=" .. box_ui_screenshot)

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
	for i, species in ipairs(expected) do
		local actual = read8(W.bills_box_list + (i - 1) * 2)
		if actual ~= species then
			fail(string.format("FAILED_BOX_SLOT_%d_EXPECTED_%d_GOT_%d", i, species, actual))
		end
	end
	state_line("VERIFIED_LOSS_PARTY_AND_BOX_PRESERVE")
end

local function trigger_loss_and_verify()
	local start_runs = read16(W.runs_hi)
	local start_losses = read16(W.losses_hi)
	for i = 1, 12000 do
		if in_hub()
			and read8(W.map_status) == 2
			and read8(W.script_flags) == 0
			and read8(W.script_mode) == 0
			and read16(W.runs_hi) == start_runs + 1
			and read16(W.losses_hi) == start_losses + 1 then
			if read8(W.party_count) ~= 1 then
				fail("FAILED_PARTY_COUNT_NOT_RESTORED")
			end
			if read8(W.party_mon1_species) ~= BULBASAUR then
				fail("FAILED_LOSS_REPLACED_BULBASAUR")
			end
			state_line("VERIFIED_LOSS_PARTY_PRESERVE")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			verify_starter_box_preserved()
			apply_keys(0)
			return
		end

		if in_draft()
			and read8(W.map_status) == 2
			and read8(W.script_flags) == 0
			and read8(W.script_mode) == 0 then
			local keys = move_toward(16, 25)
			if keys == 0 then
				keys = DOWN
			end
			run_frames(keys, 1)
		else
			pulse(A)
		end

		if i % 300 == 0 then
			state_line("loss_wait")
		end
	end
	fail("FAILED_LOSS_RETURN_TIMEOUT")
end

log("Safari Gauntlet loss party preservation verifier loaded")
state_line("initial")
boot_to_hub()
seed_bulbasaur_lead()
stand_at_reception()
start_gauntlet()
force_empty_draft_loss()
trigger_loss_and_verify()
