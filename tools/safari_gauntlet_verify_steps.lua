local log_path = "/tmp/safari-gauntlet-steps.log"
local screenshot_path = "/tmp/safari-gauntlet-steps.png"

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

local W = {
	map_group = 0xdcac,
	map_number = 0xdcad,
	map_status = 0xd431,
	map_event_status = 0xd432,
	script_flags = 0xd433,
	script_mode = 0xd436,
	crash_code = 0xffe5,
	y = 0xdcae,
	x = 0xdcaf,
	options2 = 0xcff5,
	party_count = 0xdcce,
	battle_mode = 0xd233,
	battle_menu_cursor = 0xd0d8,
	menu_cursor_buffer = 0xce2f,
	enemy_hp = 0xd21c,
	num_balls = 0xd90b,
	balls = 0xd90c,
	time_remaining = 0xdc93,
	step = 0xd7dc,
	draft_attempts = 0xd7db,
	party_mon1 = 0xdcd6,
	party_mon1_ot = 0xddf6,
	party_mon1_nickname = 0xde38,
	wild_cooldown = 0xd464,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local GROUP_SAFARI_ZONE = 32
local MAP_SAFARI_ZONE_HUB = 1
local SAFARI_GAUNTLET_STEP_DRAFT = 1
local SAFARI_GAUNTLET_STEP_ROUND1 = 2
local BATTLEMODE_WILD = 1
local MASTER_BALL = 4
local PARTYMON_STRUCT_LENGTH = 0x30
local PARTYMON_NAME_LENGTH = 0x0b

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local phase = "boot"
local phase_frame = 0
local last_log = 0
local supplies_seen = false
local initial_steps_verified = false
local decrement_verified = false
local limit_forced = false
local returned_frame = nil

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
		"%s map=%d/%d xy=%d,%d map_status=%02x map_event=%02x script_flags=%02x script_mode=%02x crash=%02x party=%d battle=%d step=%d steps_left=%d master=%d",
		prefix,
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.map_status),
		read8(W.map_event_status),
		read8(W.script_flags),
		read8(W.script_mode),
		read8(W.crash_code),
		read8(W.party_count),
		read8(W.battle_mode),
		read8(W.step),
		read16(W.time_remaining),
		ball_qty(MASTER_BALL)
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
	local t = phase_frame % 180
	if t < 60 then
		return UP
	elseif t < 120 then
		return LEFT
	end
	return RIGHT
end

local function keep_single_starter_party()
	write8(W.party_count, 1)
	write8(W.draft_attempts, 0)
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
	local group = read8(W.map_group)
	local map = read8(W.map_number)
	local battle_mode = read8(W.battle_mode)
	local steps_left = read16(W.time_remaining)
	local keys = 0

	write8(W.options2, read8(W.options2) & 0x3f)

	if frame - last_log > 300 then
		last_log = frame
		state_line("tick")
	end

	if not supplies_seen and read8(W.party_count) > 0 and ball_qty(MASTER_BALL) >= 1 then
		supplies_seen = true
		state_line("SUPPLIES_SEEN")
	end

	if battle_mode == BATTLEMODE_WILD then
		write8(W.battle_menu_cursor, 1)
		write8(W.battle_menu_cursor + 1, 0)
		write8(W.menu_cursor_buffer, 1)
		write8(W.menu_cursor_buffer + 1, 0)
		write16(W.enemy_hp, 0)
		set_phase("battle")
		keys = pulse(A, 8, 4)
	elseif group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F then
		if limit_forced and read8(W.step) == SAFARI_GAUNTLET_STEP_ROUND1 then
			if read8(W.map_status) == 2 then
				if not returned_frame then
					returned_frame = frame
					state_line("STEP_LIMIT_RETURN_SEEN")
				elseif frame - returned_frame > 60 then
					state_line("VERIFIED_STEPS")
					emu:screenshot(screenshot_path)
					log("screenshot=" .. screenshot_path)
					callbacks:remove(cbid)
					return
				end
			end
		end
		set_phase("hub")
		if read8(W.map_status) == 2 then
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
		end
	elseif group == GROUP_SAFARI_ZONE and map == MAP_SAFARI_ZONE_HUB and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT then
		if not initial_steps_verified then
			if steps_left ~= 500 then
				state_line("FAILED_BAD_INITIAL_STEPS")
				emu:screenshot(screenshot_path)
				log("screenshot=" .. screenshot_path)
				callbacks:remove(cbid)
				return
			end
			initial_steps_verified = true
			state_line("STEP_LIMIT_INIT_OK")
		elseif not decrement_verified and steps_left < 500 then
			decrement_verified = true
			state_line("STEP_LIMIT_DECREMENT_OK")
			keep_single_starter_party()
			write16(W.time_remaining, 1)
			limit_forced = true
			state_line("STEP_LIMIT_FORCED_WITH_ONE_MON")
		end
		set_phase("field")
		if read8(W.map_status) == 2 then
			keys = drive_field()
			if limit_forced and phase_frame % 48 < 8 then
				keys = keys | A
			end
		end
	else
		set_phase("boot")
		keys = drive_boot()
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

log("Safari Gauntlet step verifier loaded")
state_line("initial")
