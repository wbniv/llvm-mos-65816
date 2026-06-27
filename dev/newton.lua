-- dev/newton.lua — MAME autoboot: let the Newton fractal run, snapshot the PPU output,
-- and assert corpus_result matches the host oracle. corpus_result is set before the
-- first display_frame() call (gate hash runs inline before the loop), so it is visible
-- by frame 1; we snapshot at SHOT_AT (default 500) to capture the partially-filled fractal.
-- Inputs (env):
--   SHOT_ADDR  program-space addr of corpus_result (e.g. 0x7E0ABC)
--   SHOT_WANT  expected hash (host oracle, e.g. 0x????), hex or decimal
--   SHOT_AT    frame to snapshot/assert at (default 500)
local function num(name, d) local v = os.getenv(name); if not v or v == "" then return d end
  return tonumber(v) or tonumber(v, 16) or d end
local ADDR = num("SHOT_ADDR", 0x7E0000)
local WANT = num("SHOT_WANT", 0x0000)
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
