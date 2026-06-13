-- dev/smoke.lua — M0 SNES smoke assertion (clean-room; no GPL drmon code).
--
-- Boots the cart, lets the init chain reach main(), reads one WRAM byte, and prints
-- a deterministic "SMOKE:" line that dev/smoke.sh greps to set the process exit code.
-- (MAME exposes no Lua hook to set its own exit code, so the verdict travels on stdout.)
--
-- Invoked headless by dev/smoke.sh:
--   mame snes -cart build/hello.sfc -autoboot_script dev/smoke.lua \
--        -skip_gameinfo -video none -sound none -nothrottle -seconds_to_run 3
--
-- Inputs via env:
--   SMOKE_ADDR   65816 program-space address to read (hex, e.g. 0x7E0020)
--   SMOKE_WANT   expected byte (hex, default 0x42 — hello.c's "I ran" sentinel)
--   SMOKE_SETTLE periodic ticks to wait before sampling (default 60)

local function getenv_num(name, default)
  local v = os.getenv(name)
  if not v or v == "" then return default end
  return tonumber(v) or tonumber(v, 16) or default
end

local ADDR   = getenv_num("SMOKE_ADDR", 0x7E0020)
local WANT   = getenv_num("SMOKE_WANT", 0x42)
local SETTLE = getenv_num("SMOKE_SETTLE", 60)

local ticks = 0
local done  = false

-- register_periodic fires ~once per frame; wait SETTLE ticks for the soft-stack /
-- .data / .bss / init_array chain to run and main() to start looping on `sentinel`.
emu.register_periodic(function()
  if done then return end
  ticks = ticks + 1
  if ticks < SETTLE then return end
  done = true

  local got
  local ok, err = pcall(function()
    local sp = manager.machine.devices[":maincpu"].spaces["program"]
    got = sp:read_u8(ADDR)
  end)

  if not ok then
    print(string.format("SMOKE: FAIL read error addr=0x%06X err=%s", ADDR, tostring(err)))
  elseif got == WANT then
    print(string.format("SMOKE: PASS addr=0x%06X got=0x%02X (ran %d ticks)", ADDR, got, ticks))
  else
    print(string.format("SMOKE: FAIL addr=0x%06X got=0x%02X want=0x%02X", ADDR, got, WANT))
  end

  manager.machine:exit()
end)
