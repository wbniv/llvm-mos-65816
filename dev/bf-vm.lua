-- dev/bf-vm.lua — MAME autoboot: let the Brainfuck threaded-code VM run, snapshot the real PPU
-- output, and assert the gate proof (corpus_result) matches the host oracle. MAME's
-- video:snapshot() needs a real rendered surface, so dev/bf-vm.sh runs MAME under Xvfb. The gate
-- (bf_vm_gate_crc) finishes in a few frames; the marquee fills over ~75; we snapshot at SHOT_AT
-- (default 500) to show the VM running. Inputs:
--   SHOT_ADDR  program-space addr of corpus_result (e.g. 0x7E137A)
--   SHOT_WANT  expected hash (host reference, 0x9954)
--   SHOT_AT    frame to snapshot/assert at (default 400 — inside the first "HELLO WORLD!" dwell)
local function num(name, d) local v = os.getenv(name); if not v or v == "" then return d end
  return tonumber(v) or tonumber(v, 16) or d end
local ADDR = num("SHOT_ADDR", 0x7E0000)
local WANT = num("SHOT_WANT", 0x9954)
local AT   = num("SHOT_AT", 400)

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
