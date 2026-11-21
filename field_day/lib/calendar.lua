-- The real-world day, read from the device clock.  Gen 1 has no clock of its
-- own, so the system date drives the schedule on every game.
local M = {}

local WEEKDAYS = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY",
                   "FRIDAY", "SATURDAY" }

-- Days to add to the real date, for testing.  main.lua points this at the
-- TEST: DAYS AHEAD option.
M.offset = function() return 0 end

-- { day = n (days since 1970, local date), weekday = 1..7 (1 = Sunday),
--   weekdayName = "TUESDAY", offset = days added for testing }
function M.today()
  local offset = math.floor(tonumber(M.offset()) or 0)
  local now = os.date("*t")
  -- noon keeps daylight-saving shifts from moving the day boundary, and
  -- day numbers stay whole whatever the offset
  local noon = os.time({ year = now.year, month = now.month, day = now.day, hour = 12 })
  local shifted = noon + offset * 86400
  local t = os.date("*t", shifted)
  return {
    day = math.floor(shifted / 86400),
    weekday = t.wday,
    weekdayName = WEEKDAYS[t.wday] or "TODAY",
    offset = offset,
  }
end

return M
