local log_path = "/tmp/safari-gauntlet-hp-clamp.log"
local screenshot_path = "/tmp/safari-gauntlet-hp-clamp.png"

local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)
local B = bit(KEY.B)
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
	battle_menu_cursor = 0xd0d8,
	menu_cursor_buffer = 0xce2f,
	battle_mon_hp = 0xc758,
	battle_mon_max_hp = 0xc75a,
	enemy_hp = 0xd21c,
	enemy_attack = 0xd220,
	enemy_sp_atk = 0xd226,
	num_balls = 0xd90b,
	balls = 0xd90c,
	step = 0xd7dc,
	party_mon1 = 0xdcd6,
	party_mon1_ot = 0xddf6,
	party_mon1_nickname = 0xde38,
	party_mon1_hp = 0xdcf8,
	party_mon1_max_hp = 0xdcfa,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local MASTER_BALL = 4
local SAFARI_GAUNTLET_STEP_DRAFT = 1
local PARTYMON_STRUCT_LENGTH = 0x30
local PARTYMON_NAME_LENGTH = 0x0b

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local phase = "boot"
local phase_frame = 0
local supplies_seen = false
local injected = false
local wait_for_clamp = nil
local hub_ready_frame = nil

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

local function write16(hi, value)
	write8(hi, value // 256)
	write8(hi + 1, value % 256)
end

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function ball_qty(item)
	local count = read8(W.num_balls)
	for i = 0, count - 1 do
		local slot = W.balls + i * 2
		if read8(slot) == item then
			return read8(slot + 1)
		end
	end
	return 0
end

local function state_line(prefix)
	log(string.format(
		"%s map=%d/%d party=%d battle=%d step=%d hp=%d/%d battle_hp=%d/%d master=%d",
		prefix,
		read8(W.map_group),
		read8(W.map_number),
		read8(W.party_count),
		read8(W.battle_mode),
		read8(W.step),
		read16(W.party_mon1_hp),
		read16(W.party_mon1_max_hp),
		read16(W.battle_mon_hp),
		read16(W.battle_mon_max_hp),
		ball_qty(MASTER_BALL)
	))
end

local function pulse(key, period, width)
	if phase_frame % period < width then
		return key
	end
	return 0
end

local function set_phase(next_phase)
	if phase ~= next_phase then
		phase = next_phase
		phase_frame = 0
		state_line("phase=" .. phase)
	end
end

local function clone_starter_party()
	for i = 1, 5 do
		local dst = W.party_mon1 + i * PARTYMON_STRUCT_LENGTH
		for j = 0, PARTYMON_STRUCT_LENGTH - 1 do
			write8(dst + j, read8(W.party_mon1 + j))
		end
		local dst_ot = W.party_mon1_ot + i * PARTYMON_NAME_LENGTH
		local dst_name = W.party_mon1_nickname + i * PARTYMON_NAME_LENGTH
		for j = 0, PARTYMON_NAME_LENGTH - 1 do
			write8(dst_ot + j, read8(W.party_mon1_ot + j))
			write8(dst_name + j, read8(W.party_mon1_nickname + j))
		end
	end
	write8(W.party_count, 6)
end

local function apply_keys(keys)
	for _, key in ipairs({
		KEY.A,
		KEY.B,
		KEY.SELECT,
		KEY.START,
		KEY.RIGHT,
		KEY.LEFT,
		KEY.UP,
		KEY.DOWN,
	}) do
		emu:clearKey(key)
		if (keys & bit(key)) ~= 0 then
			emu:addKey(key)
		end
	end
end

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local group = read8(W.map_group)
	local map = read8(W.map_number)
	local battle_mode = read8(W.battle_mode)
	local keys = 0

	write8(W.options2, read8(W.options2) & 0x3f)

	if not supplies_seen and read8(W.party_count) > 0 and ball_qty(MASTER_BALL) >= 1 then
		supplies_seen = true
		state_line("SUPPLIES_AND_STARTER_SEEN")
		if read16(W.party_mon1_hp) > read16(W.party_mon1_max_hp) then
			state_line("FAILED_STARTER_HP_OVER_MAX")
			callbacks:remove(cbid)
			return
		end
	end

	if battle_mode ~= 0 then
		write8(W.battle_menu_cursor, 1)
		write8(W.battle_menu_cursor + 1, 0)
		write8(W.menu_cursor_buffer, 1)
		write8(W.menu_cursor_buffer + 1, 0)
		write16(W.enemy_attack, 1)
		write16(W.enemy_sp_atk, 1)
		write16(W.enemy_hp, 0)
		set_phase("battle")
		keys = pulse(A, 8, 4)
	elseif group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F then
		set_phase("hub")
		if injected and read8(W.step) ~= SAFARI_GAUNTLET_STEP_DRAFT and not wait_for_clamp then
			wait_for_clamp = frame + 180
		end
		if wait_for_clamp and frame >= wait_for_clamp then
			local hp = read16(W.party_mon1_hp)
			local max_hp = read16(W.party_mon1_max_hp)
			if hp <= max_hp then
				state_line("VERIFIED_HP_CLAMP")
				emu:screenshot(screenshot_path)
				log("screenshot=" .. screenshot_path)
				callbacks:remove(cbid)
				return
			end
			state_line("FAILED_HP_STILL_OVER_MAX")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			callbacks:remove(cbid)
			return
		end
		if read8(W.x) < 12 then
			keys = RIGHT
		elseif read8(W.x) > 12 then
			keys = LEFT
		elseif read8(W.y) < 8 then
			keys = DOWN
		elseif read8(W.y) > 8 then
			keys = UP
		elseif not hub_ready_frame then
			hub_ready_frame = frame
			state_line("hub_ready")
		elseif frame - hub_ready_frame < 30 then
			keys = UP
		else
			keys = pulse(A, 10, 5)
		end
	elseif supplies_seen and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT then
		if not injected and read16(W.party_mon1_max_hp) > 0 then
			clone_starter_party()
			local max_hp = read16(W.party_mon1_max_hp)
			write16(W.party_mon1_hp, max_hp + 10)
			injected = true
			state_line("INJECTED_PARTY_HP_OVER_MAX")
		end
		set_phase("draft_exit")
		local t = phase_frame % 80
		if t < 24 then
			keys = bit(KEY.DOWN)
		elseif t < 52 then
			keys = A
		end
	else
		set_phase("boot")
		local t = phase_frame % 90
		if t < 12 then
			keys = START
		elseif t < 28 then
			keys = A
		elseif t < 42 then
			keys = B
		elseif t < 58 then
			keys = A
		end
	end

	if frame - frame0 > 90000 then
		state_line("FAILED_TIMEOUT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
		return
	end

	phase_frame = phase_frame + 1
	apply_keys(keys)
end)

log("Safari Gauntlet HP clamp verifier loaded")
state_line("initial")
