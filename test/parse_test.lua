-- Loads the space-lua block(s) from Function-Plot.md under vanilla Lua,
-- with SilverBullet globals stubbed, then tests plot.parse.

local function readAll(path)
  local f = assert(io.open(path, "r"))
  local s = f:read("*a")
  f:close()
  return s
end

-- Stubs for SilverBullet globals referenced at load time.
codeWidget = { define = function() end }
widget = { new = function(t) return t end }
system = { getURLPrefix = function() return "" end }
local function stubModule()
  return setmetatable({}, { __index = function() return function() end end })
end
js = {
  import = stubModule,
  importFromSpace = stubModule,
  window = { document = { createElement = function() return { innerHTML = "" } end } },
}

local md = readAll("Function-Plot.md")
local found = false
for block in md:gmatch("```space%-lua\n(.-)\n```") do
  found = true
  assert(load(block, "space-lua"))()
end
assert(found, "no space-lua block found in Function-Plot.md")

local function eq(got, want, msg)
  if got ~= want then
    error(msg .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2)
  end
end

-- Bare equations and y= stripping (explicit curves)
local r = plot.parse("y = sin(x) / x\nx^2 / 10\n")
eq(#r.curves, 2, "curve count")
eq(r.curves[1].fn, "sin(x) / x", "y= stripped")
eq(r.curves[1].lhs, nil, "explicit has no lhs")
eq(r.curves[2].fn, "x^2 / 10", "bare line kept")
eq(#r.errors, 0, "no errors")
eq(r.xDomain, nil, "no x domain")

-- Implicit curves split at the first =
r = plot.parse("x^2 / (x + y) = 50\n")
eq(#r.curves, 1, "one implicit curve")
eq(r.curves[1].fn, "(x^2 / (x + y)) - (50)", "implicit fn")
eq(r.curves[1].lhs, "x^2 / (x + y)", "implicit lhs")
eq(r.curves[1].rhs, "50", "implicit rhs")

-- Parenthesized rhs and inner operators survive
r = plot.parse("x^2 + y^2 = (2 + 3)\n")
eq(r.curves[1].fn, "(x^2 + y^2) - ((2 + 3))", "parens preserved")

-- y = stays explicit even with y on the right
r = plot.parse("y = x + 1\n")
eq(r.curves[1].fn, "x + 1", "y= explicit")
eq(r.curves[1].lhs, nil, "y= not implicit")

-- Domains, floats, negatives, whitespace
r = plot.parse("sin(x)\nx: [-6.5, 6.5]\n y : [ -1.5 , 2 ] \n")
eq(#r.curves, 1, "one curve")
eq(r.xDomain[1], -6.5, "x lo")
eq(r.xDomain[2], 6.5, "x hi")
eq(r.yDomain[1], -1.5, "y lo")
eq(r.yDomain[2], 2, "y hi")

-- Blank lines ignored
r = plot.parse("\n\nsin(x)\n\n")
eq(#r.curves, 1, "blank lines ignored")

-- Malformed domain -> error, curves survive
r = plot.parse("sin(x)\nx: [banana, 2]\ny: oops\n")
eq(#r.curves, 1, "curves survive bad domain")
eq(#r.errors, 2, "two bad domain lines")
eq(r.xDomain, nil, "bad domain not set")

-- A z: line has no =, so it stays an explicit curve attempt
r = plot.parse("z: [1, 2]\n")
eq(#r.curves, 1, "z line treated as equation")

print("parse tests ok")
