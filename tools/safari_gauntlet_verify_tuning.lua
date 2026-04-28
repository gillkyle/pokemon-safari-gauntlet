local log_path = "/tmp/safari-gauntlet-tuning.log"
local screenshot_path = "/tmp/safari-gauntlet-tuning.png"

local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)
local START = bit(KEY.START)
local LEFT = bit(KEY.LEFT)
local RIGHT = bit(KEY.RIGHT)
local UP = bit(KEY.UP)
local DOWN = bit(KEY.DOWN)

local W = {
	map_group = 0xdcac,
	map_number = 0xdcad,
	y = 0xdcae,
	x = 0xdcaf,
	options2 = 0xcff5,
	party_count = 0xdcce,
	battle_mode = 0xd233,
	party_mon1 = 0xdcd6,
	num_items = 0xd827,
	items = 0xd828,
	num_medicine = 0xd8bf,
	medicine = 0xd8c0,
	step = 0xd7dc,
	settings = 0xdba1,
	keep_count = 0xdba2,
	keep_species = 0xdba3,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local GROUP_SAFARI_ZONE = 32
local SAFARI_GAUNTLET_STEP_DRAFT = 1
local SAFARI_GAUNTLET_SETTINGS_NO_CARRY_F = 1
local MON_LEVEL_OFFSET = 31
local EEVEE = 133
local RARE_CANDY = 0x30
local SUPER_REPEL = 0x5e

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local phase_frame = 0
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

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function qty_in_pocket(num_addr, pocket_addr, item_id)
	local count = read8(num_addr)
	for i = 0, count - 1 do
		local slot = pocket_addr + i * 2
		if read8(slot) == item_id then
			return read8(slot + 1)
		end
	end
	return 0
end

local function state_line(prefix)
	log(string.format(
		"%s map=%d/%d xy=%d,%d battle=%d step=%d party=%d settings=%02x keep=%d keep_species=%d",
		prefix,
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.battle_mode),
		read8(W.step),
		read8(W.party_count),
		read8(W.settings),
		read8(W.keep_count),
		read8(W.keep_species)
	))
end

local function pulse(key, period, width)
	if phase_frame % period < width then
		return key
	end
	return 0
end

local function apply_keys(keys)
	for _, key in ipairs({KEY.A, KEY.B, KEY.SELECT, KEY.START, KEY.LEFT, KEY.RIGHT, KEY.UP, KEY.DOWN}) do
		emu:clearKey(key)
		if (keys & bit(key)) ~= 0 then
			emu:addKey(key)
		end
	end
end

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local map_group = read8(W.map_group)
	local map_number = read8(W.map_number)
	local step = read8(W.step)
	local keys = 0

	-- Keep text speed and battle animation-friendly options.
	emu:write8(W.options2, read8(W.options2) & 0x3f)

	if frame - last_log > 300 then
		last_log = frame
		state_line("tick")
	end

	if step == SAFARI_GAUNTLET_STEP_DRAFT and map_group == GROUP_SAFARI_ZONE and read8(W.party_count) > 0 then
		local level = read8(W.party_mon1 + MON_LEVEL_OFFSET)
		local species = read8(W.party_mon1)
		local rare_candy_count = qty_in_pocket(W.num_items, W.items, RARE_CANDY)
		local rare_candy_med_count = qty_in_pocket(W.num_medicine, W.medicine, RARE_CANDY)
		local super_repel_count = qty_in_pocket(W.num_items, W.items, SUPER_REPEL)
		local total_rare_candy = rare_candy_count + rare_candy_med_count
		if total_rare_candy == 0 and super_repel_count == 0 then
			keys = pulse(A, 12, 4)
			phase_frame = phase_frame + 1
			apply_keys(keys)
			return
		end

		local keep_count = read8(W.keep_count)
		local settings = read8(W.settings)
		local carry_enabled = (settings & bit(SAFARI_GAUNTLET_SETTINGS_NO_CARRY_F)) == 0
		local expected_species = EEVEE
		if carry_enabled and keep_count > 0 then
			expected_species = read8(W.keep_species)
		end

		local ok = level == 55 and total_rare_candy == 12 and super_repel_count == 3 and species == expected_species
		if ok then
			log(string.format(
				"VERIFIED_TUNING level=%d species=%d expected_species=%d rare_candy=%d super_repel=%d carry_enabled=%d",
				level,
				species,
				expected_species,
				total_rare_candy,
				super_repel_count,
				carry_enabled and 1 or 0
			))
		else
			log(string.format(
				"FAILED_TUNING level=%d species=%d expected_species=%d rare_candy=%d super_repel=%d carry_enabled=%d (items=%d medicine=%d)",
				level,
				species,
				expected_species,
				total_rare_candy,
				super_repel_count,
				carry_enabled and 1 or 0,
				rare_candy_count,
				rare_candy_med_count
			))
		end
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
		return
	end

	if read8(W.battle_mode) ~= 0 then
		keys = pulse(A, 10, 4)
	elseif map_group == GROUP_BATTLE_FACTORY and map_number == MAP_BATTLE_FACTORY_1F and step == 0 then
		if read8(W.x) < 12 then
			keys = RIGHT
		elseif read8(W.x) > 12 then
			keys = LEFT
		elseif read8(W.y) < 6 then
			keys = DOWN
		elseif read8(W.y) > 6 then
			keys = UP
		else
			keys = pulse(A, 12, 4)
		end
	else
		keys = pulse(START | A, 120, 30)
	end

	if frame - frame0 > 120000 then
		state_line("FAILED_TIMEOUT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
		return
	end

	phase_frame = phase_frame + 1
	apply_keys(keys)
end)

log("Safari Gauntlet tuning verifier loaded")
state_line("initial")
