-- The real-world day, read from the device clock.  Gen 1 has no clock of its
-- own, so the system date drives the schedule on every game.
local M = {}

local WEEKDAYS = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY",
                   "FRIDAY", "SATURDAY" }

-- { day = n (days since 1970, local date), weekday = 1..7 (1 = Sunday),
--   weekdayName = "TUESDAY" }
function M.today()
  local t = os.date("*t")
  -- noon keeps daylight-saving shifts from moving the day boundary
  local stamp = os.time({ year = t.year, month = t.month, day = t.day, hour = 12 })
  return {
    day = math.floor(stamp / 86400),
    weekday = t.wday,
    weekdayName = WEEKDAYS[t.wday] or "TODAY",
  }
end

return M
