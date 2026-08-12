---
name: Library/dane/Function-Plot
tags: meta/library
files:
  - Function-Plot/function-plot.mjs
  - Function-Plot/mathjs-parse.mjs
share.uri: "https://github.com/thedaneeffect/silverbullet-function-plot/blob/main/Function-Plot.md"
share.mode: pull
---

# Function Plot
This library renders `plot` fenced code blocks as graphs with the
[function-plot](https://mauriciopoppe.github.io/function-plot/) library.
A KaTeX caption below the graph shows each equation, color-matched to its
curve. Captions need [[Library/mrmugame/Silverbullet-Math]]. Without it,
captions fall back to plain code text.

## Syntax
Each bare line is one curve, in calculator syntax. The `y =` prefix is
optional. `x: [a, b]` and `y: [a, b]` lines pin the axis domains.

    ```plot
    y = sin(x) / x
    y = x^2 / 10
    x: [-10, 10]
    y: [-2, 2]
    ```

## Implementation
```space-lua
plot = plot or {}

plot.PALETTE = {
  "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
  "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"
}

-- Parse a plot block body.
-- Returns { curves = {...}, xDomain = {lo,hi}?, yDomain = {lo,hi}?, errors = {...} }
function plot.parse(body)
  local result = { curves = {}, errors = {} }
  for line in string.gmatch(body, "[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      local axis, lo, hi = trimmed:match("^([xy])%s*:%s*%[([^,%]]+),([^%]]+)%]%s*$")
      if axis then
        local nlo, nhi = tonumber(lo), tonumber(hi)
        if nlo and nhi then
          result[axis .. "Domain"] = { nlo, nhi }
        else
          table.insert(result.errors,
            "Bad domain line: " .. trimmed .. " (expected form: x: [-10, 10])")
        end
      elseif trimmed:match("^[xy]%s*:") then
        table.insert(result.errors,
          "Bad domain line: " .. trimmed .. " (expected form: x: [-10, 10])")
      else
        table.insert(result.curves, trimmed:match("^y%s*=%s*(.+)$") or trimmed)
      end
    end
  end
  return result
end
```
