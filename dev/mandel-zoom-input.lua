-- dev/mandel-zoom-input.lua — MAME autoboot: inject the SNES R button (the "dive" control) and
-- assert the demo responds — i.e. that the LIVE MAME controller path (snes_read_pad1 reading $4016)
-- drives the zoom, not just the bsnes-jg scripted-input differential. This closes the gap a bug
-- report exposed (the user's "Y/A/R don't work" turned out to be MAME's non-obvious default key map,
-- but the MAME *input path itself* had no test — only the boot snapshot). Holds P1 R for a window,
-- then asserts cur_level advanced past 0 (the dive swapped levels). Inputs via env:
--   INJ_ADDR  program-space addr of cur_level (e.g. 0x7E0028)
--   INJ_AT    frame to check/exit at (default 230)
local function num(name, d) local v = os.getenv(name); if not v or v == "" then return d end
  return tonumber(v) or tonumber(v, 16) or d end
local ADDR = num("INJ_ADDR", 0x7E0028)
local AT   = num("INJ_AT", 230)

-- Find P1 R (the dive button) across the ioport fields.
local RBTN
for _, port in pairs(manager.machine.ioport.ports) do
  for fname, field in pairs(port.fields) do
    if fname == "P1 R" then RBTN = field end
  end
end

local f = 0
emu.register_periodic(function()
  f = f + 1
  if RBTN and f >= 40 and f < AT - 30 then RBTN:set_value(1) end   -- hold R to dive
  if f == AT then
    local sp = manager.machine.devices[":maincpu"].spaces["program"]
    local lvl = sp:read_u8(ADDR)
    if RBTN and lvl >= 2 then
      print(string.format("INPUT: PASS cur_level=%d after holding P1 R (live MAME controller path)", lvl))
    else
      print(string.format("INPUT: FAIL cur_level=%d (R field %s)", lvl, RBTN and "found" or "MISSING"))
    end
    manager.machine:exit()
  end
end)
