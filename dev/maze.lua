-- dev/maze.lua — MAME autoboot: let the Maze generate+solve demo run, snapshot the real PPU
-- output, and assert the gate proof (corpus_result) matches the host oracle. MAME's
-- video:snapshot() needs a real rendered surface, so dev/maze.sh runs MAME under Xvfb. The gate
-- (maze_gate_crc) finishes in well under 100 frames (the carve + A* are cheap); we snapshot at
-- SHOT_AT (default 400) to show the maze built and the A* exploring/path lit. Inputs:
--   SHOT_ADDR  program-space addr of corpus_result (e.g. 0x7E0DBC)
--   SHOT_WANT  expected hash (host reference, 0x0749)
--   SHOT_AT    frame to snapshot/assert at (default 400)
local function num(name, d) local v = os.getenv(name); if not v or v == "" then return d end
  return tonumber(v) or tonumber(v, 16) or d end
local ADDR = num("SHOT_ADDR", 0x7E0000)
local WANT = num("SHOT_WANT", 0x0749)
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
