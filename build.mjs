import { build } from 'esbuild';

const shared = { bundle: true, minify: true, format: 'esm', logLevel: 'info' };

await build({ ...shared, entryPoints: ['entries/function-plot-entry.mjs'], outfile: 'Function-Plot/function-plot.mjs' });
await build({ ...shared, entryPoints: ['entries/mathjs-entry.mjs'], outfile: 'Function-Plot/mathjs-parse.mjs' });
