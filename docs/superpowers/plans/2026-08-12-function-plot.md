# Function-Plot Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A SilverBullet v2 library that renders ```` ```plot ```` code blocks as function-plot SVG graphs with KaTeX equation captions.

**Architecture:** One library page (`Function-Plot.md`) holds all Space Lua code and CSS. Two vendored single-file ES modules (function-plot, mathjs parse) sit next to it and load through `js.import`. The Lua splits into a pure parser (testable with the local `lua` CLI) and a render function (verified manually on the server).

**Tech Stack:** SilverBullet v2 Space Lua, function-plot, mathjs (`parse().toTex()` only), esbuild for bundling, KaTeX via the already-installed `Library/mrmugame/Silverbullet-Math`.

## Global Constraints

- Repo: `~/projects/silverbullet-function-plot`, GitHub `thedaneeffect/silverbullet-function-plot`, public.
- Library page name in the space: `Library/dane/Function-Plot`.
- Deploy target: `medieval.software`, space at `/home/dane/silverbullet/space`.
- No CDN loads. All runtime assets load from the space through `.fs/` paths.
- Vendored bundles are committed. `npm run build` regenerates them.
- The `space-lua` block must load under vanilla Lua 5.4 with stubbed globals. The parse test harness depends on this.
- Commit messages: concise, no Co-Authored-By trailer, no AI attribution.
- README and docs prose: ASD-STE100 flavored style (short sentences, active voice, no contractions).
- The spec is at `docs/superpowers/specs/2026-08-12-function-plot-design.md`. It is the authority on behavior.

---

### Task 1: Repo scaffold and vendored bundles

**Files:**
- Create: `package.json`
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `build.mjs`
- Create: `entries/function-plot-entry.mjs`
- Create: `entries/mathjs-entry.mjs`
- Create: `Function-Plot/function-plot.mjs` (build output, committed)
- Create: `Function-Plot/mathjs-parse.mjs` (build output, committed)
- Test: `test/smoke.mjs`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `Function-Plot/mathjs-parse.mjs` exporting `exprToTex(expr: string): string` (both named and on the default object). `Function-Plot/function-plot.mjs` exporting `render(options: object)` (both named and on the default object). Later Lua code calls `mod.exprToTex(...)` and `mod.render(...)` regardless of whether `js.import` returns the module namespace or the default export.

- [ ] **Step 1: Write the scaffold files**

`package.json`:

```json
{
  "name": "silverbullet-function-plot",
  "private": true,
  "version": "0.1.0",
  "description": "SilverBullet library: plot equations with function-plot, captioned with KaTeX",
  "type": "module",
  "scripts": {
    "build": "node build.mjs",
    "test": "node test/smoke.mjs && lua test/parse_test.lua"
  }
}
```

`.gitignore`:

```
node_modules/
```

`LICENSE`: MIT license text, `Copyright (c) 2026 thedaneeffect`. Vendored bundles keep their own licenses (function-plot: MIT, mathjs: Apache-2.0); the README attribution section covers this in Task 5.

- [ ] **Step 2: Install dependencies**

```bash
npm install --no-fund --no-audit mathjs function-plot esbuild
```

Expected: three packages in `dependencies` in `package.json`. (esbuild lands in dependencies too; this is fine for a private package.)

- [ ] **Step 3: Write the bundle entries and build script**

`entries/function-plot-entry.mjs`:

```js
import fp from 'function-plot';

// The CJS build exports { default: fn, Chart, ... }. Depending on interop,
// the import lands on the function or on that object. Normalize here.
const functionPlot = typeof fp === 'function' ? fp : fp.default;

export function render(options) {
  return functionPlot(options);
}

export default { render };
```

`entries/mathjs-entry.mjs`:

```js
import { parse } from 'mathjs';

// function-plot spells the constant PI; mathjs typesets `pi` as the Greek letter.
export function exprToTex(expr) {
  return parse(expr.replace(/\bPI\b/g, 'pi')).toTex();
}

export default { exprToTex };
```

`build.mjs`:

```js
import { build } from 'esbuild';

const shared = { bundle: true, minify: true, format: 'esm', logLevel: 'info' };

await build({ ...shared, entryPoints: ['entries/function-plot-entry.mjs'], outfile: 'Function-Plot/function-plot.mjs' });
await build({ ...shared, entryPoints: ['entries/mathjs-entry.mjs'], outfile: 'Function-Plot/mathjs-parse.mjs' });
```

- [ ] **Step 4: Write the failing smoke test**

`test/smoke.mjs`:

```js
import mathMod from '../Function-Plot/mathjs-parse.mjs';
import fpMod from '../Function-Plot/function-plot.mjs';

const tex = mathMod.exprToTex('sin(x) / x');
if (!tex.includes('\\frac')) throw new Error(`no \\frac in: ${tex}`);
if (!tex.includes('\\sin')) throw new Error(`no \\sin in: ${tex}`);
if (mathMod.exprToTex('PI * x').includes('PI')) throw new Error('PI alias failed');
if (typeof fpMod.render !== 'function') throw new Error('function-plot render missing');
console.log('smoke ok');
```

- [ ] **Step 5: Run the smoke test to verify it fails**

Run: `node test/smoke.mjs`
Expected: FAIL with "Cannot find module" (bundles do not exist yet).

- [ ] **Step 6: Build the bundles**

Run: `npm run build`
Expected: esbuild reports two outfiles. `Function-Plot/function-plot.mjs` about 215 KB, `Function-Plot/mathjs-parse.mjs` about 670 KB.

- [ ] **Step 7: Run the smoke test to verify it passes**

Run: `node test/smoke.mjs`
Expected: prints `smoke ok`.

- [ ] **Step 8: Commit**

```bash
git add package.json package-lock.json .gitignore LICENSE build.mjs entries/ Function-Plot/ test/smoke.mjs
git commit -m "Add build pipeline and vendored function-plot and mathjs bundles"
```

---

### Task 2: Library page with the block parser

**Files:**
- Create: `Function-Plot.md`
- Test: `test/parse_test.lua`

**Interfaces:**
- Consumes: nothing from Task 1 (pure Lua).
- Produces: `plot.parse(body: string)` returning a Lua table `{ curves = { "sin(x)/x", ... }, xDomain = {lo, hi} or nil, yDomain = {lo, hi} or nil, errors = { "message", ... } }`. Curves are equation strings with any leading `y =` stripped. Task 3 consumes exactly this table.

- [ ] **Step 1: Write the library page skeleton with the parser**

`Function-Plot.md` (note: the page contains triple-backtick fences, shown verbatim below):

````markdown
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
````

Stop the page here for now. Task 3 appends the render code to this same `space-lua` block and adds the `space-style` block.

- [ ] **Step 2: Write the failing parse test**

`test/parse_test.lua`:

```lua
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

-- Bare equations and y= stripping
local r = plot.parse("y = sin(x) / x\nx^2 / 10\n")
eq(#r.curves, 2, "curve count")
eq(r.curves[1], "sin(x) / x", "y= stripped")
eq(r.curves[2], "x^2 / 10", "bare line kept")
eq(#r.errors, 0, "no errors")
eq(r.xDomain, nil, "no x domain")

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

-- A z: line is not a directive; it falls through as an equation attempt
r = plot.parse("z: [1, 2]\n")
eq(#r.curves, 1, "z line treated as equation")

print("parse tests ok")
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `lua test/parse_test.lua`
Expected: FAIL. Before Step 1 exists it fails opening the file; if the page skeleton is already written, it must pass instead — in that case treat this as the verify step.

- [ ] **Step 4: Run the test to verify it passes**

Run: `lua test/parse_test.lua`
Expected: prints `parse tests ok`.

- [ ] **Step 5: Commit**

```bash
git add Function-Plot.md test/parse_test.lua
git commit -m "Add library page with plot block parser and tests"
```

---

### Task 3: Render function, captions, and styles

**Files:**
- Modify: `Function-Plot.md` (extend the `space-lua` block, add a `space-style` block)
- Test: `test/parse_test.lua` (rerun; it loads the whole block and catches load errors)

**Interfaces:**
- Consumes: `plot.parse` from Task 2. `mod.render(options)` and `mod.exprToTex(expr)` from Task 1. The global `latex.katex.renderToString(tex, opts)` from the Silverbullet-Math library (may be absent).
- Produces: `plot.render(body: string)` returning a `widget.new{...}` table. A `codeWidget.define` registration for language `plot`.

- [ ] **Step 1: Append the render code to the space-lua block in `Function-Plot.md`**

Add below `plot.parse`, inside the same `space-lua` fence:

```lua
-- js.importFromSpace resolves a space path to its /.fs URL and imports it.
-- It unwraps `default` only when default is the sole export; our bundles
-- export named functions too, so we always get the namespace with .render
-- and .exprToTex (see client/space_lua/stdlib/js.ts in the SilverBullet repo).
plot.fp = js.importFromSpace("Library/dane/Function-Plot/function-plot.mjs")
plot.math = js.importFromSpace("Library/dane/Function-Plot/mathjs-parse.mjs")

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
    local ok = pcall(function()
      plot.fp.render {
        target = probe, width = 120, height = 80,
        data = { { fn = c.fn, nSamples = 24 } }
      }
    end)
    if ok then
      table.insert(good, c)
    else
      table.insert(errors, "Cannot plot: " .. c.fn)
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
      svg = container.innerHTML
    else
      table.insert(errors, "function-plot failed: " .. tostring(err))
    end
  elseif #errors == 0 then
    table.insert(errors, "No equations found in plot block")
  end

  local html = '<div class="fplot">' .. svg .. plot.captionHtml(good)
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

- [ ] **Step 2: Add the space-style block at the end of `Function-Plot.md`**

````markdown
```space-style
.fplot {
  display: flex;
  flex-direction: column;
  gap: 0.5em;
}
.fplot svg {
  max-width: 100%;
  height: auto;
}
/* d3 axes use currentColor; inherit the page text color in both themes. */
.fplot .function-plot text {
  fill: currentColor;
}
.fplot-caption {
  display: flex;
  flex-direction: column;
  gap: 0.25em;
}
.fplot-caption-line {
  display: flex;
  align-items: center;
  gap: 0.5em;
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
````

- [ ] **Step 3: Rerun the parse test as a load check**

Run: `lua test/parse_test.lua`
Expected: prints `parse tests ok`. This proves the extended block still loads under vanilla Lua (syntax errors, accidental globals at load time). It does not exercise `plot.render`; that happens in Task 6 on the server.

- [ ] **Step 4: Commit**

```bash
git add Function-Plot.md
git commit -m "Add plot render widget with KaTeX captions and styles"
```

---

### Task 4: Demo page

**Files:**
- Create: `Function-Plot Demo.md`

**Interfaces:**
- Consumes: the `plot` code widget from Task 3.
- Produces: the manual verification surface for Task 6.

- [ ] **Step 1: Write the demo page**

`Function-Plot Demo.md`:

````markdown
# Function Plot Demo
Manual test page for [[Library/dane/Function-Plot]].

Single curve, automatic domain:

```plot
y = sin(x) / x
```

Multiple curves, pinned domains, caption colors match:

```plot
y = sin(x)
y = cos(x)
x: [-6.3, 6.3]
y: [-1.5, 1.5]
```

Roots and fractional exponents:

```plot
y = x^2 / 10 - 1
sqrt(x)
nthRoot(x, 3)
x: [-8, 8]
```

Asymptote:

```plot
1 / (x - 1)
x: [-4, 6]
y: [-8, 8]
```

Error handling: one broken curve and one bad domain line. The good curve
still plots, and the error box lists both problems:

```plot
y = sin(x)
y = flurble(x)
x: [banana, 2]
```
````

- [ ] **Step 2: Commit**

```bash
git add "Function-Plot Demo.md"
git commit -m "Add demo page"
```

---

### Task 5: README and GitHub publish

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: everything prior.
- Produces: the public repo. The `share.uri` in `Function-Plot.md` frontmatter already points at it.

- [ ] **Step 1: Write the README**

`README.md` (ASD-STE100 flavored: short sentences, active voice, no contractions):

````markdown
# silverbullet-function-plot

A [SilverBullet](https://silverbullet.md) v2 library. It renders `plot`
fenced code blocks as graphs with
[function-plot](https://mauriciopoppe.github.io/function-plot/). A KaTeX
caption below each graph shows the equations, color-matched to the curves.

## Syntax

    ```plot
    y = sin(x) / x
    y = x^2 / 10
    x: [-10, 10]
    y: [-2, 2]
    ```

Each bare line is one curve, in calculator syntax. The `y =` prefix is
optional. `x: [a, b]` and `y: [a, b]` pin the axis domains. Without them,
function-plot picks the domains.

Plots are static SVG. SilverBullet sanitizes widget HTML, so the
function-plot pan and zoom do not work. Pin the region with `x:` and `y:`.

## Install

1. Copy `Function-Plot.md` to `Library/dane/Function-Plot.md` in your space.
2. Copy the `Function-Plot/` directory to `Library/dane/Function-Plot/`.
3. Copy `Function-Plot Demo.md` anywhere, if you want the demo.
4. Run the `System: Reload` command.

Captions need the
[Silverbullet-Math](https://github.com/MrMugame/silverbullet-math) library
for KaTeX. Without it, captions fall back to plain code text.

## Development

- `npm install`, then `npm run build` regenerates the two vendored bundles
  in `Function-Plot/` with esbuild.
- `npm test` runs the bundle smoke test (node) and the parser tests
  (vanilla `lua`).

## Licenses

This library is MIT. The vendored bundles keep their own licenses:
[function-plot](https://github.com/mauriciopoppe/function-plot) (MIT) and
[mathjs](https://github.com/josdejong/mathjs) (Apache-2.0).
````

- [ ] **Step 2: Run the full test suite**

Run: `npm test`
Expected: `smoke ok` and `parse tests ok`.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Add README"
```

- [ ] **Step 4: Create the GitHub repo and push**

The user approved a public repo under their account (thedaneeffect).

```bash
gh repo create thedaneeffect/silverbullet-function-plot --public \
  --source=. --remote=origin --push \
  --description "SilverBullet library: plot equations with function-plot and KaTeX captions"
```

Expected: repo URL printed; `git log origin/main` matches local.

---

### Task 6: Deploy to medieval.software and verify

**Files:**
- None local. Remote: `/home/dane/silverbullet/space/Library/dane/Function-Plot.md`, `/home/dane/silverbullet/space/Library/dane/Function-Plot/*.mjs`, `/home/dane/silverbullet/space/Function-Plot Demo.md`.

**Interfaces:**
- Consumes: all repo files.
- Produces: the running feature.

- [ ] **Step 1: Copy the files to the space**

```bash
ssh medieval.software 'mkdir -p "/home/dane/silverbullet/space/Library/dane/Function-Plot"'
scp Function-Plot.md medieval.software:"/home/dane/silverbullet/space/Library/dane/"
scp Function-Plot/function-plot.mjs Function-Plot/mathjs-parse.mjs \
  medieval.software:"/home/dane/silverbullet/space/Library/dane/Function-Plot/"
scp "Function-Plot Demo.md" medieval.software:"/home/dane/silverbullet/space/"
```

- [ ] **Step 2: Reload SilverBullet**

Ask the user to run the `System: Reload` command in the SilverBullet UI.
If the space-lua does not pick up, `ssh medieval.software 'docker restart silverbullet'` is the fallback (confirm with the user first).

- [ ] **Step 3: Manual verification checklist (user, in the browser)**

On `Function-Plot Demo`:

1. Single-curve block renders an SVG graph with a caption showing a stacked fraction for `sin(x)/x`.
2. Multi-curve block: two curves, two caption lines, swatch colors match curve colors, domains honored.
3. Roots block: `nthRoot(x, 3)` captions as a cube root.
4. Asymptote block: `1/(x-1)` does not draw a false vertical line through x=1.
5. Error block: `sin(x)` still plots; error box lists `flurble` and the bad domain line.
6. Toggle dark theme: axis text and captions stay readable.
7. Optional: temporarily rename `Library/mrmugame`, reload, confirm captions fall back to code text, restore.

- [ ] **Step 4: Record follow-ups**

File any visual defects (grid contrast in dark theme is the likely one) as issues on the repo, or fix small CSS tweaks directly and redeploy (Steps 1-2).
