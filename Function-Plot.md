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

-- js.importFromSpace resolves a space path to its /.fs URL and imports it.
-- It unwraps `default` only when default is the sole export; our bundles
-- export named functions too, so we always get the namespace with .render
-- and .exprToTex (see client/space_lua/stdlib/js.ts in the SilverBullet repo).
local ok, err = pcall(function()
  plot.fp = js.importFromSpace("Library/dane/Function-Plot/function-plot.mjs")
  plot.math = js.importFromSpace("Library/dane/Function-Plot/mathjs-parse.mjs")
end)
if not ok then
  plot.importError = tostring(err)
end

function plot.escapeHtml(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function plot.errorBox(errors)
  local items = {}
  for _, e in ipairs(errors) do
    table.insert(items, "<div>" .. plot.escapeHtml(e) .. "</div>")
  end
  return '<div class="fplot-errors">' .. table.concat(items) .. "</div>"
end

-- One caption line per curve: a color swatch plus the KaTeX-rendered equation.
-- Falls back to code text when Silverbullet-Math is absent or KaTeX rejects it.
function plot.captionHtml(curves)
  local lines = {}
  for _, c in ipairs(curves) do
    local body
    if latex and latex.katex then
      local ok, html = pcall(function()
        return latex.katex.renderToString(plot.math.exprToTex(c.fn), {
          throwOnError = true,
          displayMode = false
        })
      end)
      if ok then body = html end
    end
    if not body then
      body = "<code>" .. plot.escapeHtml(c.fn) .. "</code>"
    end
    table.insert(lines,
      '<div class="fplot-caption-line">'
      .. '<span class="fplot-swatch" style="background:' .. c.color .. '"></span>'
      .. body .. "</div>")
  end
  return '<div class="fplot-caption">' .. table.concat(lines) .. "</div>"
end

function plot.render(body)
  if plot.importError then
    return widget.new {
      display = "block",
      html = '<div class="fplot">' .. plot.errorBox({
        "Function-Plot modules failed to load: " .. plot.importError,
        "Check that Library/dane/Function-Plot/ contains the .mjs bundles."
      }) .. "</div>"
    }
  end

  local spec = plot.parse(body)
  local errors = spec.errors

  local curves = {}
  for i, eq in ipairs(spec.curves) do
    table.insert(curves, {
      fn = eq,
      color = plot.PALETTE[(i - 1) % #plot.PALETTE + 1]
    })
  end

  -- Probe each curve alone, so one bad equation does not take down the block.
  local doc = js.window.document
  local good = {}
  for _, c in ipairs(curves) do
    local probe = doc.createElement("div")
    local ok, perr = pcall(function()
      plot.fp.render {
        target = probe, width = 120, height = 80,
        data = { { fn = c.fn, nSamples = 24 } }
      }
    end)
    if ok then
      table.insert(good, c)
    else
      table.insert(errors, "Cannot plot: " .. c.fn .. " — " .. tostring(perr))
    end
  end

  local svg = ""
  if #good > 0 then
    local container = doc.createElement("div")
    local options = {
      target = container,
      width = 620,
      height = 360,
      grid = true,
      disableZoom = true,
      data = good
    }
    if spec.xDomain then options.xAxis = { domain = spec.xDomain } end
    if spec.yDomain then options.yAxis = { domain = spec.yDomain } end
    local ok, err = pcall(function() plot.fp.render(options) end)
    if ok then
      local svgEl = container.querySelector("svg")
      if svgEl then
        svgEl.setAttribute("viewBox", "0 0 620 360")
        svgEl.removeAttribute("width")
        svgEl.removeAttribute("height")
      end
      svg = container.innerHTML
    else
      table.insert(errors, "function-plot failed: " .. tostring(err))
    end
  elseif #errors == 0 then
    table.insert(errors, "No equations found in plot block")
  end

  local html = '<div class="fplot"><div class="fplot-main">'
    .. plot.captionHtml(good) .. svg .. "</div>"
  if #errors > 0 then
    html = html .. plot.errorBox(errors)
  end
  html = html .. "</div>"

  return widget.new { display = "block", html = html }
end

codeWidget.define {
  language = "plot",
  render = function(body) return plot.render(body) end
}
```

```space-style
.fplot {
  display: flex;
  flex-direction: column;
  gap: 0.5em;
  padding: 0.6em;
}
.fplot-main {
  display: flex;
  align-items: flex-start;
  gap: 0.75em;
}
.fplot svg.function-plot {
  flex: 1 1 auto;
  min-width: 0;
  max-width: 100%;
  height: auto;
}
/* d3 axes use currentColor; inherit the page text color in both themes. */
.fplot .function-plot text {
  fill: currentColor;
}
/* The bundle writes stroke="black" on axes and origin lines; the existing
   opacity attributes keep them subtle in both themes. */
.fplot .function-plot .axis path,
.fplot .function-plot .axis line,
.fplot .function-plot path.origin {
  stroke: currentColor;
}
.fplot-caption {
  flex: 0 1 16em;
  min-width: 8em;
  display: flex;
  flex-direction: column;
  gap: 0.4em;
  align-self: stretch;
  padding-right: 0.6em;
  border-right: 1px solid rgba(128, 128, 128, 0.35);
}
.fplot-caption:empty {
  display: none;
}
.fplot-caption-line {
  display: flex;
  align-items: center;
  gap: 0.5em;
  white-space: nowrap;
  overflow-x: auto;
}
.fplot-swatch {
  width: 0.9em;
  height: 0.9em;
  border-radius: 2px;
  display: inline-block;
  flex-shrink: 0;
}
.fplot-errors {
  border: 1px solid #c0392b;
  border-radius: 4px;
  padding: 0.4em 0.6em;
  color: #c0392b;
  font-size: 0.9em;
}
```
