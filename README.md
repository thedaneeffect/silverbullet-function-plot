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

A line of the form `lhs = rhs` (left side other than `y`) plots the
implicit curve `lhs - rhs = 0` in the two variables `x` and `y`:

    ```plot
    x^2 / (x + y) = 50
    x: [0, 200]
    y: [0, 300]
    ```

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
