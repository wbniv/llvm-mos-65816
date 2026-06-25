-- dev/mandel-shot.lua — MAME autoboot: wait for the on-console Mandelbrot to finish,
-- snapshot the real PPU output, and assert the compute (corpus_result) matches the host.
--
-- MAME's video:snapshot() only captures a real rendered surface, so dev/mandel-shot.sh
-- runs MAME under Xvfb (offscreen/-video none give an all-black PNG). The fill takes
-- the Mode 7 render takes ~5600 frames; we snapshot well after (SHOT_AT, default 5800) so
-- the screen is on and stable. Inputs via env:
--   SHOT_ADDR  program-space addr of corpus_result (e.g. 0x7E0400)
--   SHOT_WANT  expected CRC (host reference)
--   SHOT_AT    frame to snapshot/assert at (default 5800)
local function num(name, d) local v = os.getenv(name); if not v or v == "" then return d end
  return tonumber(v) or tonumber(v, 16) or d end
local ADDR = num("SHOT_ADDR", 0x7E0400)
local WANT = num("SHOT_WANT", 0x204F)
local AT   = num("SHOT_AT", 5800)

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
