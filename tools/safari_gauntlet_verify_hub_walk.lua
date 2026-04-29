local log_path = "/tmp/safari-gauntlet-hub-walk.log"
local screenshot_path = "/tmp/safari-gauntlet-hub-walk.png"

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
	player_direction = 0xd4d4,
	script_flags = 0xd433,
	script_mode = 0xd436,
	script_bank = 0xffeb,
	script_pos = 0xffec,
	crash_code = 0xffe5,
	step = 0xd7dc,
	party_count = 0xdcce,
}

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17

local f = assert(io.open(log_path, "w"))
local frame0 = emu:currentFrame()
local hub_frame = nil
local idle_verified = false
local last_log = 0
local last_pos = ""

-- Walk a loop that brushes the lower exit blockers, the center aisle,
-- and the shop side without pressing A. Holding a direction into walls/NPCs
-- is intentional: it catches bad collision/script edge cases.
local path = {
	{ key = KEY.RIGHT, frames = 240 },
	{ key = KEY.LEFT, frames = 280 },
	{ key = KEY.LEFT, frames = 90 },
	{ key = KEY.DOWN, frames = 70 },
	{ key = KEY.RIGHT, frames = 120 },
	{ key = KEY.LEFT, frames = 90 },
	{ key = KEY.UP, frames = 70 },
	{ key = KEY.RIGHT, frames = 300 },
	{ key = KEY.DOWN, frames = 70 },
	{ key = KEY.LEFT, frames = 140 },
	{ key = KEY.UP, frames = 70 },
	{ key = KEY.RIGHT, frames = 160 },
	{ key = KEY.LEFT, frames = 220 },
}

local path_index = 1
local path_frame = 0
local settle_frames = 60
local script_active_frames = 0
local unique_positions = {}
local forbidden_positions = {
	["12,10"] = true,
	["13,10"] = true,
	["11,11"] = true,
	["14,11"] = true,
}
local door_actions = {
	{ key = KEY.RIGHT, step_to = "12,8" },
	{ wait = 20 },
	{ key = KEY.DOWN, step_to = "12,9" },
	{ wait = 20 },
	{ key = KEY.DOWN, hold = 80, expect = "12,9", name = "block_12_10" },
	{ wait = 20 },
	{ key = KEY.RIGHT, step_to = "13,9" },
	{ wait = 20 },
	{ key = KEY.DOWN, hold = 80, expect = "13,9", name = "block_13_10" },
	{ wait = 20 },
	{ key = KEY.RIGHT, step_to = "14,9" },
	{ wait = 20 },
	{ key = KEY.DOWN, step_to = "14,10" },
	{ wait = 20 },
	{ key = KEY.DOWN, hold = 80, expect = "14,10", name = "block_14_11" },
	{ wait = 20 },
}
local door_action_index = 1
local door_action_frames = 0
local door_tests_done = false

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

local function read16le(lo)
	return read8(lo) + read8(lo + 1) * 256
end

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function state_line(prefix)
	log(string.format(
		"%s crash=%d map=%d/%d xy=%d,%d dir=%02x script=%02x/%02x pc=%02x:%04x party=%d step=%d positions=%d",
		prefix,
		read8(W.crash_code),
		read8(W.map_group),
		read8(W.map_number),
		read8(W.x),
		read8(W.y),
		read8(W.player_direction),
		read8(W.script_flags),
		read8(W.script_mode),
		read8(W.script_bank),
		read16le(W.script_pos),
		read8(W.party_count),
		read8(W.step),
		(function()
			local count = 0
			for _ in pairs(unique_positions) do
				count = count + 1
			end
			return count
		end)()
	))
end

local function apply_keys(keys)
	for _, key in ipairs({KEY.A, KEY.B, KEY.SELECT, KEY.START, KEY.LEFT, KEY.RIGHT, KEY.UP, KEY.DOWN}) do
		emu:clearKey(key)
		if (keys & bit(key)) ~= 0 then
			emu:addKey(key)
		end
	end
end

local function drive_boot(frame)
	local t = frame % 90
	if t < 12 then
		return START
	elseif t < 36 then
		return A
	elseif t < 48 then
		return B
	elseif t < 72 then
		return A
	end
	return 0
end

local cbid
cbid = callbacks:add("frame", function()
	local frame = emu:currentFrame()
	local in_hub = read8(W.map_group) == GROUP_BATTLE_FACTORY and read8(W.map_number) == MAP_BATTLE_FACTORY_1F
	local pos = string.format("%d,%d", read8(W.x), read8(W.y))
	unique_positions[pos] = true

	if read8(W.crash_code) ~= 0 then
		state_line("FAILED_CRASH")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	if not in_hub then
		apply_keys(drive_boot(frame - frame0))
		if frame - last_log > 300 then
			last_log = frame
			state_line("booting")
		end
		return
	end

	if not hub_frame then
		hub_frame = frame
		state_line("hub_reached")
	end

	if forbidden_positions[pos] then
		state_line("FAILED_EXIT_BLOCKER")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	-- Normal movement scripts can briefly occupy mode 3. A starter in the party
	-- is expected on current boots; only Gauntlet state means walking accidentally
	-- opened something.
	if read8(W.step) ~= 0 then
		state_line("FAILED_STARTED_RUN")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	local hub_elapsed = frame - hub_frame
	if not idle_verified then
		if hub_elapsed < 60 then
			apply_keys(A) -- simulate the player still holding A from the title/menu.
			return
		elseif hub_elapsed < 180 then
			apply_keys(0)
			return
		end

		if read8(W.x) == 11
			and read8(W.y) == 8
			and read8(W.player_direction) == 0x00
			and read8(W.script_flags) == 0
			and read8(W.script_mode) == 0
			and read8(W.party_count) > 0
			and read8(W.step) == 0 then
			idle_verified = true
			state_line("idle_verified")
		else
			state_line("FAILED_NOT_IDLE")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			callbacks:remove(cbid)
		end
		return
	end

	if settle_frames <= 0 then
		if read8(W.script_flags) ~= 0 then
			script_active_frames = script_active_frames + 1
		else
			script_active_frames = 0
		end
		if script_active_frames > 90 then
			state_line("FAILED_STUCK_SCRIPT")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			callbacks:remove(cbid)
			return
		end
	end

	if pos ~= last_pos then
		last_pos = pos
		state_line("moved")
	elseif frame - last_log > 300 then
		last_log = frame
		state_line("tick")
	end

	if settle_frames > 0 then
		settle_frames = settle_frames - 1
		apply_keys(0)
		return
	end

	if not door_tests_done then
		local action = door_actions[door_action_index]
		if not action then
			door_tests_done = true
			state_line("door_blockers_verified")
			apply_keys(0)
			return
		end

		if action.wait then
			apply_keys(0)
			door_action_frames = door_action_frames + 1
			if door_action_frames >= action.wait then
				door_action_index = door_action_index + 1
				door_action_frames = 0
			end
			return
		end

		if action.step_to then
			if door_action_frames < 18 then
				apply_keys(bit(action.key))
			else
				apply_keys(0)
			end
			door_action_frames = door_action_frames + 1

			if pos == action.step_to then
				door_action_index = door_action_index + 1
				door_action_frames = 0
			elseif door_action_frames > 100 then
				state_line("FAILED_DOOR_STEP_TIMEOUT")
				emu:screenshot(screenshot_path)
				log("screenshot=" .. screenshot_path)
				apply_keys(0)
				callbacks:remove(cbid)
				return
			end
			return
		end

		apply_keys(bit(action.key))
		door_action_frames = door_action_frames + 1

		if action.hold and door_action_frames >= action.hold then
			if action.expect and pos ~= action.expect then
				state_line("FAILED_" .. (action.name or "DOOR_BLOCK"))
				emu:screenshot(screenshot_path)
				log("screenshot=" .. screenshot_path)
				apply_keys(0)
				callbacks:remove(cbid)
				return
			end
			state_line("verified_" .. (action.name or "door_block"))
			door_action_index = door_action_index + 1
			door_action_frames = 0
		elseif door_action_frames > 160 then
			state_line("FAILED_DOOR_ACTION_TIMEOUT")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			callbacks:remove(cbid)
			return
		end
		return
	end

	local segment = path[path_index]
	if segment then
		apply_keys(bit(segment.key))
		path_frame = path_frame + 1
		if path_frame >= segment.frames then
			path_index = path_index + 1
			path_frame = 0
			state_line("segment_done")
		end
	else
		local count = 0
		for _ in pairs(unique_positions) do
			count = count + 1
		end
		if count >= 8 then
			state_line("VERIFIED_HUB_WALK")
		else
			state_line("FAILED_TOO_FEW_POSITIONS")
		end
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end

	if frame - frame0 > 12000 then
		state_line("FAILED_TIMEOUT")
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
		apply_keys(0)
		callbacks:remove(cbid)
		return
	end
end)

log("Safari Gauntlet hub walk verifier loaded")
state_line("initial")
