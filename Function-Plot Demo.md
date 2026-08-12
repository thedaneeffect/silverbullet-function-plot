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
