local log_path = "/tmp/safari-gauntlet-lucky-egg-bp.log"
local screenshot_path = "/tmp/safari-gauntlet-lucky-egg-bp.png"
local crash_screenshot_path = "/tmp/safari-gauntlet-lucky-egg-bp-crash.png"
local repo = "/Users/kyle/dev/pokecrystal"

local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)
local START = bit(KEY.START)
local UP = bit(KEY.UP)
local DOWN = bit(KEY.DOWN)
local LEFT = bit(KEY.LEFT)
local RIGHT = bit(KEY.RIGHT)

local function read_file(path)
	local handle = assert(io.open(path, "r"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local function load_symbols()
	local symbols = {}
	for line in read_file(repo .. "/polishedcrystal-3.2.3.sym"):gmatch("[^\n]+") do
		local bank, addr, name = line:match("^([0-9A-Fa-f]+):([0-9A-Fa-f]+)%s+(.+)$")
		if bank and addr and name then
			symbols[name] = tonumber(addr, 16)
		end
	end
	return symbols
end

local function item_constant(name)
	local text = read_file(repo .. "/constants/item_constants.asm")
	local hex = text:match("const%s+" .. name .. "%s+;%s*([0-9a-fA-F]+)")
	assert(hex, "missing item constant " .. name)
	return tonumber(hex, 16)
end

local S = load_symbols()
local LUCKY_EGG = item_constant("LUCKY_EGG")
local HARD_STONE = item_constant("HARD_STONE")
local CHARCOAL = item_constant("CHARCOAL")
local RARE_CANDY = item_constant("RARE_CANDY")

local W = {
	map_group = assert(S.wMapGroup, "missing wMapGroup"),
	map_number = assert(S.wMapNumber, "missing wMapNumber"),
	y = assert(S.wYCoord, "missing wYCoord"),
	x = assert(S.wXCoord, "missing wXCoord"),
	map_status = assert(S.wMapStatus, "missing wMapStatus"),
	player_direction = assert(S.wPlayerDirection, "missing wPlayerDirection"),
	script_flags = assert(S.wScriptFlags, "missing wScriptFlags"),
	script_mode = assert(S.wScriptMode, "missing wScriptMode"),
	crash_code = assert(S.hCrashCode, "missing hCrashCode"),
	battle_points = assert(S.wBattlePoints, "missing wBattlePoints"),
	tilemap = 0xc440,
	cur_item = assert(S.wCurItem, "missing wCurItem"),
	item_quantity = assert(S.wItemQuantityChangeBuffer, "missing wItemQuantityChangeBuffer"),
	money_temp = assert(S.hMoneyTemp, "missing hMoneyTemp"),
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

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function state_line(prefix)
	log(string.format(
		"%s map=%d/%d xy=%d,%d dir=%02x status=%02x script=%02x/%02x item=%02x qty=%d bp=%d cost=%d",
		prefix,
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_direction),
		read8(W.map_status),
		read8(W.script_flags),
		read8(W.script_mode),
		read8(W.cur_item),
		read8(W.item_quantity),
		read16be(W.battle_points),
		read16be(W.money_temp + 1)
	))
end

local function tile_sequence_seen(sequence)
	for y = 0, 17 do
		for x = 0, 20 - #sequence do
			local matched = true
			for i, tile in ipairs(sequence) do
				if read8(W.tilemap + y * 20 + x + i - 1) ~= tile then
					matched = false
					break
				end
			end
			if matched then
				return true
			end
		end
	end
	return false
end

local function bsod_seen()
	return tile_sequence_seen({ 0x84, 0x91, 0x91, 0x8e, 0x91 }) -- ERROR
end

local function apply_keys(keys)
	for _, key in ipairs({ KEY.A, KEY.B, KEY.SELECT, KEY.START, KEY.LEFT, KEY.RIGHT, KEY.UP, KEY.DOWN }) do
		emu:clearKey(key)
		if (keys & bit(key)) ~= 0 then
			emu:addKey(key)
		end
	end
end

local function drive_boot(frame)
	if frame > 1500 then
		return 0
	end
	local t = frame % 90
	if t < 12 then
		return START
	elseif t < 36 then
		return A
	elseif t < 48 then
		return bit(KEY.B)
	elseif t < 72 then
		return A
	end
	return 0
end

local function move_toward(tx, ty)
	local x = read8(W.x)
	local y = read8(W.y)
	if y < ty then
		return DOWN
	elseif y > ty then
		return UP
	elseif x < tx then
		return RIGHT
	elseif x > tx then
		return LEFT
	end
	return 0
end

local function is_blue_mart_item(item)
	return item == HARD_STONE or item == CHARCOAL or item == LUCKY_EGG or item == RARE_CANDY
end

local phase = "boot"
local frame0 = emu:currentFrame()
local phase_start_frame = frame0
local min_boot_frames = 1200

local function set_phase(next_phase)
	if phase ~= next_phase then
		phase = next_phase
		phase_start_frame = emu:currentFrame()
		state_line("phase=" .. phase)
	end
end

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local elapsed = frame - phase_start_frame
	local keys = 0
	local in_hub = read8(W.map_group) == GROUP_BATTLE_FACTORY and read8(W.map_number) == MAP_BATTLE_FACTORY_1F
	local ready = in_hub and read8(W.map_status) == 2 and read8(W.script_flags) == 0 and read8(W.script_mode) == 0

	if read8(W.crash_code) ~= 0 or bsod_seen() then
		state_line("FAILED_CRASH")
		emu:screenshot(crash_screenshot_path)
		log("screenshot=" .. crash_screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	if not in_hub then
		keys = drive_boot(frame - frame0)
		apply_keys(keys)
		return
	end

	write8(W.battle_points, 0)
	write8(W.battle_points + 1, 99)

	if phase ~= "talk" and phase ~= "menu" and phase ~= "select_item" and phase ~= "quantity" and phase ~= "confirm" and ((frame - frame0) < min_boot_frames or not ready) then
		apply_keys(0)
		return
	end

	if phase == "boot" then
		set_phase("move")
	end

	if phase == "move" then
		keys = move_toward(22, 8)
		if keys == 0 then
			set_phase("talk")
		elseif frame % 300 == 0 then
			state_line("moving")
		end
	elseif phase == "talk" then
		if elapsed < 30 then
			keys = UP
		elseif elapsed % 90 < 12 then
			keys = A
		end
		if elapsed > 240 and is_blue_mart_item(read8(W.cur_item)) then
			set_phase("menu")
		end
	elseif phase == "menu" then
		if read8(W.cur_item) == LUCKY_EGG then
			set_phase("select_item")
		elseif elapsed % 80 < 12 then
			keys = DOWN
		end
	elseif phase == "select_item" then
		if elapsed < 12 then
			keys = A
		elseif elapsed > 90 then
			set_phase("quantity")
		end
	elseif phase == "quantity" then
		if elapsed > 120 and elapsed < 132 then
			keys = A
		elseif elapsed > 260 then
			set_phase("confirm")
		end
	elseif phase == "confirm" then
		if elapsed > 90 then
			local cost = read16be(W.money_temp + 1)
			local qty = read8(W.item_quantity)
			if cost ~= 12 then
				state_line("FAILED_LUCKY_EGG_CONFIRM_COST_" .. cost)
				emu:screenshot(screenshot_path)
				log("screenshot=" .. screenshot_path)
				apply_keys(0)
				callbacks:remove(cbid)
				return
			end
			if qty ~= 1 then
				state_line("FAILED_LUCKY_EGG_CONFIRM_QTY_" .. qty)
				emu:screenshot(screenshot_path)
				log("screenshot=" .. screenshot_path)
				apply_keys(0)
				callbacks:remove(cbid)
				return
			end
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			state_line("VERIFIED_LUCKY_EGG_BP_CONFIRMATION")
			apply_keys(0)
			callbacks:remove(cbid)
			return
		end
	end

	if frame - frame0 > 70000 then
		state_line("FAILED_TIMEOUT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	apply_keys(keys)
end)

log("Safari Gauntlet Lucky Egg BP verifier loaded")
state_line("initial")
