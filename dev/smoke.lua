-- dev/smoke.lua — M0 SNES memory assertion (clean-room; no GPL drmon code).
--
-- Boots the cart, lets the init chain reach main(), reads SMOKE_LEN bytes (little-endian)
-- at SMOKE_ADDR, and prints a deterministic "SMOKE:" line that the shell harness greps to
-- set the process exit code. (MAME exposes no Lua hook to set its own exit code, so the
-- verdict travels on stdout.) Used by both dev/smoke.sh (1 byte) and dev/corpus.sh (N bytes).
--
-- Inputs via env:
--   SMOKE_ADDR   65816 program-space address to read (hex, e.g. 0x7E0020)
--   SMOKE_LEN    number of bytes to read, little-endian (default 1)
--   SMOKE_WANT   expected value (hex, default 0x42 — hello.c's "I ran" sentinel)
--   SMOKE_SETTLE periodic ticks to wait before sampling (default 60)

local function getenv_num(name, default)
  local v = os.getenv(name)
  if not v or v == "" then return default end
  return tonumber(v) or tonumber(v, 16) or default
end

local ADDR   = getenv_num("SMOKE_ADDR", 0x7E0020)
local LEN    = getenv_num("SMOKE_LEN", 1)
local WANT   = getenv_num("SMOKE_WANT", 0x42)
local SETTLE = getenv_num("SMOKE_SETTLE", 60)

local hexw   = "0x%0" .. (2 * LEN) .. "X"   -- value width = byte count

local ticks = 0
local done  = false

-- register_periodic fires ~once per frame; wait SETTLE ticks for the soft-stack /
-- .data / .bss / init_array chain to run and main() to store its result.
emu.register_periodic(function()
  if done then return end
  ticks = ticks + 1
  if ticks < SETTLE then return end
  done = true

  local got
  local ok, err = pcall(function()
    local sp = manager.machine.devices[":maincpu"].spaces["program"]
    -- Little-endian assemble via plain arithmetic (portable across Lua versions —
    -- no reliance on 5.3+ bitwise operators).
    got = 0
    local mul = 1
    for i = 0, LEN - 1 do
      got = got + sp:read_u8(ADDR + i) * mul
      mul = mul * 256
    end
  end)

  if not ok then
    print(string.format("SMOKE: FAIL read error addr=0x%06X err=%s", ADDR, tostring(err)))
  elseif got == WANT then
    print(string.format("SMOKE: PASS addr=0x%06X len=%d got=" .. hexw .. " (ran %d ticks)",
                        ADDR, LEN, got, ticks))
  else
    print(string.format("SMOKE: FAIL addr=0x%06X len=%d got=" .. hexw .. " want=" .. hexw,
                        ADDR, LEN, got, WANT))
  end

  manager.machine:exit()
end)
