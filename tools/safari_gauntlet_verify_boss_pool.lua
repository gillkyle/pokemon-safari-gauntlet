local log_path = "/tmp/safari-gauntlet-boss-pool.log"
local screenshot_path = "/tmp/safari-gauntlet-boss-pool-red.png"

local repo = "/Users/kyle/dev/pokecrystal"
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

local GROUP_BATTLE_FACTORY = 12
local MAP_BATTLE_FACTORY_1F = 17
local OW_UP = 0x04
local BATTLEMODE_TRAINER = 2

local f = assert(io.open(log_path, "w"))

local expected = {
	{ boss = "SAFARI_GAUNTLET_BOSS_FALKNER", class = "FALKNER", trainer = "2", group = "FalknerGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_BUGSY", class = "BUGSY", trainer = "2", group = "BugsyGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_WHITNEY", class = "WHITNEY", trainer = "2", group = "WhitneyGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_MORTY", class = "MORTY", trainer = "2", group = "MortyGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_CHUCK", class = "CHUCK", trainer = "2", group = "ChuckGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_JASMINE", class = "JASMINE", trainer = "2", group = "JasmineGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_PRYCE", class = "PRYCE", trainer = "2", group = "PryceGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_CLAIR", class = "CLAIR", trainer = "2", group = "ClairGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_BROCK", class = "BROCK", trainer = "2", group = "BrockGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_MISTY", class = "MISTY", trainer = "2", group = "MistyGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_LT_SURGE", class = "LT_SURGE", trainer = "2", group = "LtSurgeGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_ERIKA", class = "ERIKA", trainer = "2", group = "ErikaGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_JANINE", class = "JANINE", trainer = "2", group = "JanineGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_SABRINA", class = "SABRINA", trainer = "2", group = "SabrinaGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_BLAINE", class = "BLAINE", trainer = "2", group = "BlaineGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_BLUE", class = "BLUE", trainer = "2", group = "BlueGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_WILL", class = "WILL", trainer = "2", group = "WillGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_KOGA", class = "KOGA", trainer = "2", group = "KogaGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_BRUNO", class = "BRUNO", trainer = "2", group = "BrunoGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_KAREN", class = "KAREN", trainer = "2", group = "KarenGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_LANCE", class = "CHAMPION", trainer = "LANCE2", group = "ChampionGroup" },
	{ boss = "SAFARI_GAUNTLET_BOSS_RED", class = "RED", trainer = "1", group = "RedGroup" },
}

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function read_file(path)
	local fh = assert(io.open(path, "r"))
	local text = fh:read("*a")
	fh:close()
	return text
end

local function fail(reason)
	log(reason)
	pcall(function() emu:screenshot(screenshot_path) end)
	log("screenshot=" .. screenshot_path)
	emu:clearKeys(0xffffffff)
	error(reason)
end

local function assert_true(value, reason)
	if not value then
		fail(reason)
	end
end

local function load_symbols()
	local symbols = {}
	for line in read_file(repo .. "/polishedcrystal-3.2.3.sym"):gmatch("[^\n]+") do
		local addr, name = line:match("^%x%x:(%x%x%x%x)%s+([%w_]+)$")
		if not addr then
			addr, name = line:match("^[^:]+:%x%x:(%x%x%x%x)%s+([%w_]+)$")
		end
		if addr and name then
			symbols[name] = tonumber(addr, 16)
		end
	end
	return symbols
end

local S = load_symbols()
local W = {
	map_group = S.wMapGroup,
	map_number = S.wMapNumber,
	y = S.wYCoord,
	x = S.wXCoord,
	map_status = S.wMapStatus,
	script_flags = S.wScriptFlags,
	script_mode = S.wScriptMode,
	player_direction = S.wPlayerDirection,
	crash_code = S.hCrashCode,
	tilemap = 0xc440,
	options2 = S.wOptions2 or 0xcff5,
	party_count = S.wPartyCount,
	party_mon1_level = S.wPartyMon1Level,
	party_mon1_hp = S.wPartyMon1HP,
	party_mon1_max_hp = S.wPartyMon1MaxHP,
	party_mon1_attack = S.wPartyMon1Attack,
	party_mon1_defense = S.wPartyMon1Defense,
	party_mon1_speed = S.wPartyMon1Speed,
	party_mon1_sp_atk = S.wPartyMon1SpAtk,
	party_mon1_sp_def = S.wPartyMon1SpDef,
	battle_mode = S.wBattleMode,
	other_trainer_class = S.wOtherTrainerClass,
	other_trainer_id = S.wOtherTrainerID,
	ot_party_mon1_level = S.wOTPartyMon1Level,
	boss = S.wSafariGauntletBoss,
	step = S.wSafariGauntletStep,
	battle_mon_hp = S.wBattleMonHP,
	battle_mon_max_hp = S.wBattleMonMaxHP,
	battle_mon_attack = S.wBattleMonAttack,
	battle_mon_defense = S.wBattleMonDefense or 0xc75e,
	battle_mon_speed = S.wBattleMonSpeed or 0xc760,
	battle_mon_sp_atk = S.wBattleMonSpAtk or 0xc762,
	battle_mon_sp_def = S.wBattleMonSpDef or 0xc764,
}

for _, name in ipairs({
	"map_group",
	"map_number",
	"y",
	"x",
	"map_status",
	"script_flags",
	"script_mode",
	"player_direction",
	"crash_code",
	"options2",
	"party_count",
	"party_mon1_level",
	"party_mon1_hp",
	"party_mon1_max_hp",
	"party_mon1_attack",
	"party_mon1_defense",
	"party_mon1_speed",
	"party_mon1_sp_atk",
	"party_mon1_sp_def",
	"battle_mode",
	"other_trainer_class",
	"other_trainer_id",
	"ot_party_mon1_level",
	"boss",
	"step",
	"battle_mon_hp",
	"battle_mon_max_hp",
	"battle_mon_attack",
	"battle_mon_defense",
	"battle_mon_speed",
	"battle_mon_sp_atk",
	"battle_mon_sp_def",
}) do
	assert_true(W[name] ~= nil, "FAILED_MISSING_SYMBOL_" .. name)
end

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

local function parse_trainer_classes()
	local classes = {}
	local value = 0
	for line in read_file(repo .. "/constants/trainer_constants.asm"):gmatch("[^\n]+") do
		local name = line:match("^%s*trainerclass%s+([%w_]+)")
		if name then
			classes[name] = value
			value = value + 1
		end
	end
	return classes
end

local function parse_boss_constants()
	local constants = {}
	local value = 0
	local in_boss_block = false
	for line in read_file(repo .. "/constants/battle_tower_constants.asm"):gmatch("[^\n]+") do
		if line:match("^%s*const_def%s*$") then
			value = 0
			in_boss_block = false
		end
		local name = line:match("^%s*const%s+(SAFARI_GAUNTLET_BOSS_[%w_]+)")
		if name then
			in_boss_block = true
			constants[name] = value
			value = value + 1
		elseif in_boss_block and line:match("^%s*DEF%s+SAFARI_GAUNTLET_BOSS_COUNT%s+EQU%s+const_value") then
			constants.SAFARI_GAUNTLET_BOSS_COUNT = value
			break
		elseif in_boss_block and line:match("^%s*const%s+") then
			break
		end
	end
	return constants
end

local function extract_block(text, first_label, next_label)
	local s = assert(text:find(first_label .. ":", 1, true))
	local e = assert(text:find(next_label .. ":", s + 1, true))
	return text:sub(s, e - 1)
end

local trainer_classes = parse_trainer_classes()
local boss_constants = parse_boss_constants()

local function static_verify()
	local constants_text = read_file(repo .. "/constants/battle_tower_constants.asm")
	local map_text = read_file(repo .. "/maps/BattleFactory1F.asm")
	local levels_text = read_file(repo .. "/engine/battle/read_trainer_party.asm")
	local parties_text = read_file(repo .. "/data/trainers/parties.asm")
	local reveal_block = extract_block(map_text, "SafariGauntletRevealBoss", "SafariGauntletBossBattle")
	local battle_block = extract_block(map_text, "SafariGauntletBossBattle", "SafariGauntletDraftFailed")

	assert_true(constants_text:find("DEF SAFARI_GAUNTLET_BOSS_COUNT EQU const_value", 1, true), "FAILED_BOSS_COUNT_DEF")
	assert_true(boss_constants.SAFARI_GAUNTLET_BOSS_COUNT == #expected, "FAILED_BOSS_COUNT_" .. tostring(boss_constants.SAFARI_GAUNTLET_BOSS_COUNT))
	assert_true(map_text:find("random SAFARI_GAUNTLET_BOSS_COUNT", 1, true), "FAILED_BOSS_RANDOM_COUNT")
	assert_true(levels_text:find("db 57, 60", 1, true), "FAILED_BOSS_LEVEL_RANGE")

	for index, entry in ipairs(expected) do
		local boss_value = boss_constants[entry.boss]
		assert_true(boss_value == index - 1, "FAILED_BOSS_ORDER_" .. entry.boss)
		assert_true(reveal_block:find("gettrainername " .. entry.class .. ", " .. entry.trainer, 1, true), "FAILED_REVEAL_" .. entry.boss)
		assert_true(battle_block:find("loadtrainer " .. entry.class .. ", " .. entry.trainer, 1, true), "FAILED_LOADTRAINER_" .. entry.boss)

		local group_start = assert(parties_text:find(entry.group .. ":", 1, true))
		local group_end = parties_text:find("\nSECTION ", group_start + 1, true) or (#parties_text + 1)
		local group_text = parties_text:sub(group_start, group_end - 1)
		assert_true(group_text:find("def_trainer " .. entry.trainer .. ",", 1, true), "FAILED_MISSING_PARTY_" .. entry.boss)
	end

	log("VERIFIED_BOSS_POOL count=" .. #expected .. " level_range=57-60")
end

local function state_line(prefix)
	log(string.format(
		"%s crash=%02x map=%d/%d xy=%d,%d status=%02x script=%02x/%02x party=%d step=%d boss=%d battle=%d trainer=%d/%d ot_level=%d hp=%d/%d",
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
		read8(W.step),
		read8(W.boss),
		read8(W.battle_mode),
		read8(W.other_trainer_class),
		read8(W.other_trainer_id),
		read8(W.ot_party_mon1_level),
		read16(W.party_mon1_hp),
		read16(W.party_mon1_max_hp)
	))
end

local function apply_keys(keys)
	emu:clearKeys(0xffffffff)
	if keys ~= 0 then
		emu:addKeys(keys)
	end
end

local function run_frames(keys, frames)
	apply_keys(keys)
	for _ = 1, frames do
		write8(W.options2, read8(W.options2) & 0x3f)
		emu:runFrame()
		if read8(W.crash_code) ~= 0 or bsod_seen() then
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
	local keys = move_toward(12, 6)
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

local function force_red_boss()
	write8(W.party_count, 1)
	write8(W.step, 6)
	write8(W.boss, boss_constants.SAFARI_GAUNTLET_BOSS_RED)
	write8(W.party_mon1_level, 55)
	write16(W.party_mon1_max_hp, 999)
	write16(W.party_mon1_hp, 999)
	write16(W.party_mon1_attack, 999)
	write16(W.party_mon1_defense, 999)
	write16(W.party_mon1_speed, 999)
	write16(W.party_mon1_sp_atk, 999)
	write16(W.party_mon1_sp_def, 999)
	state_line("forced_red_boss")
end

local function verify_red_boss_battle()
	local red_class = trainer_classes.RED
	for i = 1, 3600 do
		if read8(W.battle_mode) == BATTLEMODE_TRAINER
			and read8(W.other_trainer_class) == red_class
			and read8(W.other_trainer_id) == 1
			and read8(W.ot_party_mon1_level) > 0 then
			local level = read8(W.ot_party_mon1_level)
			if level < 57 or level > 60 then
				fail("FAILED_RED_LEVEL_" .. level)
			end
			write16(W.battle_mon_max_hp, 999)
			write16(W.battle_mon_hp, 999)
			write16(W.battle_mon_attack, 999)
			write16(W.battle_mon_defense, 999)
			write16(W.battle_mon_speed, 999)
			write16(W.battle_mon_sp_atk, 999)
			write16(W.battle_mon_sp_def, 999)
			state_line("VERIFIED_RED_BOSS_BATTLE")
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
			apply_keys(0)
			return
		end

		if read8(W.battle_mode) == BATTLEMODE_TRAINER
			and read8(W.other_trainer_class) ~= 0
			and read8(W.other_trainer_class) ~= red_class then
			fail("FAILED_WRONG_RED_CLASS_" .. read8(W.other_trainer_class))
		end

		pulse(A)
		if i % 120 == 0 then
			state_line("red_boss_wait")
		end
	end
	fail("FAILED_RED_BOSS_BATTLE_TIMEOUT")
end

log("Safari Gauntlet boss pool verifier loaded")
static_verify()
state_line("initial")
boot_to_hub()
force_red_boss()
stand_at_reception()
verify_red_boss_battle()
