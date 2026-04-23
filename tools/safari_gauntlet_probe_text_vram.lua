local log_path = "/tmp/safari-gauntlet-text-vram.log"
local f = assert(io.open(log_path, "w"))

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
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

local function bytes_from_memory(mem, start, count)
	if not mem then
		return "missing"
	end
	local out = {}
	for i = 0, count - 1 do
		out[#out + 1] = string.format("%02x", mem:read8(start + i))
	end
	return table.concat(out, " ")
end

local wTilemap = 0xc440
local wAttrmap = 0xc5a8
local function coord(base, x, y)
	return base + y * 20 + x
end

log("probe loaded")
log(string.format("tile inner(1,14)=%02x attr=%02x", read8(coord(wTilemap, 1, 14)), read8(coord(wAttrmap, 1, 14))))
log(string.format("tile inner row=%s", table.concat((function()
	local out = {}
	for x = 1, 18 do
		out[#out + 1] = string.format("%02x", read8(coord(wTilemap, x, 14)))
	end
	return out
end)(), " ")))
log(string.format("attr inner row=%s", table.concat((function()
	local out = {}
	for x = 1, 18 do
		out[#out + 1] = string.format("%02x", read8(coord(wAttrmap, x, 14)))
	end
	return out
end)(), " ")))

if emu.memory then
	for k, v in pairs(emu.memory) do
		log("memory domain " .. tostring(k) .. "=" .. tostring(v))
	end
end

if emu.memory and emu.memory.vram then
	-- Tile $92 is the first 'S' in "Safari" with the normal font.
	log("rVBK=" .. string.format("%02x", emu:read8(0xff4f)))
	log("vram off0920 tile92=" .. bytes_from_memory(emu.memory.vram, 0x920, 16))
	log("vram off2920 tile92=" .. bytes_from_memory(emu.memory.vram, 0x2000 + 0x920, 16))
	log("vram off0800 tile80=" .. bytes_from_memory(emu.memory.vram, 0x800, 16))
	log("vram off2800 tile80=" .. bytes_from_memory(emu.memory.vram, 0x2000 + 0x800, 16))
end

log("wOptions2=" .. string.format("%02x", read8(0xcff5)))
