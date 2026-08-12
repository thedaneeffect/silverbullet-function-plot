import fp from 'function-plot';

// The CJS build exports { default: fn, Chart, ... }. Depending on interop,
// the import lands on the function or on that object. Normalize here.
const functionPlot = typeof fp === 'function' ? fp : fp.default;

export function render(options) {
  return functionPlot(options);
}

export default { render };
