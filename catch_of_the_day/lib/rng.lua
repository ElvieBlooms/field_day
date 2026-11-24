-- Deterministic picks: the same save on the same day always gets the same
-- swarm, without touching the game's own RNG.
local bit = bit

local M = {}

local U32 = 4294967296

local function u32(x) return x % U32 end

-- 32-bit multiply without losing precision in doubles
local function mul32(a, b)
  local alo, ahi = a % 65536, math.floor(a / 65536)
  local blo, bhi = b % 65536, math.floor(b / 65536)
  return (alo * blo + ((ahi * blo + alo * bhi) % 65536) * 65536) % U32
end

local function mix(h)
  h = u32(bit.bxor(h, bit.rshift(h, 16)))
  h = mul32(h, 0x7FEB352D)
  h = u32(bit.bxor(h, bit.rshift(h, 15)))
  h = mul32(h, 0x846CA68B)
  return u32(bit.bxor(h, bit.rshift(h, 16)))
end

-- 32-bit hash of any number of integers (lowbias32 mixing).
function M.hash(...)
  local h = 0x9E3779B9
  for i = 1, select("#", ...) do
    local v = math.floor(tonumber((select(i, ...))) or 0) % U32
    h = mix(u32(u32(bit.bxor(h, v)) + 0x632BE5AB))
  end
  return mix(h)
end

-- A float in [0, 1) from the hash of the arguments.
function M.unit(...)
  return M.hash(...) / U32
end

-- Weighted pick from a list of { weight = n, ... }; returns the item or nil.
function M.weighted(list, r)
  local total = 0
  for _, item in ipairs(list) do total = total + (item.weight or 1) end
  if total <= 0 then return nil end
  local target = r * total
  for _, item in ipairs(list) do
    target = target - (item.weight or 1)
    if target < 0 then return item end
  end
  return list[#list]
end

return M
