-- dev/wireframe.lua — MAME autoboot: let the 3-D solid spin, snapshot the real PPU output, and assert
-- the projected-vertex proof (corpus_result) matches the host oracle. MAME's video:snapshot() needs a
-- real rendered surface, so dev/wireframe.sh runs MAME under Xvfb. The gate (wire3d_gate_crc) finishes
-- in well under 60 frames; we snapshot well after (SHOT_AT, default 500). Inputs:
--   SHOT_ADDR  program-space addr of corpus_result (e.g. 0x7E136A)
--   SHOT_WANT  expected hash (host reference, 0xE737)
--   SHOT_AT    frame to snapshot/assert at (default 500)
local function num(name, d) local v = os.getenv(name); if not v or v == "" then return d end
  return tonumber(v) or tonumber(v, 16) or d end
local ADDR = num("SHOT_ADDR", 0x7E0000)
local WANT = num("SHOT_WANT", 0xE737)
local AT   = num("SHOT_AT", 500)

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
