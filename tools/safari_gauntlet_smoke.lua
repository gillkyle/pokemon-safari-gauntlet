local log_path = "/tmp/safari-gauntlet-smoke.log"
local screenshot_path = "/tmp/safari-gauntlet-smoke.png"

local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)
local B = bit(KEY.B)
local START = bit(KEY.START)
local SELECT = bit(KEY.SELECT)
local RIGHT = bit(KEY.RIGHT)
local LEFT = bit(KEY.LEFT)
local UP = bit(KEY.UP)
local DOWN = bit(KEY.DOWN)

local W = {
	map_group = 0xdcac,
	map_number = 0xdcad,
	y = 0xdcae,
	x = 0xdcaf,
	party_count = 0xdcce,
	battle_mode = 0xd233,
	battle_type = 0xd236,
	battle_result = 0xd0f6,
	battle_mon_hp = 0xc758,
	battle_mon_max_hp = 0xc75a,
	battle_mon_pp = 0xc750,
	enemy_hp = 0xd21c,
	enemy_catch_rate = 0xd231,
	safari_balls = 0xdc92,
	party_mon1 = 0xdcd6,
	runs_hi = 0xdb99,
	runs_lo = 0xdb9a,
	wins_hi = 0xdb9b,
	wins_lo = 0xdb9c,
	losses_hi = 0xdb9d,
	losses_lo = 0xdb9e,
	settings = 0xdba1,
	keep_count = 0xdba2,
	draft_attempts = 0xd7db,
	boss = 0xd7da,
}

local GROUP_PLAYERS_HOUSE = 24
local MAP_PLAYERS_HOUSE_2F = 7
local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local BATTLETYPE_SAFARI = 7
local PARTYMON_STRUCT_LENGTH = 0x30
local PARTYMON_HP_OFFSET = 0x22
local PARTYMON_MAX_HP_OFFSET = 0x24
local PARTYMON_PP_OFFSET = 0x16

local f = assert(io.open(log_path, "w"))
local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function read16(hi)
	return emu:read8(hi) * 256 + emu:read8(hi + 1)
end

local function write16(hi, value)
	emu:write8(hi, value // 256)
	emu:write8(hi + 1, value % 256)
end

local function keep_party_healthy()
	local battle_max = read16(W.battle_mon_max_hp)
	if battle_max > 0 then
		write16(W.battle_mon_hp, battle_max)
	end
	for move = 0, 3 do
		emu:write8(W.battle_mon_pp + move, 40)
	end
	local count = emu:read8(W.party_count)
	if count > 6 then
		count = 6
	end
	for i = 0, count - 1 do
		local base = W.party_mon1 + i * PARTYMON_STRUCT_LENGTH
		local max_hp = read16(base + PARTYMON_MAX_HP_OFFSET)
		if max_hp > 0 then
			write16(base + PARTYMON_HP_OFFSET, max_hp)
			for move = 0, 3 do
				emu:write8(base + PARTYMON_PP_OFFSET + move, 40)
			end
		end
	end
end

local function state_line(prefix)
	log(string.format(
		"%s map=%d/%d xy=%d,%d party=%d attempts=%d boss=%d settings=%02x runs=%d wins=%d losses=%d keep=%d",
		prefix,
		emu:read8(W.map_group),
		emu:read8(W.map_number),
		emu:read8(W.x),
		emu:read8(W.y),
		emu:read8(W.party_count),
		emu:read8(W.draft_attempts),
		emu:read8(W.boss),
		emu:read8(W.settings),
		read16(W.runs_hi),
		read16(W.wins_hi),
		read16(W.losses_hi),
		emu:read8(W.keep_count)
	))
end

local function make_battles_fast()
	local mode = emu:read8(W.battle_mode)
	if mode == 0 then
		return
	end
	keep_party_healthy()
	emu:write8(W.enemy_hp, 0)
	emu:write8(W.enemy_hp + 1, 0)
	if emu:read8(W.battle_type) == BATTLETYPE_SAFARI then
		emu:write8(W.enemy_catch_rate, 255)
		if emu:read8(W.safari_balls) == 0 then
			emu:write8(W.safari_balls, 25)
		end
	end
end

local frame0 = emu:currentFrame()
local last_log = 0
local phase = "boot"
local phase_frame = 0
local started_attendant = false

local function set_phase(next_phase)
	if phase ~= next_phase then
		phase = next_phase
		phase_frame = 0
		state_line("phase=" .. phase)
	end
end

local function pulse(key, period, width)
	local t = phase_frame % period
	if t < width then
		return key
	end
	return 0
end

local function drive_players_room()
	local x = emu:read8(W.x)
	local y = emu:read8(W.y)
	if x < 5 then
		return RIGHT
	elseif x > 5 then
		return LEFT
	elseif y < 3 then
		return DOWN
	elseif y > 3 then
		return UP
	elseif phase_frame < 60 then
		return UP
	elseif phase_frame < 90 then
		return 0
	end
	return pulse(A, 20, 4)
end

local function drive_boot()
	if phase_frame < 60 then
		return B
	elseif phase_frame < 95 then
		return UP
	elseif phase_frame < 130 then
		return 0
	elseif phase_frame < 165 then
		return UP
	elseif phase_frame < 210 then
		return 0
	end
	return pulse(A, 18, 5)
end

local cbid
cbid = callbacks:add("keysRead", function()
	local frame = emu:currentFrame()
	local group = emu:read8(W.map_group)
	local map = emu:read8(W.map_number)
	local keys = 0
	make_battles_fast()

	if group == 0 and map == 0 and phase == "battle_factory" then
		group = GROUP_BATTLE_FACTORY
		map = MAP_BATTLE_FACTORY_1F
	end

	if frame - last_log > 300 then
		last_log = frame
		state_line("tick")
	end

	if group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F then
		set_phase("battle_factory")
		if not started_attendant then
			started_attendant = true
			phase_frame = 0
		end
		if emu:read8(W.draft_attempts) > 0 then
			keys = pulse(A, 10, 4)
		elseif phase_frame < 90 then
			keys = UP
		else
			keys = pulse(A, 12, 4)
		end
	elseif group == GROUP_PLAYERS_HOUSE and map == MAP_PLAYERS_HOUSE_2F then
		set_phase("players_room")
		keys = drive_players_room()
	else
		set_phase("boot")
		keys = drive_boot()
	end

	if frame - frame0 > 300000 then
		state_line("final")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
	end

	phase_frame = phase_frame + 1
	emu:setKeys(keys)
end)

log("Safari Gauntlet smoke script loaded")
state_line("initial")
