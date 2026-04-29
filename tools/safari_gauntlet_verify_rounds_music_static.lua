local log_path = "/tmp/safari-gauntlet-rounds-music-static.log"
local repo = "/Users/kyle/dev/pokecrystal"
local f = assert(io.open(log_path, "w"))

local function log(msg)
	f:write(msg .. "\n")
	f:flush()
	if console then
		console:log(msg)
	end
end

local function read_file(path)
	local fh = assert(io.open(path, "r"))
	local text = fh:read("*a")
	fh:close()
	return text
end

local function fail(reason)
	log(reason)
	error(reason)
end

local function assert_true(value, reason)
	if not value then
		fail(reason)
	end
end

local function extract_block(text, first_label, next_label)
	local s = assert(text:find(first_label .. ":", 1, true), "missing " .. first_label)
	local e = assert(text:find(next_label .. ":", s + 1, true), "missing " .. next_label)
	return text:sub(s, e - 1)
end

local map_text = read_file(repo .. "/maps/BattleFactory1F.asm")
local maps_text = read_file(repo .. "/data/maps/maps.asm")
local start_battle_text = read_file(repo .. "/engine/battle/start_battle.asm")
local battle_music_text = read_file(repo .. "/data/battle/music.asm")
local core_text = read_file(repo .. "/engine/battle/core.asm")

local boss_classes = {
	"FALKNER",
	"BUGSY",
	"WHITNEY",
	"MORTY",
	"CHUCK",
	"JASMINE",
	"PRYCE",
	"CLAIR",
	"BROCK",
	"MISTY",
	"LT_SURGE",
	"ERIKA",
	"JANINE",
	"SABRINA",
	"BLAINE",
	"BLUE",
	"WILL",
	"KOGA",
	"BRUNO",
	"KAREN",
	"CHAMPION",
	"RED",
}

for round = 1, 4 do
	local block = extract_block(map_text, "SafariGauntletRound" .. round, round == 4 and "SafariGauntletBattleLoss" or "SafariGauntletRound" .. (round + 1))
	for _, class in ipairs(boss_classes) do
		assert_true(not block:find("loadtrainer " .. class .. ",", 1, true), "FAILED_BOSS_CLASS_IN_ROUND" .. round .. "_" .. class)
	end
end

local boss_block = extract_block(map_text, "SafariGauntletBossBattle", "SafariGauntletDraftFailed")
for _, class in ipairs(boss_classes) do
	assert_true(boss_block:find("loadtrainer " .. class .. ",", 1, true), "FAILED_BOSS_CLASS_MISSING_" .. class)
end

assert_true(not start_battle_text:find("MUSIC_WILD_BATTLE_GO", 1, true), "FAILED_SAFARI_GO_WILD_MUSIC")
assert_true(not start_battle_text:find("MUSIC_TRAINER_BATTLE_BW", 1, true), "FAILED_BATTLE_TOWER_BW_TRAINER_MUSIC")
assert_true(not core_text:find("MUSIC_FINAL_POKEMON_BW", 1, true), "FAILED_FINAL_POKEMON_BW_MUSIC")

for _, expected in ipairs({
	"db WILL,             MUSIC_JOHTO_GYM_LEADER_BATTLE",
	"db KOGA,             MUSIC_JOHTO_GYM_LEADER_BATTLE",
	"db BRUNO,            MUSIC_JOHTO_GYM_LEADER_BATTLE",
	"db KAREN,            MUSIC_JOHTO_GYM_LEADER_BATTLE",
	"db CHAMPION,         MUSIC_CHAMPION_BATTLE",
	"db RED,              MUSIC_CHAMPION_BATTLE",
	"db TOWERTYCOON,      MUSIC_JOHTO_TRAINER_BATTLE",
	"db FACTORYHEAD,      MUSIC_JOHTO_TRAINER_BATTLE",
}) do
	assert_true(battle_music_text:find(expected, 1, true), "FAILED_MUSIC_ENTRY_" .. expected)
end

for _, expected in ipairs({
	"map BattleFactory1F, TILESET_BATTLE_FACTORY, INDOOR, SIGN_BUILDING, VERMILION_CITY, MUSIC_BATTLE_TOWER_LOBBY",
	"map BattleFactoryHallway, TILESET_BATTLE_FACTORY, INDOOR, SIGN_BUILDING, VERMILION_CITY, MUSIC_BATTLE_TOWER_LOBBY",
	"map BattleFactoryBattleRoom, TILESET_BATTLE_FACTORY, INDOOR, SIGN_BUILDING, VERMILION_CITY, MUSIC_BATTLE_TOWER_THEME",
	"map SafariZoneHub, TILESET_SAFARI_ZONE, ROUTE, SIGN_ROUTE, SAFARI_ZONE, MUSIC_EVOLUTION",
	"map SafariZoneEast, TILESET_SAFARI_ZONE, ROUTE, SIGN_ROUTE, SAFARI_ZONE, MUSIC_EVOLUTION",
	"map SafariZoneNorth, TILESET_SAFARI_ZONE, ROUTE, SIGN_ROUTE, SAFARI_ZONE, MUSIC_EVOLUTION",
	"map SafariZoneWest, TILESET_SAFARI_ZONE, ROUTE, SIGN_ROUTE, SAFARI_ZONE, MUSIC_EVOLUTION",
	"map SafariZoneHubRestHouse, TILESET_FACILITY, INDOOR, SIGN_BUILDING, SAFARI_ZONE, MUSIC_VIRIDIAN_CITY",
	"map BattleTower1F, TILESET_BATTLE_TOWER_INSIDE, INDOOR, SIGN_BUILDING, BATTLE_TOWER, MUSIC_BATTLE_TOWER_LOBBY",
	"map BattleTowerBattleRoom, TILESET_BATTLE_TOWER_INSIDE, INDOOR, SIGN_BUILDING, BATTLE_TOWER, MUSIC_BATTLE_TOWER_THEME",
}) do
	assert_true(maps_text:find(expected, 1, true), "FAILED_MAP_MUSIC_" .. expected)
end

assert_true(not maps_text:find("map SafariZoneHub, TILESET_SAFARI_ZONE, ROUTE, SIGN_ROUTE, SAFARI_ZONE, MUSIC_ROUTE_210_DPPT", 1, true), "FAILED_SAFARI_DPPT_MUSIC")
assert_true(not maps_text:find("map BattleFactory1F, TILESET_BATTLE_FACTORY, INDOOR, SIGN_BUILDING, VERMILION_CITY, MUSIC_BATTLE_FACTORY_RSE", 1, true), "FAILED_BATTLE_FACTORY_RSE_MUSIC")

log("VERIFIED_ROUNDS_AND_CRYSTAL_MUSIC")
