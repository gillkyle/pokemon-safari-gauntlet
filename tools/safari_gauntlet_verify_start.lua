local log_path = "/tmp/safari-gauntlet-start.log"
local screenshot_path = "/tmp/safari-gauntlet-start.png"
local bg_flag = "/tmp/safari-gauntlet-start-bg.flag"
local force_bg_event = io.open(bg_flag) ~= nil

local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)
local B = bit(KEY.B)
local START = bit(KEY.START)

local W = {
	map_group = 0xdcac,
	map_number = 0xdcad,
		y = 0xdcae,
		x = 0xdcaf,
		options2 = 0xcff5,
		party_count = 0xdcce,
		map_scripts_bank = 0xd1a6,
		battle_mode = 0xd233,
	num_balls = 0xd90b,
	balls = 0xd90c,
	boss = 0xd7da,
	draft_attempts = 0xd7db,
	step = 0xd7dc,
	time_remaining = 0xdc93,
	settings = 0xdba1,
	keep_count = 0xdba2,
	keep_species = 0xdba3,
	player_direction = 0xd4d4,
	script_flags = 0xd433,
	script_mode = 0xd436,
	last_talked = 0xffc7,
	script_bank = 0xffeb,
	script_pos = 0xffec,
	cur_form = 0xcdbd,
	cur_party_species = 0xd10b,
	crash_code = 0xffe5,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local GROUP_SAFARI_ZONE = 32
local MAP_SAFARI_ZONE_HUB = 1
local SAFARI_GAUNTLET_STEP_DRAFT = 1
local MASTER_BALL = 4

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local phase = "boot"
local phase_frame = 0
local last_log = 0
local bg_event_frame = nil
local last_script_key = ""

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
		"%s crash=%d map=%d/%d xy=%d,%d dir=%02x talked=%d script=%02x/%02x pc=%02x:%04x mapbank=%02x party=%d battle=%d step=%d attempts=%d boss=%d steps_left=%d settings=%02x keep=%d keep0=%d cur=%d form=%02x master=%d",
		prefix,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_direction),
		read8(W.last_talked),
		read8(W.script_flags),
			read8(W.script_mode),
			read8(W.script_bank),
			read16le(W.script_pos),
			read8(W.map_scripts_bank),
			read8(W.party_count),
		read8(W.battle_mode),
		read8(W.step),
		read8(W.draft_attempts),
		read8(W.boss),
		read16(W.time_remaining),
		read8(W.settings),
		read8(W.keep_count),
		read8(W.keep_species),
		read8(W.cur_party_species),
		read8(W.cur_form),
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

local function drive_continue_or_title()
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
	return pulse(A, 120, 50)
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
	local keys = 0

	write8(W.options2, read8(W.options2) & 0x3f)

	if read8(W.crash_code) ~= 0 then
		state_line("FAILED_CRASH")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
		return
	end

		if frame - last_log > 300 then
			last_log = frame
			state_line("tick")
		end
		local script_key = string.format(
			"%02x/%02x:%04x/%02x/%d",
			read8(W.script_flags),
			read8(W.script_bank),
			read16le(W.script_pos),
			read8(W.script_mode),
			read8(W.step)
		)
		if script_key ~= last_script_key then
			last_script_key = script_key
			state_line("trace")
		end

		if group == GROUP_SAFARI_ZONE and map == MAP_SAFARI_ZONE_HUB and read8(W.step) == SAFARI_GAUNTLET_STEP_DRAFT then
		state_line("VERIFIED_START_DRAFT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		callbacks:remove(cbid)
		return
	elseif group == GROUP_BATTLE_FACTORY and map == MAP_BATTLE_FACTORY_1F then
		set_phase("hub")
		if force_bg_event and read8(W.y) < 8 then
			keys = bit(KEY.DOWN)
		elseif force_bg_event then
			if not bg_event_frame then
				bg_event_frame = frame
				state_line("bg_event_positioned")
			end
			if frame - bg_event_frame < 4 then
				keys = bit(KEY.UP)
			else
				keys = pulse(A, 12, 4)
			end
		elseif read8(W.player_direction) ~= 0x04 then
			keys = bit(KEY.UP)
		else
			keys = pulse(A, 12, 4)
		end
	else
		set_phase("boot")
		keys = drive_continue_or_title()
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

log("Safari Gauntlet start verifier loaded force_bg_event=" .. tostring(force_bg_event))
state_line("initial")
