-- dev/rotslab.lua: MAME assert for In-Place Block Rotate (#94).
local function num(k, d) local v = os.getenv(k); return v and tonumber(v) or d end
local ADDR = num("SHOT_ADDR", 0x7E0000)
local WANT = num("SHOT_WANT", 0xB93A)
local AT   = num("SHOT_AT",   500)

local f, done = 0, false
emu.register_periodic(function()
  if done then return end
  f = f + 1
  if f < AT then return end
  done = true
  local sp = manager.machine.devices[":maincpu"].spaces["program"]
  local v = sp:read_u8(ADDR) + sp:read_u8(ADDR + 1) * 256
  manager.machine.video:snapshot()
  if v == WANT then
    print(string.format("SHOT: PASS corpus=0x%04X (snapshot at frame %d)", v, f))
  else
    print(string.format("SHOT: FAIL corpus=0x%04X want=0x%04X", v, WANT))
  end
  manager.machine:exit()
end)
