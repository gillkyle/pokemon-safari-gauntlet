local log_path = "/tmp/safari-gauntlet-diversity.log"
local screenshot_path = "/tmp/safari-gauntlet-diversity.png"

local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)
local B = bit(KEY.B)
local START = bit(KEY.START)
local UP = bit(KEY.UP)
local LEFT = bit(KEY.LEFT)
local RIGHT = bit(KEY.RIGHT)
local DOWN = bit(KEY.DOWN)

local W = {
	map_group = 0xdcac,
	map_number = 0xdcad,
	x = 0xdcaf,
	y = 0xdcae,
	player_direction = 0xd4d4,
	options2 = 0xcff5,
	settings = 0xdba1,
	step = 0xd7dc,
	battle_mode = 0xd233,
	battle_type = 0xd236,
	enemy_species = 0xd209,
	enemy_form = 0xd213,
	enemy_level = 0xd219,
	enemy_hp = 0xd21c,
	time_remaining = 0xdc93,
	wild_cooldown = 0xd464,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local GROUP_SAFARI_ZONE = 32
local MAP_SAFARI_ZONE_HUB = 1
local MAP_SAFARI_ZONE_EAST = 2
local MAP_SAFARI_ZONE_NORTH = 3
local MAP_SAFARI_ZONE_WEST = 4
local SAFARI_GAUNTLET_STEP_DRAFT = 1
local SAFARI_GAUNTLET_SETTINGS_NATIONAL = 0x01
local BATTLEMODE_WILD = 1

local frame0 = emu:currentFrame()
local phase = "boot"
local phase_frame = 0
local last_log = 0
local hub_seen = false
local encounters = 0
local unique = 0
local seen = {}
local maps_seen = {}

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

local function write16(addr, value)
	write8(addr, value // 256)
	write8(addr + 1, value % 256)
end

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function state_line(prefix)
	log(string.format(
		"%s map=%d/%d xy=%d,%d step=%d battle=%d mode=%02x encounters=%d unique=%d",
		prefix,
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.step),
		read8(W.battle_mode),
		read8(W.settings),
		encounters,
		unique
	))
end

local function set_phase(next_phase)
	if phase ~= next_phase then
		phase = next_phase
		phase_frame = 0
		state_line("phase=" .. phase)
	end
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

local function record_map()
	if read8(W.map_group) ~= GROUP_SAFARI_ZONE then
		return
	end
	local map = read8(W.map_number)
	if not maps_seen[map] then
		maps_seen[map] = true
		log("MAP_SEEN " .. map)
	end
end

local function map_count()
	local c = 0
	for _ in pairs(maps_seen) do
		c = c + 1
	end
	return c
end

local function drive_boot()
	local t = phase_frame % 90
	if t < 12 then
		return START
	elseif t < 28 then
		return A
	elseif t < 42 then
		return B
	elseif t < 58 then
		return A
	end
	return pulse(A, 120, 60)
end

local function drive_field()
	write8(W.wild_cooldown, 0)
	write16(W.time_remaining, 0x03ff)
	local x = read8(W.x)
	local y = read8(W.y)
	if y >= 24 then
		if x < 20 then
			return RIGHT
		end
		return UP
	end
	if x < 24 then
		return RIGHT
	elseif x > 29 then
		return LEFT
	elseif y < 8 then
		return DOWN
	elseif y > 23 then
		return UP
	end
	local t = phase_frame % 160
	if t < 40 then
		return UP
	elseif t < 80 then
		return RIGHT
	elseif t < 120 then
		return DOWN
	end
	return LEFT
end

local function drive_hub()
	if read8(W.x) < 12 then
		return RIGHT
	elseif read8(W.x) > 12 then
		return LEFT
	elseif read8(W.y) < 8 then
		return DOWN
	elseif read8(W.y) > 8 then
		return UP
	elseif read8(W.player_direction) ~= 0x04 then
		write8(W.player_direction, 0x04)
		return 0
	elseif phase_frame < 90 then
		return 0
	end
	return pulse(A, 12, 4)
end

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local group = read8(W.map_group)
	local map = read8(W.map_number)
	local battle_mode = read8(W.battle_mode)
	local keys = 0

	if group == 0 and map == 0 and phase == "hub" then
		group = GROUP_BATTLE_FACTORY
		map = MAP_BATTLE_FACTORY_1F
	end

	write8(W.options2, read8(W.options2) & 0x3f)

	if group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F and read8(W.step) == 0 then
		-- Force National mode for this verifier.
		write8(W.settings, read8(W.settings) | SAFARI_GAUNTLET_SETTINGS_NATIONAL)
	end

	if battle_mode == BATTLEMODE_WILD and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT then
		local species = read8(W.enemy_species)
		local form = read8(W.enemy_form)
		local level = read8(W.enemy_level)
		if level == 30 and species > 0 then
			local key = string.format("%02x:%02x", species, form & 0x3f)
			if not seen[key] then
				seen[key] = true
				unique = unique + 1
				log(string.format("NEW_ENCOUNTER species=%02x form=%02x unique=%d", species, form, unique))
			end
			encounters = encounters + 1
		end
		write8(W.enemy_hp, 0)
		write8(W.enemy_hp + 1, 0)
		set_phase("battle")
		keys = pulse(A, 8, 4)
	else
		if group == GROUP_SAFARI_ZONE and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT and map >= MAP_SAFARI_ZONE_HUB and map <= MAP_SAFARI_ZONE_WEST then
			record_map()
			set_phase("field")
			keys = drive_field()
		elseif group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F then
			set_phase("hub")
			if not hub_seen then
				hub_seen = true
				state_line("HUB_REACHED")
			end
			keys = drive_hub()
		else
			if hub_seen then
				set_phase("idle")
				keys = 0
			else
				set_phase("boot")
				keys = drive_boot()
			end
		end
	end

	if frame - last_log > 300 then
		last_log = frame
		state_line("tick")
	end

	if encounters >= 120 and unique >= 45 then
		state_line(string.format("VERIFIED_DIVERSITY encounters=%d unique=%d maps=%d", encounters, unique, map_count()))
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
		return
	end

	if frame - frame0 > 180000 then
		state_line(string.format("FAILED_TIMEOUT encounters=%d unique=%d maps=%d", encounters, unique, map_count()))
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
		return
	end

	phase_frame = phase_frame + 1
	apply_keys(keys)
end)

log("Safari Gauntlet diversity verifier loaded")
state_line("initial")
