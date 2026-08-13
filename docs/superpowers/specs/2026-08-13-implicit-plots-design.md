# Implicit (two-variable) plots: design

Date: 2026-08-13
Status: approved (user requested the feature and the `=`-line syntax on 2026-08-12)
Extends: 2026-08-12-function-plot-design.md

## Goal

Plot equations in two variables as implicit curves (level sets), so a
formula like `damage = attack^2 / (attack + defense)` can render as
iso-damage contours in the attack-defense plane.

## Verified foundations (2026-08-13)

- The existing vendored bundle renders `fnType = "implicit"` data without a
  rebuild. Verified under jsdom: `{ fn = "x^2 / (x + y) - 50", fnType =
  "implicit" }` produces contour paths.
- mathjs cannot parse `lhs = rhs` as one expression. Captions must convert
  each side separately and join with `=`.

## Syntax

A non-directive line that contains `=` splits at the first `=`:

- If the left side is exactly `y` (optionally spaced), the line stays an
  explicit curve, exactly as today. `y = sin(x)` is unchanged.
- Any other `lhs = rhs` line is an implicit curve. The plotted function is
  `(lhs) - (rhs)` with `fnType = "implicit"`. `x` and `y` are the two
  variables.

Examples:

    ```plot
    x^2 / (x + y) = 25
    x^2 / (x + y) = 50
    x^2 / (x + y) = 100
    x: [0, 200]
    y: [0, 300]
    ```

Lines without `=` stay explicit curves. Directives (`x:`, `y:`) are
unchanged.

## Parser contract change

`plot.parse` currently returns `curves` as strings. It now returns a list
of tables:

- Explicit: `{ fn = "sin(x) / x", lhs = nil, rhs = nil }`
- Implicit: `{ fn = "(x^2 / (x + y)) - (50)", lhs = "x^2 / (x + y)", rhs = "50" }`

`fn` is always the string handed to function-plot. `lhs`/`rhs` are set only
for implicit curves and drive the caption. The lua test harness tests both
shapes.

## Render change

The datum for an implicit curve carries `fnType = "implicit"`. Everything
else (probe isolation, palette color, combined render, viewBox) is
unchanged. The probe for implicit curves uses the same small-render pcall.

## Caption change

- Explicit: `exprToTex(fn)`, as today.
- Implicit: `exprToTex(lhs) .. " = " .. exprToTex(rhs)`, KaTeX renders the
  joined string. On any conversion error, fall back to the raw line as code
  text (`lhs = rhs`).

## Docs and demo

- Demo page: add a section "Two variables: iso-damage contours" using the
  damage formula above, with a note that x is attack and y is defense, and
  that the smooth (un-floored) form plots cleanly while `floor(...)` makes
  degenerate step contours.
- Library page syntax docs and README: document the `=`-line rule and the
  `y =` exception.

## Out of scope

- Inequalities and shaded regions.
- More than two variables.
- Filing the upstream Space Lua chain-call bug (tracked separately).

## Verification

- Extend `test/parse_test.lua`: explicit line with `y =`, implicit line,
  implicit with `=` inside parentheses on the rhs, line without `=`.
- jsdom smoke check for an implicit datum (already proven; keep as a manual
  note, not a committed test, since jsdom is not a repo dependency).
- Browser check on the demo page: three contour curves, captions typeset as
  `equation = level`, colors match.
