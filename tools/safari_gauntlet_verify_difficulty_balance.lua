local mode = SAFARI_GAUNTLET_DIFFICULTY_MODE or "standard"
local modes = {
	casual = { value = 1, rare_candy = 16, label = "CASUAL" },
	standard = { value = 0, rare_candy = 12, label = "STANDARD" },
	hard = { value = 2, rare_candy = 8, label = "HARD" },
}
local selected = modes[mode]
assert(selected, "unknown difficulty mode: " .. tostring(mode))

local log_path = "/tmp/safari-gauntlet-difficulty-" .. mode .. ".log"
local screenshot_path = "/tmp/safari-gauntlet-difficulty-" .. mode .. ".png"

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
	player_direction = 0xd4d4,
	options2 = 0xcff5,
	party_count = 0xdcce,
	battle_mode = 0xd233,
	num_items = 0xd827,
	items = 0xd828,
	num_medicine = 0xd8bf,
	medicine = 0xd8c0,
	map_status = 0xd431,
	script_flags = 0xd433,
	script_mode = 0xd436,
	settings = 0xdba1,
	step = 0xd7dc,
	crash_code = 0xffe5,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local GROUP_SAFARI_ZONE = 32
local SAFARI_GAUNTLET_STEP_DRAFT = 1
local SAFARI_GAUNTLET_SETTINGS_NATIONAL = 0x01
local SAFARI_GAUNTLET_SETTINGS_INITIALIZED = 0x20
local SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_MASK = 0x18
local RARE_CANDY = 0x30
local OW_UP = 0x04

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local phase = "boot"
local phase_frame = 0
local last_log = 0
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

local function total_rare_candy()
	return qty_in_pocket(W.num_items, W.items, RARE_CANDY)
		+ qty_in_pocket(W.num_medicine, W.medicine, RARE_CANDY)
end

local function state_line(prefix)
	log(string.format(
		"%s mode=%s crash=%d map=%d/%d xy=%d,%d party=%d battle=%d step=%d settings=%02x rare_candy=%d",
		prefix,
		mode,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.party_count),
		read8(W.battle_mode),
		read8(W.step),
		read8(W.settings),
		total_rare_candy()
	))
end

local function apply_keys(keys)
	for _, key in ipairs({ KEY.A, KEY.B, KEY.SELECT, KEY.START, KEY.LEFT, KEY.RIGHT, KEY.UP, KEY.DOWN }) do
		emu:clearKey(key)
		if (keys & bit(key)) ~= 0 then
			emu:addKey(key)
		end
	end
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

local function finish(label)
	state_line(label)
	emu:screenshot(screenshot_path)
	log("screenshot=" .. screenshot_path)
	apply_keys(0)
	callbacks:remove(cbid)
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
	return 0
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

local function set_difficulty()
	local settings = read8(W.settings)
	settings = settings & (0xff ~ SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_MASK)
	settings = settings | (selected.value << 3) | SAFARI_GAUNTLET_SETTINGS_NATIONAL | SAFARI_GAUNTLET_SETTINGS_INITIALIZED
	write8(W.settings, settings)
end

local function in_hub()
	return read8(W.map_group) == GROUP_BATTLE_FACTORY
		and read8(W.map_number) == MAP_BATTLE_FACTORY_1F
end

local function in_draft()
	return read8(W.map_group) == GROUP_SAFARI_ZONE
		and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT
end

cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local keys = 0

	write8(W.options2, read8(W.options2) & 0x3f)
	if read8(W.crash_code) ~= 0 then
		finish("FAILED_CRASH")
		return
	end

	if frame - last_log > 300 then
		last_log = frame
		state_line("tick")
	end

	if phase == "boot" then
		if in_hub()
			and read8(W.map_status) == 2
			and read8(W.script_flags) == 0
			and read8(W.script_mode) == 0
			and read8(W.party_count) > 0 then
			set_difficulty()
			set_phase("move_reception")
		else
			keys = drive_boot()
		end
	elseif phase == "move_reception" then
		keys = move_toward(12, 6)
		if keys == 0 then
			write8(W.player_direction, OW_UP)
			set_phase("start")
		end
	elseif phase == "start" then
		if in_draft() and read8(W.party_count) > 0 then
			local actual = total_rare_candy()
			if actual == selected.rare_candy then
				finish("VERIFIED_DIFFICULTY_" .. selected.label)
			else
				finish("FAILED_DIFFICULTY_" .. selected.label .. "_RARE_CANDY_" .. actual)
			end
			return
		end
		keys = pulse(A, 12, 4)
	end

	if frame - frame0 > 120000 then
		finish("FAILED_TIMEOUT")
		return
	end

	phase_frame = phase_frame + 1
	apply_keys(keys)
end)

log("Safari Gauntlet difficulty balance verifier loaded mode=" .. mode)
state_line("initial")
