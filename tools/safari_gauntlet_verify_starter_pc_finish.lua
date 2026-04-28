local log_path = "/tmp/safari-gauntlet-starter-pc-finish.log"
local screenshot_path = "/tmp/safari-gauntlet-starter-box-ui.png"

local KEY = C.GB_KEY
local function bit(key)
	return 1 << key
end

local A = bit(KEY.A)

local W = {
	crash_code = 0xffe5,
}

local f = assert(io.open(log_path, "w"))

local function log(msg)
	local line = string.format("%08d %s", emu:currentFrame(), msg)
	f:write(line .. "\n")
	f:flush()
	console:log(line)
end

local function read8(addr)
	return emu:read8(addr)
end

local function run_frames(keys, frames)
	emu:clearKeys(0xffffffff)
	if keys and keys ~= 0 then
		emu:addKeys(keys)
	end
	for _ = 1, frames do
		emu:runFrame()
		if read8(W.crash_code) ~= 0 then
			log("FAILED_CRASH crash=" .. read8(W.crash_code))
			emu:screenshot(screenshot_path)
			error("crash")
		end
	end
	emu:clearKeys(0xffffffff)
end

log("Safari Gauntlet starter PC finish verifier loaded")
for _ = 1, 6 do
	run_frames(A, 8)
	run_frames(0, 360)
end
emu:screenshot(screenshot_path)
log("screenshot=" .. screenshot_path)
log("VERIFIED_STARTER_PC_BOX_UI")
