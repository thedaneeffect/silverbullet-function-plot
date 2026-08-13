# Implicit Plots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `lhs = rhs` lines in plot blocks render as implicit two-variable curves with `equation = level` KaTeX captions.

**Architecture:** Parser returns curve tables (`fn`, optional `lhs`/`rhs`); render marks implicit data with `fnType = "implicit"`; captions convert each side separately. No bundle rebuild — the vendored bundle already ships the implicit graph type (verified 2026-08-13 under jsdom).

**Tech Stack:** Space Lua in `Function-Plot.md`, existing vendored bundles, vanilla-lua test harness.

## Global Constraints

- Spec authority: `docs/superpowers/specs/2026-08-13-implicit-plots-design.md`.
- `y = expr` lines stay explicit curves; any other `lhs = rhs` line is implicit with plotted fn `(lhs) - (rhs)`.
- Space Lua quirk: NEVER chain a method call onto a multi-value return (`s:gsub():gsub()` crashes). Sequential assignments only.
- The space-lua block must load under vanilla Lua: `lua test/parse_test.lua` prints `parse tests ok`.
- Commit messages: concise, no Co-Authored-By, no AI attribution.
- Deploy target: `medieval.software:/home/dane/silverbullet/space/`.

---

### Task 1: Parser, render, and caption support

**Files:**
- Modify: `Function-Plot.md` (space-lua block: `plot.parse`, `plot.render` curve loop and probe, `plot.captionHtml`)
- Test: `test/parse_test.lua`

**Interfaces:**
- Produces: `plot.parse(body).curves` is now a list of tables — explicit `{ fn = "sin(x) / x" }`, implicit `{ fn = "(x^2 / (x + y)) - (50)", lhs = "x^2 / (x + y)", rhs = "50" }`. Task 2's demo relies on the `=`-line behavior.

- [ ] **Step 1: Update the parse tests to the new contract (they must fail first)**

In `test/parse_test.lua`, update existing assertions to the table shape and add implicit cases. Replace the test body below the harness (keep the harness and the `eq` helper) with:

```lua
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

-- A z: line is not a directive; it falls through as an implicit attempt is wrong —
-- it has no =, so it stays an explicit curve attempt
r = plot.parse("z: [1, 2]\n")
eq(#r.curves, 1, "z line treated as equation")

print("parse tests ok")
```

- [ ] **Step 2: Run tests, confirm they fail**

Run: `lua test/parse_test.lua`
Expected: FAIL on `r.curves[1].fn` (curves are still strings).

- [ ] **Step 3: Update `plot.parse` in `Function-Plot.md`**

Replace the final `else` branch (the one that does `table.insert(result.curves, trimmed:match("^y%s*=%s*(.+)$") or trimmed)`) with:

```lua
      else
        local expr = trimmed:match("^y%s*=%s*(.+)$")
        if expr then
          table.insert(result.curves, { fn = expr })
        else
          local lhs, rhs = trimmed:match("^([^=]+)=%s*(.+)$")
          if lhs and rhs then
            lhs = lhs:match("^%s*(.-)%s*$")
            rhs = rhs:match("^%s*(.-)%s*$")
            table.insert(result.curves, {
              fn = "(" .. lhs .. ") - (" .. rhs .. ")",
              lhs = lhs,
              rhs = rhs
            })
          else
            table.insert(result.curves, { fn = trimmed })
          end
        end
      end
```

- [ ] **Step 4: Update the curve loop and probe in `plot.render`**

Replace:

```lua
  local curves = {}
  for i, eq in ipairs(spec.curves) do
    table.insert(curves, {
      fn = eq,
      color = plot.PALETTE[(i - 1) % #plot.PALETTE + 1]
    })
  end
```

with:

```lua
  local curves = {}
  for i, c in ipairs(spec.curves) do
    local datum = {
      fn = c.fn,
      color = plot.PALETTE[(i - 1) % #plot.PALETTE + 1]
    }
    if c.lhs then
      datum.fnType = "implicit"
      datum.lhs = c.lhs
      datum.rhs = c.rhs
    end
    table.insert(curves, datum)
  end
```

(function-plot ignores the extra `lhs`/`rhs` keys; `plot.captionHtml` reads them.)

In the probe loop, replace the probe datum `{ fn = c.fn, nSamples = 24 }` with:

```lua
        data = { { fn = c.fn, fnType = c.fnType, nSamples = 24 } }
```

- [ ] **Step 5: Update `plot.captionHtml`**

Replace the pcall body and fallback inside the loop with:

```lua
    if latex and latex.katex then
      local ok, html = pcall(function()
        local tex
        if c.lhs then
          tex = plot.math.exprToTex(c.lhs) .. " = " .. plot.math.exprToTex(c.rhs)
        else
          tex = plot.math.exprToTex(c.fn)
        end
        return latex.katex.renderToString(tex, {
          throwOnError = true,
          displayMode = false
        })
      end)
      if ok then body = html end
    end
    if not body then
      local raw = c.fn
      if c.lhs then
        raw = c.lhs .. " = " .. c.rhs
      end
      body = "<code>" .. plot.escapeHtml(raw) .. "</code>"
    end
```

- [ ] **Step 6: Run tests, confirm they pass**

Run: `lua test/parse_test.lua` → `parse tests ok`; `node test/smoke.mjs` → `smoke ok`.

- [ ] **Step 7: Commit**

```bash
git add Function-Plot.md test/parse_test.lua
git commit -m "Add implicit two-variable curves via lhs = rhs lines"
```

---

### Task 2: Demo, docs, and deploy

**Files:**
- Modify: `Function-Plot Demo.md`
- Modify: `Function-Plot.md` (the `## Syntax` prose section only)
- Modify: `README.md`

**Interfaces:**
- Consumes: the `=`-line behavior from Task 1.

- [ ] **Step 1: Add the demo section**

Append to `Function-Plot Demo.md`:

````markdown

Two variables: iso-damage contours. Each curve is the set of
(attack, defense) pairs that produce one damage value, with x as attack
and y as defense. The smooth form plots cleanly. A `floor(...)` version
makes degenerate step contours, so keep the floor in the game code and
out of the plot:

```plot
x^2 / (x + y) = 25
x^2 / (x + y) = 50
x^2 / (x + y) = 100
x: [0, 200]
y: [0, 300]
```
````

- [ ] **Step 2: Update the library page syntax docs**

In `Function-Plot.md`, replace the `## Syntax` paragraph with:

```markdown
## Syntax
Each bare line is one curve, in calculator syntax. The `y =` prefix is
optional for explicit curves. A line of the form `lhs = rhs` (where the
left side is not `y`) plots the implicit curve `lhs - rhs = 0` in the
two variables `x` and `y`. `x: [a, b]` and `y: [a, b]` lines pin the
axis domains.
```

Keep the indented example block as is, and add one implicit line to it:

```
    ```plot
    y = sin(x) / x
    y = x^2 / 10
    x^2 + y^2 = 4
    x: [-10, 10]
    y: [-2, 2]
    ```
```

- [ ] **Step 3: Update README syntax section**

After the existing syntax paragraph in `README.md`, add:

```markdown
A line of the form `lhs = rhs` (left side other than `y`) plots the
implicit curve `lhs - rhs = 0` in the two variables `x` and `y`:

    ```plot
    x^2 / (x + y) = 50
    x: [0, 200]
    y: [0, 300]
    ```
```

- [ ] **Step 4: Test, commit, push**

Run: `npm test` → `smoke ok` + `parse tests ok`.

```bash
git add "Function-Plot Demo.md" Function-Plot.md README.md
git commit -m "Document implicit curves and add iso-damage demo"
git push origin main
```

- [ ] **Step 5: Deploy**

```bash
scp Function-Plot.md medieval.software:"/home/dane/silverbullet/space/Library/dane/"
scp "Function-Plot Demo.md" medieval.software:"/home/dane/silverbullet/space/"
```

- [ ] **Step 6: Local browser verification (controller)**

The controller re-runs the local SilverBullet + headless Chrome harness from the scratchpad against the updated files before asking the user to check: three contour curves render, captions typeset as `equation = level`, existing demo blocks unregressed.
