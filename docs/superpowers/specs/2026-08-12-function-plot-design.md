# Function-Plot library for SilverBullet: design

Date: 2026-08-12
Status: approved

## Goal

Add a `plot` code block to SilverBullet. The block plots one or more equations
with the function-plot library. A KaTeX caption below the plot shows each
equation, color-matched to its curve.

## Context

- Target instance: SilverBullet v2 (image `ghcr.io/silverbulletmd/silverbullet:latest`)
  on medieval.software. The space lives at `/home/dane/silverbullet/space`.
- The space already contains `Library/mrmugame/Silverbullet-Math`. That library
  vendors KaTeX and exposes a global `latex` Lua namespace with
  `latex.katex.renderToString(expression, options)`.
- Library convention in this space: a page `Library/<author>/<Name>.md` with a
  `files:` frontmatter list, assets vendored in a sibling directory, and
  `share.uri` pointed at a GitHub source for pull updates.

## Authoring syntax

A fenced code block with language `plot`. Line types:

- A bare line is one curve, in calculator syntax. Example: `y = sin(x) / x`.
  The `y =` prefix is optional.
- `x: [a, b]` sets the x domain. `y: [a, b]` sets the y domain.
- Blank lines are ignored.

Example:

    ```plot
    y = sin(x) / x
    y = x^2 / 10
    x: [-10, 10]
    y: [-2, 2]
    ```

## Packaging

- Public GitHub repo `thedaneeffect/silverbullet-function-plot`.
- Repo layout:
  - `Function-Plot.md`: the library page. It holds all Space Lua code and the
    space-style block.
  - `Function-Plot/function-plot.mjs`: vendored function-plot ES module build.
  - `Function-Plot Demo.md`: demo and manual test page.
  - `README.md`: what it is, install steps, syntax reference, screenshot.
- The library page carries frontmatter in the space convention: `name:
  Library/dane/Function-Plot`, `tags: meta/library`, a `files:` list with the
  vendored module, and `share.uri` pointed at the repo.
- Vendor function-plot. Do not load it from a CDN. This matches the offline
  KaTeX setup already in the space.

## Rendering

A `space-lua` block on the library page registers a widget for `plot` code
blocks. On render, in the client:

1. Parse the block body into curves and domain options.
2. Import the vendored module with `js.import` through the
   `system.getURLPrefix()` + `.fs/` path, the same pattern Silverbullet-Math
   uses for `katex.mjs`.
3. Create a detached DOM node. Call function-plot with an explicit width and
   height, the parsed domains, and one data entry per curve.
4. Serialize the resulting SVG and return it with `widget.new { html = ... }`.

## KaTeX caption

Below the SVG, one caption line per curve:

- A small color swatch that matches the function-plot palette color for that
  curve index.
- The equation, rendered by `latex.katex.renderToString`.

Equations are typed in calculator syntax, not LaTeX. A small converter
produces LaTeX for the caption:

- Backslash-escape known function names: sin, cos, tan, log, ln, sqrt, and
  the other names function-plot supports.
- Convert `*` to `\cdot`.
- Pass `^` exponents through. Wrap multi-character exponents in braces.

Fallbacks:

- If KaTeX throws on the converted string, show the raw equation as code text.
- If the `latex` namespace is absent, show all captions as code text. The plot
  still renders.

## Error handling

- A line that parses as neither an equation nor a directive renders an error
  box that names the line. The other curves still plot.
- If function-plot throws on an equation, the widget shows the error text for
  that curve and plots the rest.

## Limitations

SilverBullet sanitizes widget HTML, so the SVG is static. Pan and zoom do not
work. The `x:` and `y:` directives are the substitute. An iframe panel could
restore interactivity later. That work is out of scope.

## Out of scope

- Implicit, polar, parametric, and point plots. function-plot supports them,
  and the syntax can grow directives later. The first version plots explicit
  y-of-x curves only.
- A custom LaTeX label per curve.
- Automated tests. Space Lua has no test harness.

## Verification

- Pull the library into the medieval.software space.
- Load `Function-Plot Demo.md` and check by eye:
  - One curve, auto domain.
  - Multiple curves with `x:` and `y:` set, captions color-matched.
  - A block with one broken line: error box shows, other curves plot.
  - Captions fall back to code text when KaTeX is unavailable.
- Check both light and dark themes.
