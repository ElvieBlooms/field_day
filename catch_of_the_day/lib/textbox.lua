-- Gen 1 text box formatting.  The engine soft-wraps long lines, but wrapped
-- lines scroll on without waiting for A.  Vanilla text marks every break:
-- "\n" for the second line of a paragraph, "\v" (wait for A, then scroll)
-- for every line after that, and "\f" for a new paragraph.  box() wraps
-- plain text the same way.
local M = {}

-- The box holds 18 columns, but restyled text boxes (Facets, for one)
-- clip the 18th, so lines stop at 17.
M.COLUMNS = 17

-- display length: UTF-8 continuation bytes don't take a column (POKéMON)
local function width(s)
  local n = 0
  for i = 1, #s do
    local b = s:byte(i)
    if b < 0x80 or b >= 0xC0 then n = n + 1 end
  end
  return n
end

local function wrap(paragraph, cols)
  local lines, line = {}, ""
  for word in paragraph:gmatch("%S+") do
    if line == "" then
      line = word
    elseif width(line) + 1 + width(word) <= cols then
      line = line .. " " .. word
    else
      lines[#lines + 1] = line
      line = word
    end
    -- a single word longer than the box: cut it, like the engine would
    while width(line) > cols do
      local cut, count = 0, 0
      for i = 1, #line do
        local b = line:byte(i)
        if b < 0x80 or b >= 0xC0 then
          count = count + 1
          if count > cols then break end
        end
        cut = i
      end
      lines[#lines + 1] = line:sub(1, cut)
      line = line:sub(cut + 1)
    end
  end
  if line ~= "" then lines[#lines + 1] = line end
  return lines
end

-- Plain text (paragraphs separated by "\f") to Gen 1 text box codes.
function M.box(text, cols)
  cols = cols or M.COLUMNS
  local out = {}
  for paragraph in (tostring(text) .. "\f"):gmatch("(.-)\f") do
    if paragraph ~= "" then
      local lines = wrap(paragraph, cols)
      local s = lines[1] or ""
      for i = 2, #lines do
        s = s .. (i == 2 and "\n" or "\v") .. lines[i]
      end
      out[#out + 1] = s
    end
  end
  return table.concat(out, "\f")
end

return M
