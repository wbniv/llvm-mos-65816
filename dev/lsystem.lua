-- dev/lsystem.lua — MAME autoboot: let the L-System Plant run, snapshot the real PPU output, and
-- assert the gate proof (corpus_result) matches the host oracle. MAME's video:snapshot() needs a
-- real rendered surface, so dev/lsystem.sh runs MAME under Xvfb. The gate (lsystem_gate_crc) finishes
-- during the title splash; we snapshot at SHOT_AT (gen 6 / 567 segs: 750+ frames for the build +
-- interpret; 1200 has plenty of headroom). Inputs:
--   SHOT_ADDR  program-space addr of corpus_result (e.g. 0x7E____)
--   SHOT_WANT  expected hash (host reference, 0x8073 for gen 6)
--   SHOT_AT    frame to snapshot/assert at (default 1200)
local function num(name, d) local v = os.getenv(name); if not v or v == "" then return d end
  return tonumber(v) or tonumber(v, 16) or d end
local ADDR = num("SHOT_ADDR", 0x7E0000)
local WANT = num("SHOT_WANT", 0x8073)
local AT   = num("SHOT_AT", 1200)

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
