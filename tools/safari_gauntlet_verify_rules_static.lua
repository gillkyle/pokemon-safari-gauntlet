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
local default_options = read_file(repo_path .. "data/options/default_options.asm")
local safari_events = read_file(repo_path .. "engine/events/safari_gauntlet.asm")
local trainer_loader = read_file(repo_path .. "engine/battle/read_trainer_party.asm")
local marts = read_file(repo_path .. "data/items/marts.asm")
local battle_core = read_file(repo_path .. "engine/battle/core.asm")
local poke_balls = read_file(repo_path .. "engine/items/poke_balls.asm")
local legendary_mons = read_file(repo_path .. "data/pokemon/legendary_mons.asm")
local pokemon_constants = read_file(repo_path .. "constants/pokemon_constants.asm")

local johto_pool = number_define(wildmons, "SAFARI_GAUNTLET_JOHTO_POOL_COUNT")
assert_true(johto_pool == 251, "FAILED_JOHTO_POOL_COUNT")
assert_true(pokemon_constants:find("const CELEBI", 1, true) ~= nil, "FAILED_CELEBI_CONSTANT_MISSING")

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
assert_true(trainer_loader:find("call SafariGauntlet_AdjustTrainerLevelForDifficulty", 1, true) ~= nil, "FAILED_DIFFICULTY_LEVEL_HOOK")
assert_true(trainer_loader:find("SAFARI_GAUNTLET_DIFFICULTY_CASUAL << SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_SHIFT", 1, true) ~= nil, "FAILED_CASUAL_LEVEL_BRANCH")
assert_true(trainer_loader:find("SAFARI_GAUNTLET_DIFFICULTY_HARD << SAFARI_GAUNTLET_SETTINGS_DIFFICULTY_SHIFT", 1, true) ~= nil, "FAILED_HARD_LEVEL_BRANCH")
assert_true(trainer_loader:find("sub 3", 1, true) ~= nil, "FAILED_CASUAL_LEVEL_DELTA")
assert_true(trainer_loader:find("add 3", 1, true) ~= nil, "FAILED_HARD_LEVEL_DELTA")
assert_true(trainer_loader:find("call SafariGauntlet_LoadCuratedTrainerParty", 1, true) ~= nil, "FAILED_CURATED_TRAINER_HOOK")
assert_true(trainer_loader:find("SafariGauntlet_LoadCuratedTrainerParty:", 1, true) ~= nil, "FAILED_CURATED_TRAINER_HELPER")
assert_true(not trainer_loader:find("SafariGauntlet_PadTrainerPartyForStage", 1, true), "FAILED_DUPLICATE_PADDING_HELPER_STILL_PRESENT")
assert_true(not trainer_loader:find("SafariGauntlet_CopyLastTrainerMon", 1, true), "FAILED_DUPLICATE_COPY_HELPER_STILL_PRESENT")
assert_true(battle_core:find("call .MaybeScaleExp\n\tcall .BoostBalanceExp", 1, true) ~= nil, "FAILED_EXP_MULTIPLIER_HOOK_ORDER")
assert_true(battle_core:find(".BoostBalanceExp:", 1, true) ~= nil, "FAILED_EXP_MULTIPLIER_HELPER")
assert_true(battle_core:find("ld a, 5\n\tldh [hMultiplier], a", 1, true) ~= nil, "FAILED_EXP_MULTIPLIER_NUMERATOR")
assert_true(battle_core:find("ld a, 2\n\tldh [hDivisor], a", 1, true) ~= nil, "FAILED_EXP_MULTIPLIER_DENOMINATOR")
assert_true(battle_core:find("ldh [hQuotient + 2], a", 1, true) ~= nil, "FAILED_EXP_RESULT_COPY")

assert_true(number_define(constants, "SAFARI_GAUNTLET_SETTINGS_INITIALIZED_F") == 5, "FAILED_SETTINGS_INITIALIZED_BIT")
assert_true(default_options:find("1 << PERFECT_IVS_OPT", 1, true) ~= nil, "FAILED_DEFAULT_PERFECT_IVS")
assert_true(default_options:find("1 << TRADED_AS_OT_OPT", 1, true) ~= nil, "FAILED_DEFAULT_TRADED_AS_OT")
assert_true(safari_events:find("SafariGauntlet_EnsureDefaultSettings:", 1, true) ~= nil, "FAILED_DEFAULT_SETTINGS_HELPER")
assert_true(safari_events:find("set PERFECT_IVS_OPT, [hl]", 1, true) ~= nil, "FAILED_HELPER_SETS_PERFECT_IVS")
assert_true(safari_events:find("set TRADED_AS_OT_OPT, [hl]", 1, true) ~= nil, "FAILED_HELPER_SETS_TRADED_AS_OT")
assert_true(safari_events:find("set SAFARI_GAUNTLET_SETTINGS_NATIONAL_F, [hl]", 1, true) ~= nil, "FAILED_HELPER_SETS_NATIONAL")
assert_true(safari_events:find("set SAFARI_GAUNTLET_SETTINGS_INITIALIZED_F, [hl]", 1, true) ~= nil, "FAILED_HELPER_SETS_INITIALIZED")
local _, default_call_count = safari_events:gsub("call SafariGauntlet_EnsureDefaultSettings", "")
assert_true(default_call_count >= 3, "FAILED_DEFAULT_SETTINGS_CALL_COUNT_" .. default_call_count)

local standard_supplies = battle_factory:match("givekeyitem SUPER_ROD.-writetext SafariGauntletStandardSuppliesText")
local casual_supplies = battle_factory:match("%.CasualSupplies.-writetext SafariGauntletCasualSuppliesText")
local hard_supplies = battle_factory:match("%.HardSupplies.-writetext SafariGauntletHardSuppliesText")
assert_true(standard_supplies and standard_supplies:find("giveitem RARE_CANDY, 12", 1, true) ~= nil, "FAILED_STANDARD_RARE_CANDY")
assert_true(casual_supplies and casual_supplies:find("giveitem RARE_CANDY, 16", 1, true) ~= nil, "FAILED_CASUAL_RARE_CANDY")
assert_true(hard_supplies and hard_supplies:find("giveitem RARE_CANDY, 8", 1, true) ~= nil, "FAILED_HARD_RARE_CANDY")
assert_true(battle_factory:find("8-16 Candies", 1, true) ~= nil, "FAILED_RULE_TEXT_CANDY_RANGE")
assert_true(marts:find("BattleFactoryMart5:\n\tdb 4 ; # items", 1, true) ~= nil, "FAILED_BATTLE_FACTORY_MART5_COUNT")
assert_true(marts:find("\tdb LUCKY_EGG,    10", 1, true) ~= nil, "FAILED_LUCKY_EGG_BP_PRICE")

local expected_types = {
	{ "meganium", "GRASS", "GRASS" },
	{ "typhlosion_plain", "FIRE", "FIRE" },
	{ "feraligatr", "WATER", "WATER" },
	{ "noctowl", "NORMAL", "FLYING" },
	{ "butterfree", "BUG", "FLYING" },
	{ "ledian", "BUG", "FLYING" },
	{ "ariados", "BUG", "POISON" },
	{ "dunsparce", "NORMAL", "NORMAL" },
	{ "dudunsparce", "NORMAL", "NORMAL" },
	{ "ampharos", "ELECTRIC", "ELECTRIC" },
	{ "politoed", "WATER", "WATER" },
	{ "bellossom", "GRASS", "GRASS" },
	{ "yanmega", "BUG", "FLYING" },
	{ "sunflora", "GRASS", "GRASS" },
	{ "ninetales_plain", "FIRE", "FIRE" },
	{ "stantler", "NORMAL", "NORMAL" },
	{ "golduck", "WATER", "WATER" },
	{ "girafarig", "NORMAL", "PSYCHIC" },
	{ "farigiraf", "NORMAL", "PSYCHIC" },
	{ "magmortar", "FIRE", "FIRE" },
	{ "electivire", "ELECTRIC", "ELECTRIC" },
	{ "corsola_galarian", "GHOST", "GHOST" },
	{ "cursola", "GHOST", "GHOST" },
	{ "octillery", "WATER", "WATER" },
	{ "rapidash_plain", "FIRE", "FIRE" },
	{ "rhyperior", "GROUND", "ROCK" },
	{ "mismagius", "GHOST", "GHOST" },
	{ "charizard", "FIRE", "FLYING" },
	{ "blastoise", "WATER", "WATER" },
	{ "lugia", "PSYCHIC", "FLYING" },
	{ "mewtwo_armored", "PSYCHIC", "PSYCHIC" },
	{ "celebi", "PSYCHIC", "GRASS" },
}

local function active_type_pair(mon)
	local text = read_file(repo_path .. "data/pokemon/base_stats/" .. mon .. ".asm")
	local active1, active2
	for type1, type2 in text:gmatch("db%s+([A-Z_]+),%s*([A-Z_]+)%s+;%s+type") do
		active1 = type1
		active2 = type2
	end
	assert_true(active1 ~= nil, "FAILED_TYPE_LINE_MISSING_" .. mon)
	return active1, active2
end

for _, entry in ipairs(expected_types) do
	local type1, type2 = active_type_pair(entry[1])
	assert_true(type1 == entry[2] and type2 == entry[3], string.format("FAILED_TYPE_%s_%s_%s", entry[1], type1, type2))
end

local _, roll_count = battle_factory:gsub("special Special_SafariGauntlet_RollTrainerFamily", "")
assert_true(roll_count == 4, "FAILED_TRAINER_FAMILY_ROLL_COUNT_" .. roll_count)
assert_true(not battle_factory:find("random 16", 1, true), "FAILED_ROUND_RANDOM_16_STILL_PRESENT")

local function label_block(text, start_label, end_label)
	local start_pos = text:find(start_label .. ":", 1, true)
	assert_true(start_pos ~= nil, "FAILED_MISSING_LABEL_" .. start_label)
	local end_pos = text:find(end_label .. ":", start_pos + 1, true)
	assert_true(end_pos ~= nil, "FAILED_MISSING_LABEL_" .. end_label)
	return text:sub(start_pos, end_pos - 1)
end

local function loadtrainer_keys(round_label, next_label)
	local block = label_block(battle_factory, round_label, next_label)
	local keys = {}
	local count = 0
	for class, trainer in block:gmatch("loadtrainer%s+([%w_]+),%s*([%w_]+)") do
		local key = class .. "," .. trainer
		assert_true(not keys[key], "FAILED_DUPLICATE_LOADTRAINER_" .. round_label .. "_" .. key)
		keys[key] = true
		count = count + 1
	end
	assert_true(count == 16, "FAILED_LOADTRAINER_COUNT_" .. round_label .. "_" .. count)
	return keys
end

local function curated_team_entries(round_label, next_label, expected_size)
	local block = label_block(trainer_loader, round_label, next_label)
	local entries = {}
	local current = nil
	for line in block:gmatch("[^\n]+") do
		local class, trainer = line:match("^%s*db%s+([%w_]+),%s*([%w_]+)")
		if class then
			local key = class .. "," .. trainer
			assert_true(entries[key] == nil, "FAILED_DUPLICATE_CURATED_TEAM_" .. round_label .. "_" .. key)
			current = { species = {} }
			entries[key] = current
		else
			local species = line:match("^%s*dp%s+([%w_]+),%s*PLAIN_FORM")
			if species then
				assert_true(current ~= nil, "FAILED_CURATED_SPECIES_WITHOUT_TEAM_" .. round_label .. "_" .. species)
				current.species[#current.species + 1] = species
			end
		end
	end

	local count = 0
	for key, entry in pairs(entries) do
		count = count + 1
		assert_true(#entry.species == expected_size, "FAILED_CURATED_TEAM_SIZE_" .. round_label .. "_" .. key .. "_" .. #entry.species)
		local seen_species = {}
		for _, species in ipairs(entry.species) do
			assert_true(not seen_species[species], "FAILED_CURATED_TEAM_DUPLICATE_SPECIES_" .. round_label .. "_" .. key .. "_" .. species)
			seen_species[species] = true
		end
	end
	assert_true(count == 16, "FAILED_CURATED_TEAM_COUNT_" .. round_label .. "_" .. count)
	return entries
end

local function assert_curated_matches_loadtrainers(round_label, next_round_label, team_label, next_team_label, expected_size)
	local expected = loadtrainer_keys(round_label, next_round_label)
	local entries = curated_team_entries(team_label, next_team_label, expected_size)
	for key in pairs(expected) do
		assert_true(entries[key] ~= nil, "FAILED_CURATED_TEAM_MISSING_" .. round_label .. "_" .. key)
	end
	for key in pairs(entries) do
		assert_true(expected[key] ~= nil, "FAILED_CURATED_TEAM_UNUSED_" .. team_label .. "_" .. key)
	end
	log(string.format("CURATED_TRAINERS_OK_%s teams=16 size=%d", round_label, expected_size))
	return entries
end

assert_curated_matches_loadtrainers("SafariGauntletRound1", "SafariGauntletRound2", "SafariGauntletTrainerTeamsRound1", "SafariGauntletTrainerTeamsRound2", 3)
assert_curated_matches_loadtrainers("SafariGauntletRound2", "SafariGauntletRound3", "SafariGauntletTrainerTeamsRound2", "SafariGauntletTrainerTeamsRound3", 4)
assert_curated_matches_loadtrainers("SafariGauntletRound3", "SafariGauntletRound4", "SafariGauntletTrainerTeamsRound3", "SafariGauntletTrainerTeamsRound4", 5)
local round4_entries = assert_curated_matches_loadtrainers("SafariGauntletRound4", "SafariGauntletBattleLoss", "SafariGauntletTrainerTeamsRound4", "SetDynamicForm", 5)

local required_round4_species = {
	WYRDEER = true,
	DUDUNSPARCE = true,
	URSALUNA = true,
	KLEAVOR = true,
	FARIGIRAF = true,
	ANNIHILAPE = true,
}
local found_round4_species = {}
for _, entry in pairs(round4_entries) do
	for _, species in ipairs(entry.species) do
		found_round4_species[species] = true
	end
end
for species in pairs(required_round4_species) do
	assert_true(found_round4_species[species], "FAILED_ROUND4_NATIONAL_SPECIES_MISSING_" .. species)
end

log("VERIFIED_STATIC_RULES")
if emu and emu.screenshot then
	emu:screenshot(screenshot_path)
	log("screenshot=" .. screenshot_path)
end
