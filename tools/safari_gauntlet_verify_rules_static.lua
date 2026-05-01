local log_path = "/tmp/safari-gauntlet-rules-static.log"
local screenshot_path = "/tmp/safari-gauntlet-rules-static.png"
local repo_path = "/Users/kyle/dev/pokecrystal/"

local f = assert(io.open(log_path, "w"))

local function log(msg)
	local line = string.format("%08d %s", emu and emu.currentFrame and emu:currentFrame() or 0, msg)
	f:write(line .. "\n")
	f:flush()
	if console and console.log then
		console:log(line)
	else
		print(line)
	end
end

local function read_file(path)
	local handle = assert(io.open(path, "r"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local function number_define(text, name)
	local value = text:match("DEF%s+" .. name .. "%s+EQU%s+(%d+)")
	assert(value, "FAILED_MISSING_DEFINE " .. name)
	return tonumber(value)
end

local function assert_true(ok, label)
	if not ok then
		log(label)
		if emu and emu.screenshot then
			emu:screenshot(screenshot_path)
			log("screenshot=" .. screenshot_path)
		end
		error(label)
	end
end

local wildmons = read_file(repo_path .. "engine/overworld/wildmons.asm")
local constants = read_file(repo_path .. "constants/battle_tower_constants.asm")
local battle_factory = read_file(repo_path .. "maps/BattleFactory1F.asm")
local trainer_loader = read_file(repo_path .. "engine/battle/read_trainer_party.asm")
local battle_core = read_file(repo_path .. "engine/battle/core.asm")
local poke_balls = read_file(repo_path .. "engine/items/poke_balls.asm")
local legendary_mons = read_file(repo_path .. "data/pokemon/legendary_mons.asm")
local pokemon_constants = read_file(repo_path .. "constants/pokemon_constants.asm")

local johto_pool = number_define(wildmons, "SAFARI_GAUNTLET_JOHTO_POOL_COUNT")
assert_true(johto_pool == 251, "FAILED_JOHTO_POOL_COUNT")

local common_catch_rate = number_define(wildmons, "SAFARI_GAUNTLET_COMMON_CATCH_RATE")
local uncommon_catch_rate = number_define(wildmons, "SAFARI_GAUNTLET_UNCOMMON_CATCH_RATE")
local legendary_pool_count = number_define(wildmons, "SAFARI_GAUNTLET_LEGENDARY_POOL_COUNT")
assert_true(common_catch_rate == 120, "FAILED_COMMON_CATCH_THRESHOLD")
assert_true(uncommon_catch_rate == 60, "FAILED_UNCOMMON_CATCH_THRESHOLD")
assert_true(
	wildmons:find("DEF SAFARI_GAUNTLET_NATIONAL_POOL_COUNT EQU NUM_POKEMON", 1, true) ~= nil,
	"FAILED_NATIONAL_POOL_NOT_FULL_DEX"
)
assert_true(
	pokemon_constants:find("DEF NUM_POKEMON EQU NUM_SPECIES - (2 * HIGH(NUM_SPECIES))", 1, true) ~= nil,
	"FAILED_NUM_POKEMON_ENCODING_UNEXPECTED"
)
assert_true(pokemon_constants:find("const AZURILL", 1, true) ~= nil, "FAILED_AZURILL_CONSTANT_MISSING")
assert_true(pokemon_constants:find("const ANNIHILAPE", 1, true) ~= nil, "FAILED_ANNIHILAPE_CONSTANT_MISSING")
assert_true(wildmons:find(".extended_species_block", 1, true) ~= nil, "FAILED_NATIONAL_EXTENDED_BLOCK_MISSING")
assert_true(wildmons:find("1 << MON_EXTSPECIES_F", 1, true) ~= nil, "FAILED_NATIONAL_EXTENDED_FLAG_MISSING")

local legendary_count = 0
for _ in legendary_mons:gmatch("\n%s*dp%s+") do
	legendary_count = legendary_count + 1
end
assert_true(legendary_count == legendary_pool_count, "FAILED_LEGENDARY_POOL_COUNT_" .. legendary_count)

local function legendary_table_has(mon)
	return legendary_mons:find("\n%s*dp%s+" .. mon .. "%s*\n") ~= nil
end

assert_true(legendary_table_has("LUGIA"), "FAILED_LUGIA_NOT_LEGENDARY")
assert_true(legendary_table_has("MEWTWO"), "FAILED_MEWTWO_NOT_LEGENDARY")
assert_true(legendary_table_has("MEW"), "FAILED_MEW_NOT_LEGENDARY")
assert_true(legendary_table_has("CELEBI"), "FAILED_CELEBI_NOT_LEGENDARY")

local function catch_rate(mon)
	local text = read_file(repo_path .. "data/pokemon/base_stats/" .. mon .. ".asm")
	local value = text:match("db%s+(%d+)%s+;%s+catch rate")
	assert(value, "FAILED_MISSING_CATCH_RATE_" .. mon)
	return tonumber(value)
end

assert_true(catch_rate("marill") >= common_catch_rate, "FAILED_MARILL_NOT_COMMON_CATCH")
assert_true(catch_rate("haunter") >= uncommon_catch_rate and catch_rate("haunter") < common_catch_rate, "FAILED_HAUNTER_NOT_UNCOMMON_CATCH")
assert_true(catch_rate("dragonite") < uncommon_catch_rate, "FAILED_DRAGONITE_NOT_RARE_CATCH")
assert_true(catch_rate("lugia") < uncommon_catch_rate, "FAILED_LUGIA_CATCH_RATE")

assert_true(wildmons:find("ld hl, LegendaryMons", 1, true) ~= nil, "FAILED_LEGENDARY_TABLE_NOT_USED")
assert_true(wildmons:find("call GetSpeciesAndFormIndexFromHL", 1, true) ~= nil, "FAILED_LEGENDARY_CLASSIFIER_NOT_USED")
assert_true(wildmons:find("wBaseCatchRate", 1, true) ~= nil, "FAILED_CATCH_RATE_CLASSIFIER_NOT_USED")

for _, rate in ipairs({
	{ "hub", "SAFARI_GAUNTLET_HUB_COMMON_END", "SAFARI_GAUNTLET_HUB_UNCOMMON_END", "SAFARI_GAUNTLET_HUB_RARE_END" },
	{ "mid", "SAFARI_GAUNTLET_MID_COMMON_END", "SAFARI_GAUNTLET_MID_UNCOMMON_END", "SAFARI_GAUNTLET_MID_RARE_END" },
	{ "north", "SAFARI_GAUNTLET_NORTH_COMMON_END", "SAFARI_GAUNTLET_NORTH_UNCOMMON_END", "SAFARI_GAUNTLET_NORTH_RARE_END" },
}) do
	local common_end = number_define(wildmons, rate[2])
	local uncommon_end = number_define(wildmons, rate[3])
	local rare_end = number_define(wildmons, rate[4])
	local common_rate = common_end
	local uncommon_rate = uncommon_end - common_end
	local rare_rate = rare_end - uncommon_end
	local legendary_rate = 100 - rare_end
	assert_true(common_rate > uncommon_rate, "FAILED_COMMON_NOT_DOMINANT_" .. rate[1])
	assert_true(uncommon_rate > rare_rate, "FAILED_UNCOMMON_NOT_ABOVE_RARE_" .. rate[1])
		assert_true(legendary_rate == 1, "FAILED_LEGENDARY_RATE_" .. rate[1] .. "_" .. legendary_rate)
		log(string.format("RATE_OK_%s common=%d uncommon=%d rare=%d legendary=%d", rate[1], common_rate, uncommon_rate, rare_rate, legendary_rate))
	end

assert_true(number_define(constants, "SAFARI_GAUNTLET_DRAFT_LEVEL") == 50, "FAILED_DRAFT_LEVEL_DEFINE")
assert_true(not constants:find("SAFARI_GAUNTLET_DRAFT_MIN_CATCH_RATE", 1, true), "FAILED_DRAFT_CATCH_RATE_FLOOR_STILL_DEFINED")
assert_true(not battle_core:find("SafariGauntlet_AdjustDraftWildmonCatchRate", 1, true), "FAILED_DRAFT_CATCH_RATE_FLOOR_STILL_USED")
assert_true(number_define(constants, "SAFARI_GAUNTLET_DRAFT_POKE_BALL_BONUS") == 2, "FAILED_DRAFT_POKE_BALL_BONUS")
assert_true(number_define(constants, "SAFARI_GAUNTLET_DRAFT_GREAT_BALL_BONUS") == 3, "FAILED_DRAFT_GREAT_BALL_BONUS")
assert_true(number_define(constants, "SAFARI_GAUNTLET_DRAFT_ULTRA_BALL_BONUS") == 4, "FAILED_DRAFT_ULTRA_BALL_BONUS")
assert_true(poke_balls:find("SafariGauntlet_DraftBallMultiplier", 1, true) ~= nil, "FAILED_DRAFT_BALL_MULTIPLIER_MISSING")
assert_true(poke_balls:find("cp POKE_BALL", 1, true) ~= nil, "FAILED_DRAFT_POKE_BALL_NOT_HANDLED")
assert_true(poke_balls:find("cp GREAT_BALL", 1, true) ~= nil, "FAILED_DRAFT_GREAT_BALL_NOT_HANDLED")
assert_true(poke_balls:find("cp ULTRA_BALL", 1, true) ~= nil, "FAILED_DRAFT_ULTRA_BALL_NOT_HANDLED")
assert_true(trainer_loader:find("db 57, 60", 1, true) ~= nil, "FAILED_BOSS_LEVEL_RANGE")
assert_true(trainer_loader:find("db 3, 4, 5, 5", 1, true) ~= nil, "FAILED_TRAINER_PARTY_MINIMUMS")

local _, roll_count = battle_factory:gsub("special Special_SafariGauntlet_RollTrainerFamily", "")
assert_true(roll_count == 4, "FAILED_TRAINER_FAMILY_ROLL_COUNT_" .. roll_count)
assert_true(not battle_factory:find("random 16", 1, true), "FAILED_ROUND_RANDOM_16_STILL_PRESENT")

log("VERIFIED_STATIC_RULES")
if emu and emu.screenshot then
	emu:screenshot(screenshot_path)
	log("screenshot=" .. screenshot_path)
end
