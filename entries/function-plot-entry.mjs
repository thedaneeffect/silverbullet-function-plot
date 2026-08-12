import fp from 'function-plot';

// The CJS build exports { default: fn, Chart, ... }. Depending on interop,
// the import lands on the function or on that object. Normalize here.
const functionPlot = typeof fp === 'function' ? fp : fp.default;
const Chart = typeof fp === 'function' ? undefined : fp.Chart;

export function render(options) {
  const instance = functionPlot(options);
  // We render detached snapshots; drop the cache entry so charts do not
  // accumulate across re-renders.
  if (Chart && Chart.cache && instance && instance.id) {
    delete Chart.cache[instance.id];
  }
  return instance;
}

export default { render };
