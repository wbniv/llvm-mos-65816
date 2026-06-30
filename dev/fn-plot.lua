-- dev/fn-plot.lua — MAME autoboot: let fn-plot run, snapshot the PPU output, assert gate proof.
-- fn_gate_crc() finishes in ~9 frames; snapshot at 500 to show the partial curve + HUD.
-- Inputs (env vars):
--   SHOT_ADDR  WRAM addr of corpus_result (e.g. 0x7E0123)
--   SHOT_WANT  expected hash (0x2EBE)
--   SHOT_AT    frame to snapshot (default 500)
local function num(name, d) local v = os.getenv(name)
  if not v or v == "" then return d end
  return tonumber(v) or tonumber(v, 16) or d end
local ADDR = num("SHOT_ADDR", 0x7E0000)
local WANT = num("SHOT_WANT", 0x2EBE)
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
