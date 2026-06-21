-- dev/probe-cycles.lua — #320 Inc 4 Ph2 (M): far-pointer CC throughput probe.
--
-- Boots a farcc_bench.c ROM (an infinite far-ptr round-trip loop), runs a FIXED number
-- of frames, then reads two volatile WRAM symbols and prints a deterministic, greppable
-- line the shell harness (dev/measure-far-cc.sh) parses:
--   * corpus_result (1 byte) — must be 0xF3 (the round-trip is correct), else the
--     timing is meaningless;
--   * iters (4 bytes, little-endian) — round-trips completed by frame PROBE_SETTLE.
-- More iters in the same wall of emulated time == cheaper per-call far-ptr passing.
-- MAME 0.285's Lua exposes no total_cycles(); this frame-deterministic count is the
-- cycle metric (and is exact — MAME runs the same K frames identically every run).
--
-- Inputs via env (addresses are 65816 program-space, hex):
--   PROBE_CORPUS_ADDR   WRAM address of corpus_result   (e.g. 0x7E0004)
--   PROBE_ITERS_ADDR    WRAM address of iters (4 bytes) (e.g. 0x7E0005)
--   PROBE_WANT          expected corpus_result (default 0xF3)
--   PROBE_SETTLE        frames to run before sampling (default 120)

local function getenv_num(name, default)
  local v = os.getenv(name)
  if not v or v == "" then return default end
  return tonumber(v) or tonumber(v, 16) or default
end

local CORPUS = getenv_num("PROBE_CORPUS_ADDR", 0x7E0004)
local ITERS  = getenv_num("PROBE_ITERS_ADDR", 0x7E0005)
local WANT   = getenv_num("PROBE_WANT", 0xF3)
local SETTLE = getenv_num("PROBE_SETTLE", 120)

local ticks = 0
local done  = false

emu.register_periodic(function()
  if done then return end
  ticks = ticks + 1
  if ticks < SETTLE then return end
  done = true

  local ok, result, iters = pcall(function()
    local sp = manager.machine.devices[":maincpu"].spaces["program"]
    local r = sp:read_u8(CORPUS)
    -- 4-byte little-endian iters via plain arithmetic (no 5.3+ bitwise needed).
    local it, mul = 0, 1
    for i = 0, 3 do
      it = it + sp:read_u8(ITERS + i) * mul
      mul = mul * 256
    end
    return r, it
  end)

  if not ok then
    print(string.format("PROBE: FAIL read error (%s)", tostring(result)))
  elseif result == WANT then
    print(string.format("PROBE: PASS result=0x%02X iters=%d (ran %d frames)", result, iters, ticks))
  else
    print(string.format("PROBE: FAIL result=0x%02X want=0x%02X iters=%d (ran %d frames)",
                        result, WANT, iters, ticks))
  end

  manager.machine:exit()
end)
