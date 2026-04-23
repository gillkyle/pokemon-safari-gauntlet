local log_path = "/tmp/safari-gauntlet-checksum-probe.log"
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

local function hexrange(start, count)
	local out = {}
	for i = 0, count - 1 do
		out[#out + 1] = string.format("%02x", read8(start + i))
	end
	return table.concat(out, " ")
end

log("checksum probe")
log(string.format("rom_header=%02x %02x", emu:read8(0x014e), emu:read8(0x014f)))
log(string.format("wRomChecksum=%02x %02x", read8(0xcffe), read8(0xcfff)))
log(string.format("hCrashCode=%02x", emu:read8(0xffe5)))
log(string.format("wOptions/wRom tail cff0-cfff=%s", hexrange(0xcff0, 0x10)))
log(string.format("wSRAMAccessCount=%02x", read8(0xcffd)))
log("log=" .. log_path)
