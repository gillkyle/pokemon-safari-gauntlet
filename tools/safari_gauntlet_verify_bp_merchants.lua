local log_path = "/tmp/safari-gauntlet-bp-merchants.log"
local screenshot_path = "/tmp/safari-gauntlet-bp-merchants.png"
local repo_path = "/Users/kyle/dev/pokecrystal/"

local f = assert(io.open(log_path, "w"))

local function log(msg)
	local frame = emu and emu.currentFrame and emu:currentFrame() or 0
	local line = string.format("%08d %s", frame, msg)
	f:write(line .. "\n")
	f:flush()
	if console and console.log then
		console:log(line)
	else
		print(line)
	end
end

local function fail(label)
	log(label)
	if emu and emu.screenshot then
		emu:screenshot(screenshot_path)
		log("screenshot=" .. screenshot_path)
	end
	error(label)
end

local function assert_true(ok, label)
	if not ok then
		fail(label)
	end
end

local function read_file(path)
	local handle = assert(io.open(path, "r"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local function parse_bp_mart(text, label)
	local block = text:match(label .. ":%s*\n(.-)\n%s*db %-1")
	assert_true(block ~= nil, "FAILED_MISSING_" .. label)
	local count = tonumber(block:match("db%s+(%d+)%s+;%s+# items"))
	assert_true(count ~= nil, "FAILED_MISSING_COUNT_" .. label)
	local items = {}
	for item, cost in block:gmatch("db%s+([A-Z0-9_]+),%s*(%d+)") do
		items[item] = tonumber(cost)
	end
	return count, items
end

local marts = read_file(repo_path .. "data/items/marts.asm")
local evos = read_file(repo_path .. "data/pokemon/evos_attacks.asm")
local map = read_file(repo_path .. "maps/BattleFactory1F.asm")
local wram = read_file(repo_path .. "ram/wramx.asm")
local mart_engine = read_file(repo_path .. "engine/items/mart.asm")

local evolution_items = {}
for line in evos:gmatch("[^\n]+") do
	local method, item = line:match("evo_data%s+([A-Z0-9_]+),%s*([A-Z0-9_]+)")
	if method == "EVOLVE_ITEM" or method == "EVOLVE_TRADE" or method == "EVOLVE_HOLDING" then
		evolution_items[item] = method
	end
end

local factory_counts = {}
local factory_items = {}
for _, mart in ipairs({ "BattleFactoryMart1", "BattleFactoryMart4", "BattleFactoryMart5" }) do
	local count, items = parse_bp_mart(marts, mart)
	factory_counts[mart] = count
	assert_true(count <= 12, "FAILED_FACTORY_PAGE_TOO_LARGE_" .. mart .. "_" .. count)
	for item, cost in pairs(items) do
		factory_items[item] = cost
	end
end
local required_count = 0
for item in pairs(evolution_items) do
	required_count = required_count + 1
	assert_true(factory_items[item] == 12, "FAILED_EVOLUTION_ITEM_BP_" .. item)
end
assert_true(factory_items.RARE_CANDY == 36, "FAILED_FACTORY_RARE_CANDY_BP")
assert_true(factory_items.LUCKY_EGG == 12, "FAILED_FACTORY_LUCKY_EGG_BP")
local factory_count = factory_counts.BattleFactoryMart1 + factory_counts.BattleFactoryMart4 + factory_counts.BattleFactoryMart5
assert_true(factory_count == required_count + 2, "FAILED_FACTORY_ITEM_COUNT_" .. factory_count)

local tower_count, tower_items = parse_bp_mart(marts, "BattleTowerMart2")
assert_true(tower_count == 9, "FAILED_TOWER_MART2_COUNT_" .. tower_count)
assert_true(tower_items.RARE_CANDY == 36, "FAILED_TOWER_RARE_CANDY_BP")

local battle_count_2, battle_items_2 = parse_bp_mart(marts, "BattleFactoryMart2")
assert_true(battle_count_2 <= 12, "FAILED_BATTLE_MART2_TOO_LARGE_" .. battle_count_2)
for _, item in ipairs({
	"CHOICE_BAND",
	"CHOICE_SCARF",
	"CHOICE_SPECS",
	"LIFE_ORB",
	"FOCUS_SASH",
	"LEFTOVERS",
	"EXPERT_BELT",
	"ASSAULT_VEST",
	"MUSCLE_BAND",
	"WISE_GLASSES",
	"EVIOLITE",
	"WEAK_POLICY",
}) do
	assert_true(battle_items_2[item] ~= nil, "FAILED_BATTLE_MART2_ITEM_" .. item)
end
assert_true(battle_items_2.LIFE_ORB == 48, "FAILED_LIFE_ORB_BP")

local battle_count_3, battle_items_3 = parse_bp_mart(marts, "BattleFactoryMart3")
assert_true(battle_count_3 <= 12, "FAILED_BATTLE_MART3_TOO_LARGE_" .. battle_count_3)
for _, item in ipairs({
	"CLEAR_AMULET",
	"SCOPE_LENS",
	"WIDE_LENS",
	"ZOOM_LENS",
	"ROCKY_HELMET",
	"AIR_BALLOON",
	"LOADED_DICE",
	"THROAT_SPRAY",
	"EJECT_BUTTON",
	"EJECT_PACK",
	"FLAME_ORB",
	"TOXIC_ORB",
}) do
	assert_true(battle_items_3[item] ~= nil, "FAILED_BATTLE_MART3_ITEM_" .. item)
end

local mart_capacity = tonumber(wram:match("wCurMart::%s+ds%s+(%d+)"))
assert_true(mart_capacity and mart_capacity >= 14, "FAILED_WCURMART_CAPACITY")
assert_true(map:find("object_event 20, 10, SPRITE_CLERK", 1, true) == nil, "FAILED_FLOOR_BATTLE_MERCHANT_STILL_PRESENT")
assert_true(map:find("object_event 24,  6, SPRITE_CLERK, SPRITEMOVEDATA_STANDING_DOWN, 0, 0, -1, PAL_NPC_BROWN, OBJECTTYPE_COMMAND, pokemart, MARTTYPE_BP, MART_BATTLEFACTORY_2", 1, true) ~= nil, "FAILED_BATTLE_MERCHANT_STAPLES")
assert_true(map:find("PAL_NPC_RED, OBJECTTYPE_COMMAND, pokemart, MARTTYPE_BP, MART_BATTLEFACTORY_1", 1, true) ~= nil, "FAILED_EVO_MERCHANT_STONES")
assert_true(map:find("PAL_NPC_GREEN, OBJECTTYPE_COMMAND, pokemart, MARTTYPE_BP, MART_BATTLEFACTORY_4", 1, true) ~= nil, "FAILED_EVO_MERCHANT_TRADE")
assert_true(map:find("PAL_NPC_BLUE, OBJECTTYPE_COMMAND, pokemart, MARTTYPE_BP, MART_BATTLEFACTORY_5", 1, true) ~= nil, "FAILED_EVO_MERCHANT_MISC")

for _, hm in ipairs({
	{ "HM_CUT", 5 },
	{ "HM_FLY", 6 },
	{ "HM_SURF", 6 },
	{ "HM_STRENGTH", 5 },
	{ "HM_WHIRLPOOL", 5 },
	{ "HM_WATERFALL", 6 },
}) do
	local name, cost = hm[1], hm[2]
	assert_true(map:find("checktmhm " .. name, 1, true) ~= nil, "FAILED_HM_CHECK_" .. name)
	assert_true(map:find("givetmhm " .. name, 1, true) ~= nil, "FAILED_HM_GIVE_" .. name)
	assert_true(map:find("checkbp " .. cost .. "\n\tifequalfwd HAVE_LESS, .NotEnoughBP\n\tgettmhmname " .. name, 1, true) ~= nil, "FAILED_HM_COST_" .. name)
	assert_true(map:find("givetmhm " .. name .. "\n\ttakebp " .. cost, 1, true) ~= nil, "FAILED_HM_TAKEBP_" .. name)
end

assert_true(map:find("HMs       5%-6BP@") ~= nil, "FAILED_HM_MENU_ENTRY")
assert_true(map:find("SafariGauntletHMVendorMenuData", 1, true) ~= nil, "FAILED_HM_MENU_DATA")

local confirm_block = mart_engine:match("BTMartConfirmPurchase:%s*\n(.-)\n%s*ExpCandyConfirmPurchase:")
assert_true(confirm_block ~= nil, "FAILED_BT_CONFIRM_BLOCK_MISSING")
assert_true(confirm_block:find("call BTMartLoadPurchaseCost", 1, true) ~= nil, "FAILED_BT_CONFIRM_COST_REFRESH")
assert_true(mart_engine:find("BTMartLoadPurchaseCost:", 1, true) ~= nil, "FAILED_BT_COST_HELPER_MISSING")
assert_true(mart_engine:find("BTMartGetSelectedPointCost:", 1, true) ~= nil, "FAILED_BT_POINT_COST_HELPER_MISSING")
local ask_cost_block = mart_engine:match("BTMartGetSelectedPointCost:%s*\n(.-)\n%s*BTMartLoadPurchaseCost:")
assert_true(ask_cost_block and ask_cost_block:find("ld hl, wMartItem1BCD", 1, true), "FAILED_BT_ASK_COST_BUFFER_LOOKUP")
local load_cost_block = mart_engine:match("BTMartLoadPurchaseCost:%s*\n(.-)\n%s*BlueCardMartComparePoints:")
assert_true(load_cost_block and load_cost_block:find("ld a, [wBuySellPriceLo]", 1, true), "FAILED_BT_CONFIRM_UNIT_COST_SOURCE")

log(string.format("VERIFIED_BP_MERCHANTS evolution_items=%d factory_count=%d", required_count, factory_count))
if emu and emu.screenshot then
	emu:screenshot(screenshot_path)
	log("screenshot=" .. screenshot_path)
end
